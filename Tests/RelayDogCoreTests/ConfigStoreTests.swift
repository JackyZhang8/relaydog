import XCTest
@testable import RelayDogCore

final class ConfigStoreTests: XCTestCase {
    func testLoadCreatesDefaultConfigWhenMissing() throws {
        let temp = try TemporaryRelayDogHome()
        let store = ConfigStore(paths: AppPaths(homeDirectory: temp.url))

        let config = try store.loadOrCreateDefault()

        XCTAssertEqual(config.listener.host, "127.0.0.1")
        XCTAssertEqual(config.listener.port, 18787)
        XCTAssertTrue(config.listener.enabled)
        XCTAssertEqual(config.language, .system)
        XCTAssertFalse(config.requestLogging.enabled)
        XCTAssertEqual(config.requestLogging.maxFileBytes, 50 * 1024 * 1024)
        XCTAssertEqual(config.requestLogging.retentionDays, 7)
        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.url.appendingPathComponent(".relaydog/config.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: temp.url.appendingPathComponent(".relaydog/logs").path))

        let text = try String(contentsOf: temp.url.appendingPathComponent(".relaydog/config.json"), encoding: .utf8)
        XCTAssertTrue(text.contains("\"host\" : \"127.0.0.1\""))
        XCTAssertTrue(text.contains("\"language\" : \"system\""))
    }

    func testSaveThenLoadPreservesPlaintextConfig() throws {
        let temp = try TemporaryRelayDogHome()
        let store = ConfigStore(paths: AppPaths(homeDirectory: temp.url))
        var config = RelayDogConfig.defaultConfig()
        config.upstreams = [
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
            )
        ]

        try store.save(config)
        let loaded = try store.load()

        XCTAssertEqual(loaded.upstreams.first?.protocols[.openAI]?.apiKey, "sk-plain-text")
        XCTAssertEqual(loaded.upstreams.first?.protocols[.openAI]?.modelMappings["gpt-5.5"], "glm5.2")
    }

    func testDecodingConfigWithoutLanguageDefaultsToSystem() throws {
        let encoded = try JSONEncoder.relayDog.encode(RelayDogConfig.defaultConfig())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "language")
        let oldConfigData = try JSONSerialization.data(withJSONObject: object)

        let config = try JSONDecoder.relayDog.decode(RelayDogConfig.self, from: oldConfigData)

        XCTAssertEqual(config.language, .system)
    }
}

private struct TemporaryRelayDogHome {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("relaydog-config-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
