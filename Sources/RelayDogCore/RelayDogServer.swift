import Foundation
import Network

public protocol RawRequestHandling: Sendable {
    func handle(_ rawRequest: Data) async throws -> Data
}

extension ProxyRequestHandler: RawRequestHandling {}

public protocol ServerTransport: AnyObject {
    func start(host: String, port: Int, handler: @escaping @Sendable (Data) async throws -> Data) async throws
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

public final class RelayDogServer {
    public private(set) var state: RelayDogServerState = .stopped

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
        try await transport.start(host: host, port: port) { [handler] request in
            try await handler.handle(request)
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

public final class NWListenerServerTransport: ServerTransport {
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

    public func start(host: String, port: Int, handler: @escaping @Sendable (Data) async throws -> Data) async throws {
        let parameters = try Self.makeParameters(host: host, port: port)
        let listener = try listenerFactory(parameters)
        self.listener = listener
        listener.newConnectionHandler = { [queue] connection in
            connection.start(queue: queue)
            Self.receive(on: connection, handler: handler)
        }
        do {
            try await startAndWaitUntilReady(listener)
        } catch {
            listener.cancel()
            self.listener = nil
            throw error
        }
    }

    public static func makeParameters(host: String, port: Int) throws -> NWParameters {
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
            throw RelayDogServerError.invalidPort(port)
        }

        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: NWEndpoint.Host(host), port: nwPort)
        return parameters
    }

    public func stop() async {
        listener?.cancel()
        listener = nil
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

    private static func receive(on connection: NWConnection, handler: @escaping @Sendable (Data) async throws -> Data) {
        let buffer = ConnectionRequestBuffer()
        receiveNext(on: connection, buffer: buffer, handler: handler)
    }

    private static func receiveNext(
        on connection: NWConnection,
        buffer: ConnectionRequestBuffer,
        handler: @escaping @Sendable (Data) async throws -> Data
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) { data, _, isComplete, error in
            guard error == nil, let data, !data.isEmpty else {
                connection.cancel()
                return
            }

            do {
                if let request = try buffer.append(data) {
                    sendResponse(for: request, on: connection, handler: handler)
                } else if isComplete {
                    sendResponse(for: buffer.currentData, on: connection, handler: handler)
                } else {
                    receiveNext(on: connection, buffer: buffer, handler: handler)
                }
            } catch {
                sendResponse(for: buffer.currentData, on: connection, handler: handler)
            }
        }
    }

    private static func sendResponse(
        for request: Data,
        on connection: NWConnection,
        handler: @escaping @Sendable (Data) async throws -> Data
    ) {
        Task {
            do {
                let response = try await handler(request)
                connection.send(content: response, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            } catch {
                connection.cancel()
            }
        }
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
