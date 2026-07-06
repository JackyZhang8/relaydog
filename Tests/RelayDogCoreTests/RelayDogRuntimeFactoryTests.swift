import XCTest
@testable import RelayDogCore

final class RelayDogRuntimeFactoryTests: XCTestCase {
    func testMakeEngineWiresRequestLoggerWhenLoggingEnabled() {
        var config = RelayDogConfig.defaultConfig()
        config.requestLogging.enabled = true
        let paths = AppPaths(homeDirectory: FileManager.default.temporaryDirectory)

        let engine = RelayDogRuntimeFactory.makeEngine(
            config: config,
            paths: paths,
            upstreamClient: RuntimeFactoryStubUpstreamClient()
        )

        XCTAssertNotNil(engine.eventLogger)
        XCTAssertNotNil(engine.statisticsStore)
    }

    func testMakeEngineDoesNotWireRequestLoggerWhenLoggingDisabled() {
        var config = RelayDogConfig.defaultConfig()
        config.requestLogging.enabled = false

        let engine = RelayDogRuntimeFactory.makeEngine(
            config: config,
            paths: AppPaths(homeDirectory: FileManager.default.temporaryDirectory),
            upstreamClient: RuntimeFactoryStubUpstreamClient()
        )

        XCTAssertNil(engine.eventLogger)
        XCTAssertNotNil(engine.statisticsStore)
    }
}

private struct RuntimeFactoryStubUpstreamClient: UpstreamClient {
    func send(_ request: ForwardedHTTPRequest) async throws -> ProxyHTTPResponse {
        ProxyHTTPResponse(statusCode: 200, headers: [:], body: Data())
    }
}
