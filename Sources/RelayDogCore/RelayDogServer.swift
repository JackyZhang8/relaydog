import Foundation
import Network

public typealias RawResponseWriter = @Sendable (Data) async -> Void

public protocol RawRequestHandling: Sendable {
    func handle(_ rawRequest: Data) async throws -> Data
    func handleStream(_ rawRequest: Data, write: @escaping RawResponseWriter) async
}

public extension RawRequestHandling {
    func handleStream(_ rawRequest: Data, write: @escaping RawResponseWriter) async {
        guard let response = try? await handle(rawRequest) else {
            return
        }
        await write(response)
    }
}

extension ProxyRequestHandler: RawRequestHandling {}

public protocol ServerTransport: AnyObject {
    func start(
        host: String,
        port: Int,
        handler: @escaping @Sendable (Data, @escaping RawResponseWriter) async -> Void
    ) async throws
    func stop() async
}

protocol NWListenerManaging: AnyObject {
    var stateUpdateHandler: (@Sendable (NWListener.State) -> Void)? { get set }
    var newConnectionHandler: (@Sendable (NWConnection) -> Void)? { get set }

    func start(queue: DispatchQueue)
    func cancel()
}

extension NWListener: NWListenerManaging {}

public enum RelayDogServerState: Equatable, Sendable {
    case stopped
    case running(host: String, port: Int)
}

public final class RelayDogServer: @unchecked Sendable {
    private let stateLock = NSLock()
    private var _state: RelayDogServerState = .stopped

    public private(set) var state: RelayDogServerState {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _state
        }
        set {
            stateLock.lock()
            defer { stateLock.unlock() }
            _state = newValue
        }
    }

    private let host: String
    private let port: Int
    private let handler: RawRequestHandling
    private let transport: ServerTransport

    public init(host: String, port: Int, handler: RawRequestHandling, transport: ServerTransport = NWListenerServerTransport()) {
        self.host = host
        self.port = port
        self.handler = handler
        self.transport = transport
    }

    public func start() async throws {
        try await transport.start(host: host, port: port) { [handler] request, write in
            await handler.handleStream(request, write: write)
        }
        state = .running(host: host, port: port)
    }

    public func stop() async {
        await transport.stop()
        state = .stopped
    }
}

public enum RelayDogServerError: Error, Equatable {
    case invalidPort(Int)
}

public final class NWListenerServerTransport: ServerTransport, @unchecked Sendable {
    private let listenerLock = NSLock()
    private var listener: (any NWListenerManaging)?
    private let queue = DispatchQueue(label: "relaydog.listener")
    private let listenerFactory: (NWParameters) throws -> any NWListenerManaging

    public init() {
        listenerFactory = { parameters in
            try NWListener(using: parameters)
        }
    }

    init(listenerFactory: @escaping (NWParameters) throws -> any NWListenerManaging) {
        self.listenerFactory = listenerFactory
    }

    public func start(
        host: String,
        port: Int,
        handler: @escaping @Sendable (Data, @escaping RawResponseWriter) async -> Void
    ) async throws {
        let parameters = try Self.makeParameters(host: host, port: port)
        let listener = try listenerFactory(parameters)
        setListener(listener)
        listener.newConnectionHandler = { [queue] connection in
            connection.start(queue: queue)
            Self.receive(on: connection, handler: handler)
        }
        do {
            try await startAndWaitUntilReady(listener)
        } catch {
            listener.cancel()
            setListener(nil)
            throw error
        }
    }

    public static func makeParameters(host: String, port: Int) throws -> NWParameters {
        guard (0...Int(UInt16.max)).contains(port), let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            throw RelayDogServerError.invalidPort(port)
        }

        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: NWEndpoint.Host(host), port: nwPort)
        return parameters
    }

    public func stop() async {
        let listener = takeListener()
        listener?.cancel()
    }

    private func setListener(_ listener: (any NWListenerManaging)?) {
        listenerLock.lock()
        defer { listenerLock.unlock() }
        self.listener = listener
    }

    private func takeListener() -> (any NWListenerManaging)? {
        listenerLock.lock()
        defer { listenerLock.unlock() }
        let listener = self.listener
        self.listener = nil
        return listener
    }

    private func startAndWaitUntilReady(_ listener: any NWListenerManaging) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let box = ListenerStartContinuation(continuation)
            listener.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    box.resume()
                case .waiting(let error), .failed(let error):
                    box.resume(throwing: error)
                case .cancelled:
                    box.resume(throwing: CancellationError())
                case .setup:
                    break
                @unknown default:
                    break
                }
            }
            listener.start(queue: queue)
        }
    }

    private static func receive(
        on connection: NWConnection,
        handler: @escaping @Sendable (Data, @escaping RawResponseWriter) async -> Void
    ) {
        let buffer = ConnectionRequestBuffer()
        receiveNext(on: connection, buffer: buffer, handler: handler)
    }

    private static func receiveNext(
        on connection: NWConnection,
        buffer: ConnectionRequestBuffer,
        handler: @escaping @Sendable (Data, @escaping RawResponseWriter) async -> Void
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { data, _, isComplete, error in
            guard error == nil, let data, !data.isEmpty else {
                connection.cancel()
                return
            }

            do {
                if let request = try buffer.append(data) {
                    respond(to: request, on: connection, handler: handler)
                } else if isComplete {
                    respond(to: buffer.currentData, on: connection, handler: handler)
                } else {
                    receiveNext(on: connection, buffer: buffer, handler: handler)
                }
            } catch let codecError as HTTPMessageCodecError where isRequestTooLarge(codecError) {
                sendAndClose(
                    HTTPMessageCodec.encodeResponse(
                        ProxyHTTPResponse(statusCode: 413, headers: ["content-type": "application/json"], body: Data())
                    ),
                    on: connection
                )
            } catch {
                respond(to: buffer.currentData, on: connection, handler: handler)
            }
        }
    }

    private static func isRequestTooLarge(_ error: HTTPMessageCodecError) -> Bool {
        if case .requestTooLarge = error {
            return true
        }
        return false
    }

    private static func respond(
        to request: Data,
        on connection: NWConnection,
        handler: @escaping @Sendable (Data, @escaping RawResponseWriter) async -> Void
    ) {
        Task {
            await handler(request) { chunk in
                await send(chunk, on: connection)
            }
            connection.cancel()
        }
    }

    private static func send(_ data: Data, on connection: NWConnection) async {
        await withCheckedContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { _ in
                continuation.resume()
            })
        }
    }

    private static func sendAndClose(_ data: Data, on connection: NWConnection) {
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

private final class ConnectionRequestBuffer: @unchecked Sendable {
    private var buffer = HTTPRequestBuffer()

    var currentData: Data {
        buffer.currentData
    }

    func append(_ data: Data) throws -> Data? {
        try buffer.append(data)
    }
}

private final class ListenerStartContinuation: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?

    init(_ continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func resume() {
        resume(with: .success(()))
    }

    func resume(throwing error: Error) {
        resume(with: .failure(error))
    }

    private func resume(with result: Result<Void, Error>) {
        lock.lock()
        guard let continuation else {
            lock.unlock()
            return
        }
        self.continuation = nil
        lock.unlock()

        switch result {
        case .success:
            continuation.resume()
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}
