import XCTest
@testable import RelayDogCore

final class ProtocolDetectorTests: XCTestCase {
    func testDetectsOpenAIByPath() {
        let result = ProtocolDetector.detect(path: "/v1/chat/completions", headers: [:])
        XCTAssertEqual(result.protocol, .openAI)
    }

    func testDetectsClaudeByMessagesPath() {
        let result = ProtocolDetector.detect(path: "/v1/messages", headers: [:])
        XCTAssertEqual(result.protocol, .claude)
    }

    func testHeaderFallbackPrefersClaudeForAnthropicVersion() {
        let result = ProtocolDetector.detect(path: "/unknown", headers: ["Anthropic-Version": "2023-06-01"])
        XCTAssertEqual(result.protocol, .claude)
    }

    func testUnknownWhenPathAndHeadersAreAmbiguous() {
        let result = ProtocolDetector.detect(path: "/unknown", headers: [:])
        XCTAssertEqual(result.protocol, nil)
        XCTAssertEqual(result.reason, "Unable to identify protocol for /unknown")
    }
}
