import XCTest
@testable import RelayDogCore

final class UpstreamURLBuilderTests: XCTestCase {
    func testAppendsRequestPathToBaseURL() throws {
        let url = try UpstreamURLBuilder.url(baseURL: "https://example.com/openai/v1", requestPath: "/v1/chat/completions")

        XCTAssertEqual(url.absoluteString, "https://example.com/openai/v1/chat/completions")
    }

    func testPreservesPercentEncodedRequestPath() throws {
        let url = try UpstreamURLBuilder.url(baseURL: "https://example.com/v1", requestPath: "/v1/models/gpt%2D5.5")

        XCTAssertEqual(url.absoluteString, "https://example.com/v1/models/gpt%2D5.5")
    }

    func testPreservesPercentEncodedQuery() throws {
        let url = try UpstreamURLBuilder.url(baseURL: "https://example.com/v1", requestPath: "/v1/models?filter=a%20b")

        XCTAssertEqual(url.absoluteString, "https://example.com/v1/models?filter=a%20b")
    }
}
