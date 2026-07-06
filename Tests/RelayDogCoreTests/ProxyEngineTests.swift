import XCTest
@testable import RelayDogCore

final class ProxyEngineTests: XCTestCase {
    func testOpenAIRequestUsesOpenAIRouteMapsModelAndOverridesAuthorization() async throws {
        let client = RecordingUpstreamClient(response: .init(statusCode: 200, headers: ["content-type": "application/json"], body: Data(#"{"ok":true}"#.utf8)))
        let engine = ProxyEngine(config: TestConfigs.proxyEngineConfig(), upstreamClient: client)
        let request = ProxyHTTPRequest(
            method: "POST",
            path: "/v1/responses",
            headers: ["Authorization": "Bearer client-key", "content-type": "application/json"],
            body: Data(#"{"model":"gpt-5.5","input":"hi"}"#.utf8)
        )

        let response = try await engine.handle(request)

        XCTAssertEqual(response.statusCode, 200)
        let forwarded = try XCTUnwrap(client.requests.first)
        XCTAssertEqual(forwarded.protocol, .openAI)
        XCTAssertEqual(forwarded.upstreamID, "glm")
        XCTAssertEqual(forwarded.url.absoluteString, "https://example.com/openai/v1/responses")
        XCTAssertEqual(forwarded.headers["Authorization"], "Bearer sk-plain-text")

        let forwardedJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: forwarded.body) as? [String: Any])
        XCTAssertEqual(forwardedJSON["model"] as? String, "glm5.2")
        XCTAssertEqual(forwarded.modelRewrite?.originalModel, "gpt-5.5")
        XCTAssertEqual(forwarded.modelRewrite?.mappedModel, "glm5.2")
    }

    func testOpenAIGetModelsWithEmptyBodyIsForwardedTransparently() async throws {
        let client = RecordingUpstreamClient(response: .init(statusCode: 200, headers: [:], body: Data()))
        let engine = ProxyEngine(config: TestConfigs.proxyEngineConfig(), upstreamClient: client)

        let response = try await engine.handle(.init(method: "GET", path: "/v1/models", headers: [:], body: Data()))

        XCTAssertEqual(response.statusCode, 200)
        let forwarded = try XCTUnwrap(client.requests.first)
        XCTAssertEqual(forwarded.body, Data())
        XCTAssertNil(forwarded.modelRewrite)
    }

    func testForwardedRequestCarriesSelectedUpstreamTimeout() async throws {
        let client = RecordingUpstreamClient(response: .init(statusCode: 200, headers: [:], body: Data()))
        var config = TestConfigs.proxyEngineConfig()
        config.upstreams[0].timeoutSeconds = 12
        let engine = ProxyEngine(config: config, upstreamClient: client)

        _ = try await engine.handle(.init(
            method: "POST",
            path: "/v1/responses",
            headers: [:],
            body: Data(#"{"model":"gpt-5.5"}"#.utf8)
        ))

        let forwarded = try XCTUnwrap(client.requests.first)
        XCTAssertEqual(forwarded.timeoutSeconds, 12)
    }

    func testOpenAIHeaderOverrideRemovesCaseInsensitiveClientAuthorization() async throws {
        let client = RecordingUpstreamClient(response: .init(statusCode: 200, headers: [:], body: Data()))
        let engine = ProxyEngine(config: TestConfigs.proxyEngineConfig(), upstreamClient: client)

        _ = try await engine.handle(.init(
            method: "POST",
            path: "/v1/responses",
            headers: ["authorization": "Bearer client-key"],
            body: Data(#"{"model":"gpt-5.5"}"#.utf8)
        ))

        let forwarded = try XCTUnwrap(client.requests.first)
        XCTAssertEqual(forwarded.headers["Authorization"], "Bearer sk-plain-text")
        XCTAssertNil(forwarded.headers["authorization"])
    }

    func testGlobalModelMappingsApplyWhenUpstreamHasNoOverride() async throws {
        var config = TestConfigs.proxyEngineConfig()
        config.upstreams[0].protocols[.openAI]?.modelMappings = [:]
        config.globalModelMappings[.openAI] = ["gpt-5.5": "global-model"]
        let client = RecordingUpstreamClient(response: .init(statusCode: 200, headers: [:], body: Data()))
        let engine = ProxyEngine(config: config, upstreamClient: client)

        _ = try await engine.handle(.init(
            method: "POST",
            path: "/v1/responses",
            headers: [:],
            body: Data(#"{"model":"gpt-5.5"}"#.utf8)
        ))

        let forwarded = try XCTUnwrap(client.requests.first)
        let forwardedJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: forwarded.body) as? [String: Any])
        XCTAssertEqual(forwardedJSON["model"] as? String, "global-model")
        XCTAssertEqual(forwarded.modelRewrite?.originalModel, "gpt-5.5")
        XCTAssertEqual(forwarded.modelRewrite?.mappedModel, "global-model")
    }

    func testUpstreamSpecificMappingOverridesGlobalMapping() async throws {
        let client = RecordingUpstreamClient(response: .init(statusCode: 200, headers: [:], body: Data()))
        let engine = ProxyEngine(config: TestConfigs.proxyEngineConfig(), upstreamClient: client)

        _ = try await engine.handle(.init(
            method: "POST",
            path: "/v1/responses",
            headers: [:],
            body: Data(#"{"model":"gpt-5.5"}"#.utf8)
        ))

        let forwarded = try XCTUnwrap(client.requests.first)
        let forwardedJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: forwarded.body) as? [String: Any])
        XCTAssertEqual(forwardedJSON["model"] as? String, "glm5.2")
    }

    func testUpstreamErrorReturnsBadGatewayResponse() async throws {
        let client = FailingUpstreamClient()
        let engine = ProxyEngine(config: TestConfigs.proxyEngineConfig(), upstreamClient: client)

        let response = try await engine.handle(.init(
            method: "POST",
            path: "/v1/responses",
            headers: [:],
            body: Data(#"{"model":"gpt-5.5"}"#.utf8)
        ))

        XCTAssertEqual(response.statusCode, 502)
        XCTAssertTrue(String(decoding: response.body, as: UTF8.self).contains("Upstream request failed"))
    }

    func testRootPathReturnsStatusWithoutCallingUpstream() async throws {
        let client = RecordingUpstreamClient(response: .init(statusCode: 200, headers: [:], body: Data()))
        let engine = ProxyEngine(config: TestConfigs.proxyEngineConfig(), upstreamClient: client)

        let response = try await engine.handle(.init(method: "GET", path: "/", headers: [:], body: Data()))

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertTrue(String(decoding: response.body, as: UTF8.self).contains("relaydog"))
        XCTAssertTrue(client.requests.isEmpty)
    }

    func testHandleStreamWritesHeadAndBodyChunks() async throws {
        let client = StreamingStubUpstreamClient(
            statusCode: 200,
            headers: ["content-type": "text/event-stream"],
            chunks: [Data("data: one\n\n".utf8), Data("data: two\n\n".utf8)]
        )
        let engine = ProxyEngine(config: TestConfigs.proxyEngineConfig(), upstreamClient: client)
        let collector = WriteCollector()

        await engine.handleStream(
            .init(method: "POST", path: "/v1/responses", headers: [:], body: Data(#"{"model":"gpt-5.5","stream":true}"#.utf8))
        ) { chunk in
            await collector.append(chunk)
        }

        let written = await collector.chunks
        XCTAssertEqual(written.count, 4)
        let head = String(decoding: written[0], as: UTF8.self)
        XCTAssertTrue(head.hasPrefix("HTTP/1.1 200 OK\r\n"))
        XCTAssertTrue(head.contains("content-type: text/event-stream\r\n"))
        XCTAssertTrue(head.contains("Transfer-Encoding: chunked\r\n"))
        XCTAssertTrue(head.contains("Connection: close\r\n"))
        XCTAssertEqual(written[1], HTTPMessageCodec.encodeChunk(Data("data: one\n\n".utf8)))
        XCTAssertEqual(written[2], HTTPMessageCodec.encodeChunk(Data("data: two\n\n".utf8)))
        XCTAssertEqual(written[3], HTTPMessageCodec.chunkedBodyTerminator)
    }

    func testRedactsSensitiveHeaders() {
        let redacted = ProxyEngine.redactedHeaders([
            "Authorization": "Bearer sk-secret",
            "x-api-key": "sk-secret",
            "Cookie": "session=abc",
            "content-type": "application/json"
        ])

        XCTAssertEqual(redacted["Authorization"], "Bearer ***")
        XCTAssertEqual(redacted["x-api-key"], "***")
        XCTAssertEqual(redacted["Cookie"], "***")
        XCTAssertEqual(redacted["content-type"], "application/json")
    }
}

actor WriteCollector {
    private(set) var chunks: [Data] = []

    func append(_ chunk: Data) {
        chunks.append(chunk)
    }
}

final class StreamingStubUpstreamClient: UpstreamClient, @unchecked Sendable {
    private let statusCode: Int
    private let headers: [String: String]
    private let chunks: [Data]

    init(statusCode: Int, headers: [String: String], chunks: [Data]) {
        self.statusCode = statusCode
        self.headers = headers
        self.chunks = chunks
    }

    func send(_ request: ForwardedHTTPRequest) async throws -> ProxyHTTPResponse {
        ProxyHTTPResponse(statusCode: statusCode, headers: headers, body: chunks.reduce(Data(), +))
    }

    func stream(_ request: ForwardedHTTPRequest) async throws -> UpstreamStreamingResponse {
        UpstreamStreamingResponse(
            statusCode: statusCode,
            headers: headers,
            body: AsyncThrowingStream { continuation in
                for chunk in chunks {
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
        )
    }
}

private struct FailingUpstreamClient: UpstreamClient {
    struct StubError: Error {}

    func send(_ request: ForwardedHTTPRequest) async throws -> ProxyHTTPResponse {
        throw StubError()
    }
}

extension ProxyEngineTests {
    func testClaudeRequestUsesClaudeRouteAndXAPIKey() async throws {
        let client = RecordingUpstreamClient(response: .init(statusCode: 200, headers: [:], body: Data()))
        let engine = ProxyEngine(config: TestConfigs.proxyEngineConfig(), upstreamClient: client)
        let request = ProxyHTTPRequest(
            method: "POST",
            path: "/v1/messages",
            headers: ["anthropic-version": "2023-06-01"],
            body: Data(#"{"model":"claude-sonnet-4-5"}"#.utf8)
        )

        _ = try await engine.handle(request)

        let forwarded = try XCTUnwrap(client.requests.first)
        XCTAssertEqual(forwarded.protocol, .claude)
        XCTAssertEqual(forwarded.upstreamID, "dual")
        XCTAssertEqual(forwarded.url.absoluteString, "https://example.com/anthropic/v1/messages")
        XCTAssertEqual(forwarded.headers["x-api-key"], "claude-plain-text")
        XCTAssertEqual(forwarded.modelRewrite?.originalModel, "claude-sonnet-4-5")
        XCTAssertNil(forwarded.modelRewrite?.mappedModel)
    }

    func testClaudeRequestAppliesModelMappings() async throws {
        var config = TestConfigs.proxyEngineConfig()
        config.upstreams[1].protocols[.claude]?.modelMappings = ["claude-sonnet-4-5": "upstream-claude"]
        let client = RecordingUpstreamClient(response: .init(statusCode: 200, headers: [:], body: Data()))
        let engine = ProxyEngine(config: config, upstreamClient: client)

        _ = try await engine.handle(.init(
            method: "POST",
            path: "/v1/messages",
            headers: ["anthropic-version": "2023-06-01"],
            body: Data(#"{"model":"claude-sonnet-4-5"}"#.utf8)
        ))

        let forwarded = try XCTUnwrap(client.requests.first)
        let forwardedJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: forwarded.body) as? [String: Any])
        XCTAssertEqual(forwardedJSON["model"] as? String, "upstream-claude")
        XCTAssertEqual(forwarded.modelRewrite?.mappedModel, "upstream-claude")
    }

    func testUnknownProtocolReturnsBadRequestWithoutCallingUpstream() async throws {
        let client = RecordingUpstreamClient(response: .init(statusCode: 200, headers: [:], body: Data()))
        let engine = ProxyEngine(config: TestConfigs.proxyEngineConfig(), upstreamClient: client)

        let response = try await engine.handle(.init(method: "GET", path: "/unknown", headers: [:], body: Data()))

        XCTAssertEqual(response.statusCode, 400)
        XCTAssertTrue(String(decoding: response.body, as: UTF8.self).contains("Unable to identify protocol"))
        XCTAssertTrue(client.requests.isEmpty)
    }

    func testMissingUpstreamReturnsServiceUnavailable() async throws {
        var config = TestConfigs.proxyEngineConfig()
        config.upstreams = []
        let client = RecordingUpstreamClient(response: .init(statusCode: 200, headers: [:], body: Data()))
        let engine = ProxyEngine(config: config, upstreamClient: client)

        let response = try await engine.handle(.init(method: "POST", path: "/v1/responses", headers: [:], body: Data(#"{"model":"gpt-5.5"}"#.utf8)))

        XCTAssertEqual(response.statusCode, 503)
        XCTAssertTrue(String(decoding: response.body, as: UTF8.self).contains("No enabled upstream"))
        XCTAssertTrue(client.requests.isEmpty)
    }

    func testRoundRobinRoutingAffectsForwardedRequests() async throws {
        var config = TestConfigs.proxyEngineConfig()
        config.routing[.openAI] = .init(mode: .roundRobin, selectedUpstreamID: nil)
        let client = RecordingUpstreamClient(response: .init(statusCode: 200, headers: [:], body: Data()))
        let engine = ProxyEngine(config: config, upstreamClient: client)
        let request = ProxyHTTPRequest(
            method: "POST",
            path: "/v1/responses",
            headers: [:],
            body: Data(#"{"model":"gpt-5.5"}"#.utf8)
        )

        _ = try await engine.handle(request)
        _ = try await engine.handle(request)

        XCTAssertEqual(client.requests.map(\.upstreamID), ["glm", "dual"])
    }

    func testRecordsRequestStatisticsForForwardedRequests() async throws {
        let statistics = StatisticsStore()
        let client = RecordingUpstreamClient(response: .init(statusCode: 200, headers: [:], body: Data()))
        let engine = ProxyEngine(
            config: TestConfigs.proxyEngineConfig(),
            upstreamClient: client,
            statisticsStore: statistics
        )

        _ = try await engine.handle(.init(
            method: "POST",
            path: "/v1/responses",
            headers: [:],
            body: Data(#"{"model":"gpt-5.5"}"#.utf8)
        ))

        let snapshot = statistics.snapshot(protocol: .openAI, upstreamID: "glm")
        XCTAssertEqual(snapshot.totalRequests, 1)
        XCTAssertEqual(snapshot.failedRequests, 0)
    }
}

final class RecordingUpstreamClient: UpstreamClient, @unchecked Sendable {
    private(set) var requests: [ForwardedHTTPRequest] = []
    private let response: ProxyHTTPResponse

    init(response: ProxyHTTPResponse) {
        self.response = response
    }

    func send(_ request: ForwardedHTTPRequest) async throws -> ProxyHTTPResponse {
        requests.append(request)
        return response
    }
}

enum TestConfigs {
    static func proxyEngineConfig() -> RelayDogConfig {
        RelayDogConfig(
            listener: .init(host: "127.0.0.1", port: 18787, enabled: true),
            upstreams: [
                .init(
                    id: "glm",
                    name: "GLM Gateway",
                    enabled: true,
                    weight: 100,
                    timeoutSeconds: 60,
                    note: "",
                    protocols: [
                        .openAI: .init(
                            enabled: true,
                            baseURL: "https://example.com/openai/v1",
                            apiKey: "sk-plain-text",
                            headerOverrides: [:],
                            healthCheckPath: "/v1/models",
                            modelSync: .manual,
                            models: ["glm5.2"],
                            modelMappings: ["gpt-5.5": "glm5.2"]
                        )
                    ]
                ),
                .init(
                    id: "dual",
                    name: "Dual Gateway",
                    enabled: true,
                    weight: 100,
                    timeoutSeconds: 60,
                    note: "",
                    protocols: [
                        .openAI: .init(enabled: true, baseURL: "https://example.com/dual/v1", apiKey: "dual-openai", headerOverrides: [:], healthCheckPath: "/v1/models", modelSync: .manual, models: [], modelMappings: [:]),
                        .claude: .init(enabled: true, baseURL: "https://example.com/anthropic", apiKey: "claude-plain-text", headerOverrides: [:], healthCheckPath: "/v1/messages", modelSync: .manual, models: ["claude-sonnet-4-5"], modelMappings: [:])
                    ]
                )
            ],
            routing: [
                .openAI: .init(mode: .single, selectedUpstreamID: "glm"),
                .claude: .init(mode: .single, selectedUpstreamID: "dual")
            ],
            globalModelMappings: [.openAI: ["gpt-5.5": "global-should-be-overridden"]],
            requestLogging: .init(enabled: false, maxFileBytes: 50 * 1024 * 1024, retentionDays: 7, recordResponseBody: true)
        )
    }
}
