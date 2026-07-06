import XCTest
import Network
@testable import RelayDogCore

final class RelayDogServerTests: XCTestCase {
    func testStartBindsTransportAndHandlesRequests() async throws {
        let transport = RecordingServerTransport()
        let handler = StubRawRequestHandler(response: Data("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok".utf8))
        let server = RelayDogServer(host: "127.0.0.1", port: 18787, handler: handler, transport: transport)

        try await server.start()
        let response = try await transport.handle(Data("GET / HTTP/1.1\r\n\r\n".utf8))

        XCTAssertEqual(transport.startedHost, "127.0.0.1")
        XCTAssertEqual(transport.startedPort, 18787)
        XCTAssertEqual(response, Data("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok".utf8))
        XCTAssertEqual(handler.requests, [Data("GET / HTTP/1.1\r\n\r\n".utf8)])
        XCTAssertEqual(server.state, .running(host: "127.0.0.1", port: 18787))
    }

    func testStopClosesTransport() async throws {
        let transport = RecordingServerTransport()
        let server = RelayDogServer(
            host: "127.0.0.1",
            port: 18787,
            handler: StubRawRequestHandler(response: Data()),
            transport: transport
        )

        try await server.start()
        await server.stop()

        XCTAssertTrue(transport.didStop)
        XCTAssertEqual(server.state, .stopped)
    }

    func testNWListenerParametersBindToConfiguredLocalhost() throws {
        let parameters = try NWListenerServerTransport.makeParameters(host: "127.0.0.1", port: 18787)

        XCTAssertEqual(
            parameters.requiredLocalEndpoint,
            .hostPort(host: "127.0.0.1", port: try XCTUnwrap(NWEndpoint.Port(rawValue: 18787)))
        )
    }

    func testNWListenerTransportWaitsForReadyBeforeReturning() async throws {
        let listener = FakeNWListener(startState: .ready)
        let transport = NWListenerServerTransport(listenerFactory: { _ in listener })

        try await transport.start(host: "127.0.0.1", port: 18787) { _, _ in }

        XCTAssertEqual(listener.startCount, 1)
        XCTAssertFalse(listener.didCancel)
    }

    func testNWListenerTransportThrowsWhenListenerFailsBeforeReady() async throws {
        let listener = FakeNWListener(startState: .failed(.posix(.EADDRINUSE)))
        let transport = NWListenerServerTransport(listenerFactory: { _ in listener })

        do {
            try await transport.start(host: "127.0.0.1", port: 18787) { _, _ in }
            XCTFail("Expected listener start failure")
        } catch {
            XCTAssertTrue(listener.didCancel)
        }
    }
}

private final class RecordingServerTransport: ServerTransport, @unchecked Sendable {
    var startedHost: String?
    var startedPort: Int?
    var didStop = false
    private var handler: (@Sendable (Data, @escaping RawResponseWriter) async -> Void)?

    func start(
        host: String,
        port: Int,
        handler: @escaping @Sendable (Data, @escaping RawResponseWriter) async -> Void
    ) async throws {
        startedHost = host
        startedPort = port
        self.handler = handler
    }

    func stop() async {
        didStop = true
    }

    func handle(_ request: Data) async throws -> Data {
        let collector = ResponseCollector()
        try await XCTUnwrap(handler)(request) { chunk in
            await collector.append(chunk)
        }
        return await collector.data
    }
}

private actor ResponseCollector {
    private(set) var data = Data()

    func append(_ chunk: Data) {
        data.append(chunk)
    }
}

private final class StubRawRequestHandler: RawRequestHandling, @unchecked Sendable {
    private(set) var requests: [Data] = []
    private let response: Data

    init(response: Data) {
        self.response = response
    }

    func handle(_ rawRequest: Data) async throws -> Data {
        requests.append(rawRequest)
        return response
    }
}

private final class FakeNWListener: NWListenerManaging, @unchecked Sendable {
    var stateUpdateHandler: (@Sendable (NWListener.State) -> Void)?
    var newConnectionHandler: (@Sendable (NWConnection) -> Void)?
    private let startState: NWListener.State
    private(set) var startCount = 0
    private(set) var didCancel = false

    init(startState: NWListener.State) {
        self.startState = startState
    }

    func start(queue: DispatchQueue) {
        startCount += 1
        queue.async { [stateUpdateHandler, startState] in
            stateUpdateHandler?(startState)
        }
    }

    func cancel() {
        didCancel = true
    }
}
