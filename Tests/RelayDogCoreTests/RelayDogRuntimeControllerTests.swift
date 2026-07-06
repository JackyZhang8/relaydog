import XCTest
@testable import RelayDogCore

final class RelayDogRuntimeControllerTests: XCTestCase {
    func testStartBindsListenerWhenConfigEnablesListener() async throws {
        let transport = RuntimeControllerRecordingServerTransport()
        let controller = RelayDogRuntimeController(
            config: RelayDogConfig.defaultConfig(),
            paths: AppPaths(homeDirectory: FileManager.default.temporaryDirectory),
            upstreamClient: RuntimeControllerStubUpstreamClient(),
            transport: transport
        )

        try await controller.start()

        XCTAssertEqual(transport.startedHost, "127.0.0.1")
        XCTAssertEqual(transport.startedPort, 18787)
        XCTAssertEqual(controller.state, .running(host: "127.0.0.1", port: 18787))
        XCTAssertNotNil(controller.statisticsStore)
    }

    func testStartDoesNotBindListenerWhenConfigDisablesListener() async throws {
        var config = RelayDogConfig.defaultConfig()
        config.listener.enabled = false
        let transport = RuntimeControllerRecordingServerTransport()
        let controller = RelayDogRuntimeController(
            config: config,
            paths: AppPaths(homeDirectory: FileManager.default.temporaryDirectory),
            upstreamClient: RuntimeControllerStubUpstreamClient(),
            transport: transport
        )

        try await controller.start()

        XCTAssertNil(transport.startedHost)
        XCTAssertEqual(controller.state, .stopped)
    }
}

private final class RuntimeControllerRecordingServerTransport: ServerTransport, @unchecked Sendable {
    var startedHost: String?
    var startedPort: Int?

    func start(host: String, port: Int, handler: @escaping @Sendable (Data) async throws -> Data) async throws {
        startedHost = host
        startedPort = port
    }

    func stop() async {}
}

private struct RuntimeControllerStubUpstreamClient: UpstreamClient {
    func send(_ request: ForwardedHTTPRequest) async throws -> ProxyHTTPResponse {
        ProxyHTTPResponse(statusCode: 200, headers: [:], body: Data())
    }
}
