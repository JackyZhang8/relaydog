import XCTest
@testable import RelayDogCore

final class RoutingHealthStatisticsTests: XCTestCase {
    func testRoundRobinCyclesEnabledUpstreamsForProtocol() throws {
        var config = TestConfigs.proxyEngineConfig()
        config.routing[.openAI] = .init(mode: .roundRobin, selectedUpstreamID: nil)
        let routing = RoutingState()

        let first = try routing.select(protocol: .openAI, from: config, health: HealthState())
        let second = try routing.select(protocol: .openAI, from: config, health: HealthState())
        let third = try routing.select(protocol: .openAI, from: config, health: HealthState())

        XCTAssertEqual(first.upstream.id, "glm")
        XCTAssertEqual(second.upstream.id, "dual")
        XCTAssertEqual(third.upstream.id, "glm")
    }

    func testFailoverSkipsUnhealthyUpstream() throws {
        var config = TestConfigs.proxyEngineConfig()
        config.routing[.openAI] = .init(mode: .failover, selectedUpstreamID: nil)
        let health = HealthState()
        health.update(.init(upstreamID: "glm", proto: .openAI, isReachable: false, latencyMilliseconds: nil, lastError: "timeout", checkedAt: Date()))

        let selected = try RoutingState().select(protocol: .openAI, from: config, health: health)

        XCTAssertEqual(selected.upstream.id, "dual")
    }

    func testLowestLatencyChoosesReachableFastestUpstream() throws {
        var config = TestConfigs.proxyEngineConfig()
        config.routing[.openAI] = .init(mode: .lowestLatency, selectedUpstreamID: nil)
        let health = HealthState()
        health.update(.init(upstreamID: "glm", proto: .openAI, isReachable: true, latencyMilliseconds: 200, lastError: nil, checkedAt: Date()))
        health.update(.init(upstreamID: "dual", proto: .openAI, isReachable: true, latencyMilliseconds: 30, lastError: nil, checkedAt: Date()))

        let selected = try RoutingState().select(protocol: .openAI, from: config, health: health)

        XCTAssertEqual(selected.upstream.id, "dual")
    }

    func testStatisticsTracksCountsAndAverageLatency() {
        let store = StatisticsStore()

        store.record(.init(proto: .openAI, upstreamID: "glm", succeeded: true, durationMilliseconds: 100))
        store.record(.init(proto: .openAI, upstreamID: "glm", succeeded: false, durationMilliseconds: 300))

        let snapshot = store.snapshot(protocol: .openAI, upstreamID: "glm")
        XCTAssertEqual(snapshot.totalRequests, 2)
        XCTAssertEqual(snapshot.failedRequests, 1)
        XCTAssertEqual(snapshot.successRate, 0.5)
        XCTAssertEqual(snapshot.averageDurationMilliseconds, 200)
    }
}
