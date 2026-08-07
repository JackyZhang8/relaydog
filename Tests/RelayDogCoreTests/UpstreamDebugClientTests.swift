import XCTest
@testable import RelayDogCore

final class UpstreamDebugClientTests: XCTestCase {
    func testOpenAITestPromptPostsChatCompletionAndCapturesRequestAndResponse() async throws {
        let transport = DebugRecordingHTTPTransport(response: .init(
            statusCode: 200,
            headers: ["content-type": "application/json"],
            body: Data(#"{"choices":[{"message":{"content":"hello"}}]}"#.utf8)
        ))
        let client = UpstreamDebugClient(transport: transport)
        let upstream = debugUpstream(
            proto: .openAI,
            baseURL: "https://example.com/openai/v1",
            apiKey: "sk-test"
        )

        let result = try await client.sendTestPrompt(
            upstream: upstream,
            protocol: .openAI,
            model: "glm-5.2",
            prompt: "hi"
        )

        XCTAssertEqual(transport.requests.count, 1)
        XCTAssertEqual(transport.requests[0].url?.absoluteString, "https://example.com/openai/v1/chat/completions")
        XCTAssertEqual(transport.requests[0].httpMethod, "POST")
        XCTAssertEqual(transport.requests[0].value(forHTTPHeaderField: "Authorization"), "Bearer sk-test")
        XCTAssertEqual(transport.requests[0].value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertTrue(String(decoding: transport.bodies[0], as: UTF8.self).contains(#""model":"glm-5.2""#))
        XCTAssertTrue(String(decoding: transport.bodies[0], as: UTF8.self).contains(#""content":"hi""#))
        XCTAssertTrue(result.requestText.contains("POST https://example.com/openai/v1/chat/completions"))
        XCTAssertTrue(result.requestText.contains(#""content" : "hi""#))
        XCTAssertTrue(result.responseText.contains("HTTP 200"))
        XCTAssertTrue(result.responseText.contains("hello"))
    }

    func testClaudeTestPromptPostsMessagesRequestAndCapturesRequestAndResponse() async throws {
        let transport = DebugRecordingHTTPTransport(response: .init(
            statusCode: 200,
            headers: ["content-type": "application/json"],
            body: Data(#"{"content":[{"text":"hello"}]}"#.utf8)
        ))
        let client = UpstreamDebugClient(transport: transport)
        let upstream = debugUpstream(
            proto: .claude,
            baseURL: "https://example.com/anthropic",
            apiKey: "claude-key"
        )

        let result = try await client.sendTestPrompt(
            upstream: upstream,
            protocol: .claude,
            model: "claude-sonnet",
            prompt: "hi"
        )

        XCTAssertEqual(transport.requests[0].url?.absoluteString, "https://example.com/anthropic/v1/messages")
        XCTAssertEqual(transport.requests[0].value(forHTTPHeaderField: "x-api-key"), "claude-key")
        XCTAssertEqual(transport.requests[0].value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        XCTAssertTrue(String(decoding: transport.bodies[0], as: UTF8.self).contains(#""model":"claude-sonnet""#))
        XCTAssertTrue(String(decoding: transport.bodies[0], as: UTF8.self).contains(#""max_tokens":256"#))
        XCTAssertTrue(result.requestText.contains("POST https://example.com/anthropic/v1/messages"))
        XCTAssertTrue(result.responseText.contains("hello"))
    }

    func testTestPromptAllowsDisabledUpstream() async throws {
        let transport = DebugRecordingHTTPTransport(response: .init(
            statusCode: 200,
            headers: ["content-type": "application/json"],
            body: Data(#"{"choices":[{"message":{"content":"hello"}}]}"#.utf8)
        ))
        let client = UpstreamDebugClient(transport: transport)
        var upstream = debugUpstream(
            proto: .openAI,
            baseURL: "https://example.com/openai/v1",
            apiKey: "sk-test"
        )
        upstream.enabled = false

        _ = try await client.sendTestPrompt(
            upstream: upstream,
            protocol: .openAI,
            model: "glm-5.2",
            prompt: "hi"
        )

        XCTAssertEqual(transport.requests.count, 1)
    }

    private func debugUpstream(proto: ProxyProtocol, baseURL: String, apiKey: String) -> UpstreamConfig {
        UpstreamConfig(
            id: "debug",
            name: "Debug Gateway",
            enabled: true,
            weight: 100,
            timeoutSeconds: 30,
            note: "",
            protocols: [
                proto: .init(
                    enabled: true,
                    baseURL: baseURL,
                    apiKey: apiKey,
                    headerOverrides: [:],
                    healthCheckPath: "/v1/models",
                    modelSync: .manual,
                    models: [],
                    modelMappings: [:]
                )
            ]
        )
    }
}

private final class DebugRecordingHTTPTransport: HTTPTransport, @unchecked Sendable {
    private(set) var requests: [URLRequest] = []
    private(set) var bodies: [Data] = []
    private let response: HTTPTransportResponse

    init(response: HTTPTransportResponse) {
        self.response = response
    }

    func data(for request: URLRequest) async throws -> HTTPTransportResponse {
        requests.append(request)
        bodies.append(request.httpBody ?? Data())
        return response
    }
}
