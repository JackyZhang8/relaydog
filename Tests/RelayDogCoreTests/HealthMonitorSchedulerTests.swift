import XCTest
@testable import RelayDogCore

final class HealthMonitorSchedulerTests: XCTestCase {
    func testCheckAllUpdatesHealthStateForEnabledUpstreams() async throws {
        let transport = SchedulerStubHTTPTransport(statusCode: 200)
        let monitor = HealthMonitor(transport: transport)
        let healthState = HealthState()
        let config = TestConfigs.proxyEngineConfig()

        await HealthMonitorScheduler.checkAll(config: config, monitor: monitor, healthState: healthState)

        XCTAssertEqual(healthState.isReachable(upstreamID: "glm", proto: .openAI), true)
        XCTAssertEqual(healthState.isReachable(upstreamID: "dual", proto: .openAI), true)
        XCTAssertEqual(healthState.isReachable(upstreamID: "dual", proto: .claude), true)
    }

    func testCheckAllRecordsUnreachableUpstreams() async throws {
        let transport = SchedulerStubHTTPTransport(statusCode: 503)
        let monitor = HealthMonitor(transport: transport)
        let healthState = HealthState()
        let config = TestConfigs.proxyEngineConfig()

        await HealthMonitorScheduler.checkAll(config: config, monitor: monitor, healthState: healthState)

        XCTAssertEqual(healthState.isReachable(upstreamID: "glm", proto: .openAI), false)
        XCTAssertEqual(healthState.health(upstreamID: "glm", proto: .openAI)?.lastError, "HTTP 503")
    }
}

private final class SchedulerStubHTTPTransport: HTTPTransport, @unchecked Sendable {
    private let statusCode: Int

    init(statusCode: Int) {
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> HTTPTransportResponse {
        HTTPTransportResponse(statusCode: statusCode, headers: [:], body: Data())
    }
}
