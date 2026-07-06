import XCTest
import RelayDogCore
@testable import RelayDogApp

@MainActor
final class RelayDogAppModelTests: XCTestCase {
    func testSelectRoutePersistsSingleProtocolRoute() async throws {
        let temp = try TemporaryAppModelHome()
        let store = ConfigStore(paths: AppPaths(homeDirectory: temp.url))
        try store.save(appModelConfig())
        let model = RelayDogAppModel(paths: store.paths)

        try await model.selectRoute(protocol: .openAI, upstreamID: "dual")

        let saved = try store.load()
        XCTAssertEqual(saved.routing[.openAI], .init(mode: .single, selectedUpstreamID: "dual"))
    }

    func testToggleRequestLoggingPersistsSetting() async throws {
        let temp = try TemporaryAppModelHome()
        let store = ConfigStore(paths: AppPaths(homeDirectory: temp.url))
        try store.save(appModelConfig())
        let model = RelayDogAppModel(paths: store.paths)

        try await model.setRequestLoggingEnabled(true)

        XCTAssertTrue(try store.load().requestLogging.enabled)
    }

    func testSelectRouteRestartsRunningProxyWithUpdatedConfig() async throws {
        let temp = try TemporaryAppModelHome()
        let store = ConfigStore(paths: AppPaths(homeDirectory: temp.url))
        try store.save(appModelConfig())
        let factory = RecordingRuntimeFactory()
        let model = RelayDogAppModel(paths: store.paths, runtimeFactory: factory.makeRuntime)

        await model.startProxyIfNeeded()
        try await model.selectRoute(protocol: .openAI, upstreamID: "dual")

        XCTAssertEqual(factory.runtimes.count, 2)
        XCTAssertEqual(factory.runtimes[0].stopCount, 1)
        XCTAssertEqual(factory.runtimes[1].startCount, 1)
        XCTAssertEqual(factory.runtimes[1].config.routing[.openAI], .init(mode: .single, selectedUpstreamID: "dual"))
    }

    func testTogglingRequestLoggingRestartsRunningProxyWithUpdatedConfig() async throws {
        let temp = try TemporaryAppModelHome()
        let store = ConfigStore(paths: AppPaths(homeDirectory: temp.url))
        try store.save(appModelConfig())
        let factory = RecordingRuntimeFactory()
        let model = RelayDogAppModel(paths: store.paths, runtimeFactory: factory.makeRuntime)

        await model.startProxyIfNeeded()
        try await model.setRequestLoggingEnabled(true)

        XCTAssertEqual(factory.runtimes.count, 2)
        XCTAssertTrue(factory.runtimes[1].config.requestLogging.enabled)
    }

    func testUpdateRequestLoggingPersistsEveryEditableValueAndRestartsRunningProxy() async throws {
        let temp = try TemporaryAppModelHome()
        let store = ConfigStore(paths: AppPaths(homeDirectory: temp.url))
        try store.save(appModelConfig())
        let factory = RecordingRuntimeFactory()
        let model = RelayDogAppModel(paths: store.paths, runtimeFactory: factory.makeRuntime)

        await model.startProxyIfNeeded()
        try await model.updateRequestLogging(.init(enabled: true, maxFileBytes: 12 * 1024 * 1024, retentionDays: 3, recordResponseBody: false))

        let saved = try store.load().requestLogging
        XCTAssertTrue(saved.enabled)
        XCTAssertEqual(saved.maxFileBytes, 12 * 1024 * 1024)
        XCTAssertEqual(saved.retentionDays, 3)
        XCTAssertFalse(saved.recordResponseBody)
        XCTAssertEqual(factory.runtimes.count, 2)
        XCTAssertEqual(factory.runtimes[1].config.requestLogging, saved)
    }

    func testSetListenerPortPersistsAndRestartsRunningProxyWithNewPort() async throws {
        let temp = try TemporaryAppModelHome()
        let store = ConfigStore(paths: AppPaths(homeDirectory: temp.url))
        try store.save(appModelConfig())
        let factory = RecordingRuntimeFactory()
        let model = RelayDogAppModel(paths: store.paths, runtimeFactory: factory.makeRuntime)

        await model.startProxyIfNeeded()
        try await model.setListenerPort(18888)

        XCTAssertEqual(try store.load().listener.port, 18888)
        XCTAssertEqual(factory.runtimes.count, 2)
        XCTAssertEqual(factory.runtimes[0].stopCount, 1)
        XCTAssertEqual(factory.runtimes[1].config.listener.port, 18888)
        XCTAssertEqual(model.runtimeState, .running(host: "127.0.0.1", port: 18888))
    }

    func testSetListenerHostPersistsAndRestartsRunningProxyWithNewHost() async throws {
        let temp = try TemporaryAppModelHome()
        let store = ConfigStore(paths: AppPaths(homeDirectory: temp.url))
        try store.save(appModelConfig())
        let factory = RecordingRuntimeFactory()
        let model = RelayDogAppModel(paths: store.paths, runtimeFactory: factory.makeRuntime)

        await model.startProxyIfNeeded()
        try await model.setListenerHost("0.0.0.0")

        XCTAssertEqual(try store.load().listener.host, "0.0.0.0")
        XCTAssertEqual(factory.runtimes.count, 2)
        XCTAssertEqual(factory.runtimes[0].stopCount, 1)
        XCTAssertEqual(factory.runtimes[1].config.listener.host, "0.0.0.0")
        XCTAssertEqual(model.runtimeState, .running(host: "0.0.0.0", port: 18787))
    }

    func testStartProxyIfNeededDoesNothingWhenListenerDisabled() async throws {
        let temp = try TemporaryAppModelHome()
        let store = ConfigStore(paths: AppPaths(homeDirectory: temp.url))
        var config = appModelConfig()
        config.listener.enabled = false
        try store.save(config)
        let factory = RecordingRuntimeFactory()
        let model = RelayDogAppModel(paths: store.paths, runtimeFactory: factory.makeRuntime)

        await model.startProxyIfNeeded()

        XCTAssertTrue(factory.runtimes.isEmpty)

        try await model.setListenerEnabled(true)

        XCTAssertEqual(factory.runtimes.count, 1)
        XCTAssertEqual(factory.runtimes[0].startCount, 1)
    }

    func testConcurrentStartProxyIfNeededStartsSingleRuntime() async throws {
        let temp = try TemporaryAppModelHome()
        let store = ConfigStore(paths: AppPaths(homeDirectory: temp.url))
        try store.save(appModelConfig())
        let factory = RecordingRuntimeFactory()
        let model = RelayDogAppModel(paths: store.paths, runtimeFactory: factory.makeRuntime)

        async let first: Void = model.startProxyIfNeeded()
        async let second: Void = model.startProxyIfNeeded()
        _ = await (first, second)

        XCTAssertEqual(factory.runtimes.count, 1)
        XCTAssertEqual(factory.runtimes[0].startCount, 1)
    }

    func testSetListenerEnabledStopsAndStartsRuntime() async throws {
        let temp = try TemporaryAppModelHome()
        let store = ConfigStore(paths: AppPaths(homeDirectory: temp.url))
        try store.save(appModelConfig())
        let factory = RecordingRuntimeFactory()
        let model = RelayDogAppModel(paths: store.paths, runtimeFactory: factory.makeRuntime)

        await model.startProxyIfNeeded()
        try await model.setListenerEnabled(false)

        XCTAssertFalse(try store.load().listener.enabled)
        XCTAssertEqual(factory.runtimes.count, 1)
        XCTAssertEqual(factory.runtimes[0].stopCount, 1)
        XCTAssertEqual(model.runtimeState, .stopped)

        try await model.setListenerEnabled(true)

        XCTAssertTrue(try store.load().listener.enabled)
        XCTAssertEqual(factory.runtimes.count, 2)
        XCTAssertEqual(factory.runtimes[1].startCount, 1)
    }

    func testUpsertAndDeleteUpstreamPersistAndRestartRunningProxy() async throws {
        let temp = try TemporaryAppModelHome()
        let store = ConfigStore(paths: AppPaths(homeDirectory: temp.url))
        var config = appModelConfig()
        config.routing[.openAI] = .init(mode: .single, selectedUpstreamID: "new")
        try store.save(config)
        let factory = RecordingRuntimeFactory()
        let model = RelayDogAppModel(paths: store.paths, runtimeFactory: factory.makeRuntime)
        let newUpstream = UpstreamConfig(
            id: "new",
            name: "New Gateway",
            enabled: true,
            weight: 20,
            timeoutSeconds: 45,
            note: "local",
            protocols: [
                .openAI: .init(enabled: true, baseURL: "https://new.example/v1", apiKey: "new-key", headerOverrides: [:], healthCheckPath: "/v1/models", modelSync: .manual, models: ["gpt-5.5"], modelMappings: ["gpt-5.5": "glm-5.2"]),
                .claude: .init(enabled: false, baseURL: "https://new.example", apiKey: "", headerOverrides: [:], healthCheckPath: "/v1/models", modelSync: .manual, models: [], modelMappings: [:])
            ]
        )

        await model.startProxyIfNeeded()
        try await model.upsertUpstream(newUpstream)

        var saved = try store.load()
        XCTAssertEqual(saved.upstreams.first(where: { $0.id == "new" })?.name, "New Gateway")
        XCTAssertEqual(saved.upstreams.first(where: { $0.id == "new" })?.protocols[.openAI]?.modelMappings["gpt-5.5"], "glm-5.2")
        XCTAssertEqual(factory.runtimes.count, 2)

        var edited = newUpstream
        edited.name = "Edited Gateway"
        try await model.upsertUpstream(edited)

        saved = try store.load()
        XCTAssertEqual(saved.upstreams.first(where: { $0.id == "new" })?.name, "Edited Gateway")
        XCTAssertEqual(factory.runtimes.count, 3)

        try await model.deleteUpstream(id: "new")

        saved = try store.load()
        XCTAssertNil(saved.upstreams.first(where: { $0.id == "new" }))
        XCTAssertNil(saved.routing[.openAI]?.selectedUpstreamID)
        XCTAssertEqual(factory.runtimes.count, 4)
    }

    func testUpsertUpstreamClearsRoutesThatNoLongerHaveEnabledProtocolCapability() async throws {
        let temp = try TemporaryAppModelHome()
        let store = ConfigStore(paths: AppPaths(homeDirectory: temp.url))
        var config = appModelConfig()
        config.upstreams[0].protocols[.claude] = .init(enabled: true, baseURL: "https://example.com/anthropic", apiKey: "claude", headerOverrides: [:], healthCheckPath: "/v1/messages", modelSync: .manual, models: [], modelMappings: [:])
        config.routing[.openAI] = .init(mode: .single, selectedUpstreamID: "dual")
        config.routing[.claude] = .init(mode: .single, selectedUpstreamID: "dual")
        try store.save(config)
        let factory = RecordingRuntimeFactory()
        let model = RelayDogAppModel(paths: store.paths, runtimeFactory: factory.makeRuntime)

        var edited = try XCTUnwrap(config.upstreams.first { $0.id == "dual" })
        edited.protocols[.claude]?.enabled = false

        await model.startProxyIfNeeded()
        try await model.upsertUpstream(edited)

        let saved = try store.load()
        XCTAssertEqual(saved.routing[.openAI]?.selectedUpstreamID, "dual")
        XCTAssertNil(saved.routing[.claude]?.selectedUpstreamID)
        XCTAssertEqual(factory.runtimes.last?.config.routing[.claude]?.selectedUpstreamID, nil)
    }

    func testUpstreamEditorDraftPreservesEnabledProtocolsWhenSavingExistingDualUpstream() throws {
        var config = appModelConfig()
        config.upstreams[0].protocols[.claude] = .init(enabled: true, baseURL: "https://example.com/anthropic", apiKey: "claude", headerOverrides: [:], healthCheckPath: "/v1/messages", modelSync: .manual, models: [], modelMappings: [:])
        let dual = try XCTUnwrap(config.upstreams.first { $0.id == "dual" })
        let draft = RelayDogUpstreamEditorDraft(upstream: dual)

        let saved = draft.makeUpstream()

        XCTAssertTrue(saved.protocols[.openAI]?.enabled == true)
        XCTAssertTrue(saved.protocols[.claude]?.enabled == true)
    }

    func testUpsertUpstreamToggleEnabledPersistsClearsRouteAndRestartsRunningProxy() async throws {
        let temp = try TemporaryAppModelHome()
        let store = ConfigStore(paths: AppPaths(homeDirectory: temp.url))
        var config = appModelConfig()
        config.routing[.openAI] = .init(mode: .single, selectedUpstreamID: "dual")
        try store.save(config)
        let factory = RecordingRuntimeFactory()
        let model = RelayDogAppModel(paths: store.paths, runtimeFactory: factory.makeRuntime)
        var upstream = try XCTUnwrap(config.upstreams.first { $0.id == "dual" })
        upstream.enabled = false

        await model.startProxyIfNeeded()
        try await model.upsertUpstream(upstream)

        let saved = try store.load()
        XCTAssertFalse(try XCTUnwrap(saved.upstreams.first { $0.id == "dual" }).enabled)
        XCTAssertNil(saved.routing[.openAI]?.selectedUpstreamID)
        XCTAssertEqual(factory.runtimes.count, 2)
        XCTAssertFalse(try XCTUnwrap(factory.runtimes.last?.config.upstreams.first { $0.id == "dual" }).enabled)
    }

    func testFetchModelsUsesDraftUpstreamWithoutPersistingConfig() async throws {
        let temp = try TemporaryAppModelHome()
        let store = ConfigStore(paths: AppPaths(homeDirectory: temp.url))
        try store.save(appModelConfig())
        let transport = RecordingModelHTTPTransport(response: .init(
            statusCode: 200,
            headers: [:],
            body: Data(#"{"data":[{"id":"glm-5.2"},{"id":"glm-4.5"}]}"#.utf8)
        ))
        let model = RelayDogAppModel(
            paths: store.paths,
            modelManager: ModelManager(transport: transport)
        )
        var draft = UpstreamConfig(
            id: "draft",
            name: "Draft Gateway",
            enabled: true,
            weight: 100,
            timeoutSeconds: 60,
            note: "",
            protocols: [
                .openAI: .init(enabled: true, baseURL: "https://example.com/openai/v1", apiKey: "sk-draft", headerOverrides: [:], healthCheckPath: "/v1/models", modelSync: .manual, models: [], modelMappings: [:])
            ]
        )

        let models = try await model.fetchModels(upstream: draft, protocol: .openAI)

        XCTAssertEqual(models, ["glm-5.2", "glm-4.5"])
        XCTAssertEqual(transport.requests.first?.url?.absoluteString, "https://example.com/openai/v1/models")
        XCTAssertEqual(transport.requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer sk-draft")
        XCTAssertNil(try store.load().upstreams.first(where: { $0.id == "draft" }))

        draft.protocols[.openAI]?.models = models
        XCTAssertEqual(draft.protocols[.openAI]?.models, ["glm-5.2", "glm-4.5"])
    }

    func testDebugUpstreamUsesDraftRequestWithoutPersistingConfig() async throws {
        let temp = try TemporaryAppModelHome()
        let store = ConfigStore(paths: AppPaths(homeDirectory: temp.url))
        try store.save(appModelConfig())
        let transport = RecordingModelHTTPTransport(response: .init(
            statusCode: 200,
            headers: [:],
            body: Data(#"{"choices":[{"message":{"content":"pong"}}]}"#.utf8)
        ))
        let model = RelayDogAppModel(
            paths: store.paths,
            debugClient: UpstreamDebugClient(transport: transport)
        )
        let draft = UpstreamConfig(
            id: "draft",
            name: "Draft Gateway",
            enabled: true,
            weight: 100,
            timeoutSeconds: 60,
            note: "",
            protocols: [
                .openAI: .init(enabled: true, baseURL: "https://example.com/openai/v1", apiKey: "sk-debug", headerOverrides: [:], healthCheckPath: "/v1/models", modelSync: .manual, models: ["glm-5.2"], modelMappings: [:])
            ]
        )

        let result = try await model.debugUpstream(upstream: draft, protocol: .openAI, model: "glm-5.2", prompt: "hi")

        XCTAssertTrue(result.requestText.contains("POST https://example.com/openai/v1/chat/completions"))
        XCTAssertTrue(result.responseText.contains("pong"))
        XCTAssertNil(try store.load().upstreams.first(where: { $0.id == "draft" }))
    }

    func testCheckUpstreamHealthUsesDraftWithoutPersistingConfig() async throws {
        let temp = try TemporaryAppModelHome()
        let store = ConfigStore(paths: AppPaths(homeDirectory: temp.url))
        try store.save(appModelConfig())
        let transport = RecordingModelHTTPTransport(response: .init(statusCode: 200, headers: [:], body: Data()))
        let model = RelayDogAppModel(
            paths: store.paths,
            healthMonitor: HealthMonitor(transport: transport)
        )
        let draft = UpstreamConfig(
            id: "draft",
            name: "Draft Gateway",
            enabled: true,
            weight: 100,
            timeoutSeconds: 60,
            note: "",
            protocols: [
                .openAI: .init(enabled: true, baseURL: "https://example.com/openai/v1", apiKey: "sk-health", headerOverrides: [:], healthCheckPath: "/v1/models", modelSync: .manual, models: [], modelMappings: [:])
            ]
        )

        let checkedHealth = await model.checkUpstreamHealth(upstream: draft, protocol: .openAI)
        let health = try XCTUnwrap(checkedHealth)

        XCTAssertTrue(health.isReachable)
        XCTAssertEqual(transport.requests.first?.url?.absoluteString, "https://example.com/openai/v1/models")
        XCTAssertEqual(transport.requests.first?.value(forHTTPHeaderField: "Authorization"), "Bearer sk-health")
        XCTAssertNil(try store.load().upstreams.first(where: { $0.id == "draft" }))
    }

    func testSetLanguagePersistsWithoutRestartingRunningProxy() async throws {
        let temp = try TemporaryAppModelHome()
        let store = ConfigStore(paths: AppPaths(homeDirectory: temp.url))
        try store.save(appModelConfig())
        let factory = RecordingRuntimeFactory()
        let model = RelayDogAppModel(paths: store.paths, runtimeFactory: factory.makeRuntime)

        await model.startProxyIfNeeded()
        try model.setLanguage(.zh)

        XCTAssertEqual(try store.load().language, .zh)
        XCTAssertEqual(factory.runtimes.count, 1)
        XCTAssertEqual(factory.runtimes[0].startCount, 1)
        XCTAssertEqual(factory.runtimes[0].stopCount, 0)
    }

    func testSettingsViewModelReflectsPersistedLanguage() throws {
        let temp = try TemporaryAppModelHome()
        let store = ConfigStore(paths: AppPaths(homeDirectory: temp.url))
        var config = appModelConfig()
        config.language = .en
        try store.save(config)

        let model = RelayDogAppModel(paths: store.paths)

        XCTAssertEqual(model.settingsViewModel.config.language, .en)
    }

    private func appModelConfig() -> RelayDogConfig {
        RelayDogConfig(
            listener: .init(host: "127.0.0.1", port: 18787, enabled: true),
            upstreams: [
                .init(
                    id: "dual",
                    name: "Dual Gateway",
                    enabled: true,
                    weight: 100,
                    timeoutSeconds: 60,
                    note: "",
                    protocols: [
                        .openAI: .init(enabled: true, baseURL: "https://example.com/dual/v1", apiKey: "openai", headerOverrides: [:], healthCheckPath: "/v1/models", modelSync: .manual, models: [], modelMappings: [:])
                    ]
                )
            ],
            routing: [.openAI: .init(mode: .roundRobin, selectedUpstreamID: nil)],
            globalModelMappings: [:],
            requestLogging: .init(enabled: false, maxFileBytes: 50 * 1024 * 1024, retentionDays: 7, recordResponseBody: true)
        )
    }
}

private final class RecordingRuntimeFactory {
    private(set) var runtimes: [RecordingRuntime] = []

    func makeRuntime(config: RelayDogConfig, paths: AppPaths) -> any RelayDogRuntimeManaging {
        let runtime = RecordingRuntime(config: config)
        runtimes.append(runtime)
        return runtime
    }
}

private final class RecordingRuntime: RelayDogRuntimeManaging, @unchecked Sendable {
    let config: RelayDogConfig
    var state: RelayDogServerState = .stopped
    private(set) var startCount = 0
    private(set) var stopCount = 0

    init(config: RelayDogConfig) {
        self.config = config
    }

    func start() async throws {
        startCount += 1
        state = .running(host: config.listener.host, port: config.listener.port)
    }

    func stop() async {
        stopCount += 1
        state = .stopped
    }
}

private final class RecordingModelHTTPTransport: HTTPTransport, @unchecked Sendable {
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

private struct TemporaryAppModelHome {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("relaydog-app-model-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
