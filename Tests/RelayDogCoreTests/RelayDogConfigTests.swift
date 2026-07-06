import XCTest
@testable import RelayDogCore

final class RelayDogConfigTests: XCTestCase {
    func testEncodesApiKeyInPlaintextJson() throws {
        let config = RelayDogConfig(
            listener: .init(host: "127.0.0.1", port: 18787, enabled: true),
            upstreams: [
                .init(
                    id: "glm",
                    name: "GLM Gateway",
                    enabled: true,
                    weight: 100,
                    timeoutSeconds: 60,
                    note: "local personal config",
                    protocols: [
                        .openAI: .init(
                            enabled: true,
                            baseURL: "https://example.com/openai/v1",
                            apiKey: "sk-plain-text",
                            headerOverrides: ["Authorization": "Bearer sk-plain-text"],
                            healthCheckPath: "/v1/models",
                            modelSync: .remote,
                            models: ["glm5.2"],
                            modelMappings: ["gpt-5.5": "glm5.2"]
                        )
                    ]
                )
            ],
            routing: [.openAI: .init(mode: .single, selectedUpstreamID: "glm")],
            globalModelMappings: [.openAI: ["gpt-5.5": "glm5.2"]],
            requestLogging: .init(enabled: false, maxFileBytes: 50 * 1024 * 1024, retentionDays: 7, recordResponseBody: true)
        )

        let data = try JSONEncoder.relayDog.encode(config)
        let json = String(decoding: data, as: UTF8.self)

        XCTAssertTrue(json.contains("\"apiKey\" : \"sk-plain-text\""))
        XCTAssertTrue(json.contains("\"gpt-5.5\" : \"glm5.2\""))
    }
}
