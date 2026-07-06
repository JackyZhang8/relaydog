import XCTest
@testable import RelayDogCore

final class ProxyRequestHandlerTests: XCTestCase {
    func testHandlesRawHTTPRequestAndReturnsRawHTTPResponse() async throws {
        let client = RecordingUpstreamClient(response: .init(statusCode: 200, headers: ["content-type": "application/json"], body: Data(#"{"ok":true}"#.utf8)))
        let engine = ProxyEngine(config: TestConfigs.proxyEngineConfig(), upstreamClient: client)
        let handler = ProxyRequestHandler(engine: engine)
        let raw = Data("""
        POST /v1/responses HTTP/1.1\r
        Host: 127.0.0.1:18787\r
        Content-Type: application/json\r
        Content-Length: 32\r
        \r
        {"model":"gpt-5.5","input":"hi"}
        """.utf8)

        let responseData = try await handler.handle(raw)
        let responseText = String(decoding: responseData, as: UTF8.self)

        XCTAssertTrue(responseText.hasPrefix("HTTP/1.1 200 OK\r\n"))
        XCTAssertTrue(responseText.hasSuffix("\r\n\r\n{\"ok\":true}"))
        XCTAssertEqual(client.requests.first?.url.absoluteString, "https://example.com/openai/v1/responses")
    }

    func testMalformedHTTPRequestReturnsBadRequestResponse() async throws {
        let client = RecordingUpstreamClient(response: .init(statusCode: 200, headers: [:], body: Data()))
        let engine = ProxyEngine(config: TestConfigs.proxyEngineConfig(), upstreamClient: client)
        let handler = ProxyRequestHandler(engine: engine)

        let responseData = try await handler.handle(Data("not http".utf8))
        let responseText = String(decoding: responseData, as: UTF8.self)

        XCTAssertTrue(responseText.hasPrefix("HTTP/1.1 400 Bad Request\r\n"))
        XCTAssertTrue(client.requests.isEmpty)
    }
}
