import XCTest
@testable import RelayDogCore

final class UpstreamSelectorTests: XCTestCase {
    func testSingleModeSelectsConfiguredUpstreamWithMatchingProtocol() throws {
        let config = TestConfigs.proxyEngineConfig()

        let selected = try UpstreamSelector.select(protocol: .openAI, from: config)

        XCTAssertEqual(selected.upstream.id, "glm")
        XCTAssertEqual(selected.capability.baseURL, "https://example.com/openai/v1")
    }

    func testFallsBackToFirstEnabledProtocolCapabilityWhenNoSelectionConfigured() throws {
        var config = TestConfigs.proxyEngineConfig()
        config.routing[.claude] = .init(mode: .roundRobin, selectedUpstreamID: nil)

        let selected = try UpstreamSelector.select(protocol: .claude, from: config)

        XCTAssertEqual(selected.upstream.id, "dual")
        XCTAssertEqual(selected.capability.baseURL, "https://example.com/anthropic")
    }
}
