import XCTest
@testable import RelayDogCore

final class ModelManagerTests: XCTestCase {
    func testSyncOpenAIModelsFetchesV1ModelsAndParsesModelIDs() async throws {
        let transport = ModelRecordingHTTPTransport(response: .init(
            statusCode: 200,
            headers: ["content-type": "application/json"],
            body: Data(#"{"object":"list","data":[{"id":"glm5.2"},{"id":"glm-4.5"}]}"#.utf8)
        ))
        let manager = ModelManager(transport: transport)
        let upstream = remoteModelUpstream()

        let models = try await manager.resolveModels(upstream: upstream, protocol: .openAI)

        XCTAssertEqual(models, ["glm5.2", "glm-4.5"])
        XCTAssertEqual(transport.requests.count, 1)
        XCTAssertEqual(transport.requests[0].url?.absoluteString, "https://example.com/openai/v1/models")
        XCTAssertEqual(transport.requests[0].httpMethod, "GET")
        XCTAssertEqual(transport.requests[0].value(forHTTPHeaderField: "Authorization"), "Bearer sk-plain-text")
    }

    func testManualModelsReturnConfiguredListWithoutNetworkRequest() async throws {
        let transport = ModelRecordingHTTPTransport(response: .init(statusCode: 200, headers: [:], body: Data()))
        let manager = ModelManager(transport: transport)
        var upstream = remoteModelUpstream()
        upstream.protocols[.openAI]?.modelSync = .manual
        upstream.protocols[.openAI]?.models = ["manual-glm"]

        let models = try await manager.resolveModels(upstream: upstream, protocol: .openAI)

        XCTAssertEqual(models, ["manual-glm"])
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testValidateMappingsReportsTargetsMissingFromSameProtocolModels() {
        var config = TestConfigs.proxyEngineConfig()
        config.globalModelMappings[.openAI] = [
            "hidden-global": "missing-global-model"
        ]
        config.upstreams[0].protocols[.openAI]?.modelMappings = [
            "gpt-5.5": "glm5.2",
            "claude-alias": "claude-sonnet-4-5"
        ]
        config.upstreams[1].protocols[.claude]?.modelMappings = ["sonnet": "claude-sonnet-4-5"]

        let openAIIssues = ModelManager.validateMappings(
            upstreamID: "glm",
            protocol: .openAI,
            in: config
        )
        let claudeIssues = ModelManager.validateMappings(
            upstreamID: "dual",
            protocol: .claude,
            in: config
        )

        XCTAssertEqual(openAIIssues, [
            .init(clientModel: "claude-alias", targetModel: "claude-sonnet-4-5")
        ])
        XCTAssertTrue(claudeIssues.isEmpty)
    }

    func testParsesCommonModelListShapes() throws {
        let data = Data(#"{"models":["a",{"id":"b"},{"name":"c"}]}"#.utf8)

        let models = try ModelManager.parseModelIDs(from: data)

        XCTAssertEqual(models, ["a", "b", "c"])
    }

    private func remoteModelUpstream() -> UpstreamConfig {
        UpstreamConfig(
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
                    modelSync: .remote,
                    models: [],
                    modelMappings: [:]
                )
            ]
        )
    }
}

private final class ModelRecordingHTTPTransport: HTTPTransport, @unchecked Sendable {
    private(set) var requests: [URLRequest] = []
    private let response: HTTPTransportResponse

    init(response: HTTPTransportResponse) {
        self.response = response
    }

    func data(for request: URLRequest) async throws -> HTTPTransportResponse {
        requests.append(request)
        return response
    }
}
