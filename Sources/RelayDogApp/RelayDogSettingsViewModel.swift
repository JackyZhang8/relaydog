import Foundation
import RelayDogCore

public struct RelayDogSettingsViewModel: Sendable {
    public var config: RelayDogConfig
    public var paths: AppPaths
    private var preferredLanguages: [String]

    public init(
        config: RelayDogConfig,
        paths: AppPaths = AppPaths(),
        preferredLanguages: [String] = Locale.preferredLanguages
    ) {
        self.config = config
        self.paths = paths
        self.preferredLanguages = preferredLanguages
    }

    public var localEndpoint: String {
        "http://\(config.listener.host):\(config.listener.port)"
    }

    public var headerTagline: String {
        text(
            "本机 AI 模型中转站，一个客户端地址连接多路模型。",
            "Local AI model relay. One client address routes to multiple models."
        )
    }

    public var openAIBaseURL: String {
        localEndpoint + "/v1"
    }

    public var claudeBaseURL: String {
        localEndpoint
    }

    public var endpointItems: [RelayDogSettingsEndpointItem] {
        [
            .init(title: text("OpenAI Base URL", "OpenAI Base URL"), value: openAIBaseURL),
            .init(title: text("Claude Base URL", "Claude Base URL"), value: claudeBaseURL)
        ]
    }

    public var localDataItems: [RelayDogSettingsEndpointItem] {
        [
            .init(title: text("配置文件", "Config File"), value: paths.configFile.path),
            .init(title: text("日志文件夹", "Logs Folder"), value: paths.logsDirectory.path)
        ]
    }

    public var aboutDetails: RelayDogSettingsAboutDetails {
        RelayDogSettingsAboutDetails(
            title: "RelayDog",
            description: text(
                "RelayDog 是一个本机 AI 模型中转工具。它用统一端口同时承接 OpenAI 兼容协议和 Claude 协议请求，按路由转发到不同中转站，并支持按中转站配置模型列表、模型映射、请求日志和调试测试。",
                "RelayDog is a local AI model relay tool. It serves OpenAI-compatible and Claude requests on one local endpoint, routes them to configured upstreams, and supports per-upstream models, mappings, request logs, and debug tests."
            ),
            featureTitles: [
                text("单一本地端点", "Single local endpoint"),
                text("OpenAI 与 Claude 路由", "OpenAI and Claude routing"),
                text("按中转站配置模型和映射", "Per-upstream models and mappings"),
                text("请求日志与调试测试", "Request logs and debug tests")
            ],
            storageNote: text(
                "当前配置和 API Key 会以明文保存到本机配置文件，请只在受信任的本机环境中使用。",
                "Configuration and API keys are currently stored in plaintext on this Mac. Use RelayDog only in trusted local environments."
            )
        )
    }

    public var protocolSummaries: [RelayDogSettingsProtocolSummary] {
        ProxyProtocol.allCases.map { proto in
            RelayDogSettingsProtocolSummary(
                proto: proto,
                routeTitle: selectedRouteTitle(for: proto),
                enabledUpstreamCount: enabledUpstreamCount(for: proto),
                modelCount: modelCount(for: proto),
                modelMappingCount: modelMappingCount(for: proto)
            )
        }
    }

    public var upstreamRows: [RelayDogSettingsUpstreamRow] {
        config.upstreams.map { upstream in
            let protocolTitles = ProxyProtocol.allCases.compactMap { proto -> String? in
                guard upstream.protocols[proto]?.enabled == true else {
                    return nil
                }
                return proto.displayName
            }

            return RelayDogSettingsUpstreamRow(
                id: upstream.id,
                name: upstream.name,
                isEnabled: upstream.enabled,
                protocolTitles: protocolTitles,
                weight: upstream.weight,
                timeoutTitle: "\(upstream.timeoutSeconds)s",
                note: upstream.note
            )
        }
    }

    public var modelMappingRows: [RelayDogSettingsModelMappingRow] {
        var rows: [RelayDogSettingsModelMappingRow] = []

        for upstream in config.upstreams {
            for proto in ProxyProtocol.allCases {
                let mappings = upstream.protocols[proto]?.modelMappings ?? [:]
                for (clientModel, upstreamModel) in mappings {
                    rows.append(.init(
                        scope: upstream.name,
                        proto: proto,
                        clientModel: clientModel,
                        upstreamModel: upstreamModel
                    ))
                }
            }
        }

        return rows.sorted { lhs, rhs in
            if lhs.scope == rhs.scope {
                if lhs.proto == rhs.proto {
                    return lhs.clientModel < rhs.clientModel
                }
                return lhs.proto.rawValue < rhs.proto.rawValue
            }
            return lhs.scope < rhs.scope
        }
    }

    public var requestLoggingTitle: String {
        config.requestLogging.enabled
            ? t("开启", "On", language: effectiveLanguage)
            : t("关闭", "Off", language: effectiveLanguage)
    }

    public var effectiveLanguage: RelayDogResolvedLanguage {
        config.language.resolved(preferredLanguages: preferredLanguages)
    }

    public var languageOptions: [RelayDogLanguageOption] {
        RelayDogLanguage.allCases.map { language in
            RelayDogLanguageOption(
                preference: language,
                title: language.optionTitle,
                isSelected: language == config.language
            )
        }
    }

    public func text(_ zh: String, _ en: String) -> String {
        t(zh, en, language: effectiveLanguage)
    }

    public func selectedRouteTitle(for proto: ProxyProtocol) -> String {
        guard let selectedID = config.routing[proto]?.selectedUpstreamID,
              let upstream = config.upstreams.first(where: { $0.id == selectedID }) else {
            return "Auto"
        }
        return upstream.name
    }

    private func enabledUpstreamCount(for proto: ProxyProtocol) -> Int {
        config.upstreams.filter { upstream in
            upstream.enabled && upstream.protocols[proto]?.enabled == true
        }.count
    }

    private func modelCount(for proto: ProxyProtocol) -> Int {
        let models = config.upstreams.flatMap { upstream in
            upstream.protocols[proto]?.models ?? []
        }
        return Set(models).count
    }

    private func modelMappingCount(for proto: ProxyProtocol) -> Int {
        config.upstreams.reduce(0) { partial, upstream in
            partial + (upstream.protocols[proto]?.modelMappings.count ?? 0)
        }
    }
}

public protocol RelayDogRuntimeManaging: AnyObject, Sendable {
    var state: RelayDogServerState { get }
    func start() async throws
    func stop() async
}

extension RelayDogRuntimeController: RelayDogRuntimeManaging {}

public enum RelayDogAppModelError: Error, Equatable, Sendable {
    case invalidListenerPort(Int)
}

@MainActor
public final class RelayDogAppModel: ObservableObject {
    @Published public private(set) var config: RelayDogConfig
    @Published public private(set) var runtimeState: RelayDogServerState = .stopped
    @Published public private(set) var lastError: String?
    public let paths: AppPaths
    private let runtimeFactory: (RelayDogConfig, AppPaths) -> any RelayDogRuntimeManaging
    private let modelManager: ModelManager
    private let debugClient: UpstreamDebugClient
    private let healthMonitor: HealthMonitor
    private var runtimeController: (any RelayDogRuntimeManaging)?

    public init(
        config: RelayDogConfig? = nil,
        paths: AppPaths = AppPaths(),
        autostart: Bool = false,
        modelManager: ModelManager = ModelManager(transport: URLSessionHTTPTransport()),
        debugClient: UpstreamDebugClient = UpstreamDebugClient(transport: URLSessionHTTPTransport()),
        healthMonitor: HealthMonitor = HealthMonitor(transport: URLSessionHTTPTransport()),
        runtimeFactory: @escaping (RelayDogConfig, AppPaths) -> any RelayDogRuntimeManaging = { config, paths in
            RelayDogRuntimeController(config: config, paths: paths)
        }
    ) {
        self.paths = paths
        self.runtimeFactory = runtimeFactory
        self.modelManager = modelManager
        self.debugClient = debugClient
        self.healthMonitor = healthMonitor

        if let config {
            self.config = config
        } else {
            let store = ConfigStore(paths: paths)
            self.config = (try? store.loadOrCreateDefault()) ?? RelayDogConfig.defaultConfig()
        }

        if autostart {
            Task { @MainActor [weak self] in
                await self?.startProxyIfNeeded()
            }
        }
    }

    public var menuViewModel: RelayDogMenuViewModel {
        RelayDogMenuViewModel(config: config, runtimeState: runtimeState)
    }

    public var settingsViewModel: RelayDogSettingsViewModel {
        RelayDogSettingsViewModel(config: config, paths: paths)
    }

    public func reload() {
        let store = ConfigStore(paths: paths)
        if let config = try? store.loadOrCreateDefault() {
            self.config = config
        }
    }

    public func selectRoute(protocol proto: ProxyProtocol, upstreamID: String?) async throws {
        if let upstreamID {
            config.routing[proto] = .init(mode: .single, selectedUpstreamID: upstreamID)
        } else if config.routing[proto] == nil {
            config.routing[proto] = .init(mode: .roundRobin, selectedUpstreamID: nil)
        } else {
            config.routing[proto]?.selectedUpstreamID = nil
        }

        try await saveAndRestartIfRunning()
    }

    public func setListenerEnabled(_ enabled: Bool) async throws {
        guard config.listener.enabled != enabled else {
            return
        }

        config.listener.enabled = enabled
        try saveConfig()

        if enabled {
            await startProxyIfNeeded()
        } else {
            await stopProxy()
        }
    }

    public func setListenerPort(_ port: Int) async throws {
        guard (1...65_535).contains(port) else {
            throw RelayDogAppModelError.invalidListenerPort(port)
        }
        guard config.listener.port != port else {
            return
        }

        config.listener.port = port
        try await saveAndRestartIfRunning()
    }

    public func setListenerHost(_ host: String) async throws {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty, config.listener.host != host else {
            return
        }

        config.listener.host = host
        try await saveAndRestartIfRunning()
    }

    public func setRequestLoggingEnabled(_ enabled: Bool) async throws {
        config.requestLogging.enabled = enabled
        try await saveAndRestartIfRunning()
    }

    public func updateRequestLogging(_ requestLogging: RequestLoggingConfig) async throws {
        config.requestLogging = requestLogging
        try await saveAndRestartIfRunning()
    }

    public func upsertUpstream(_ upstream: UpstreamConfig) async throws {
        if let index = config.upstreams.firstIndex(where: { $0.id == upstream.id }) {
            config.upstreams[index] = upstream
        } else {
            config.upstreams.append(upstream)
        }

        clearUnavailableSelectedRoutes()
        try await saveAndRestartIfRunning()
    }

    public func deleteUpstream(id: String) async throws {
        config.upstreams.removeAll { $0.id == id }
        clearUnavailableSelectedRoutes()

        try await saveAndRestartIfRunning()
    }

    public func fetchModels(upstream: UpstreamConfig, protocol proto: ProxyProtocol) async throws -> [String] {
        var upstream = upstream
        upstream.protocols[proto]?.modelSync = .remote
        return try await modelManager.resolveModels(upstream: upstream, protocol: proto)
    }

    public func debugUpstream(upstream: UpstreamConfig, protocol proto: ProxyProtocol, model: String, prompt: String) async throws -> UpstreamDebugResult {
        try await debugClient.sendTestPrompt(upstream: upstream, protocol: proto, model: model, prompt: prompt)
    }

    public func checkUpstreamHealth(upstream: UpstreamConfig, protocol proto: ProxyProtocol) async -> UpstreamHealth? {
        await healthMonitor.check(upstream: upstream, proto: proto)
    }

    public func setLanguage(_ language: RelayDogLanguage) throws {
        config.language = language
        try saveConfig()
    }

    public func startProxyIfNeeded() async {
        guard runtimeController == nil else {
            return
        }

        let controller = runtimeFactory(config, paths)

        do {
            try await controller.start()
            runtimeController = controller
            runtimeState = controller.state
            lastError = nil
        } catch {
            runtimeState = .stopped
            lastError = String(describing: error)
        }
    }

    public func stopProxy() async {
        await runtimeController?.stop()
        runtimeController = nil
        runtimeState = .stopped
    }

    private func saveConfig() throws {
        objectWillChange.send()
        try ConfigStore(paths: paths).save(config)
    }

    private func saveAndRestartIfRunning() async throws {
        try saveConfig()
        await restartProxyIfRunning()
    }

    private func restartProxyIfRunning() async {
        guard runtimeController != nil else {
            return
        }

        await stopProxy()
        await startProxyIfNeeded()
    }

    private func clearUnavailableSelectedRoutes() {
        for proto in ProxyProtocol.allCases {
            guard let selectedID = config.routing[proto]?.selectedUpstreamID else {
                continue
            }

            let selectedIsAvailable = config.upstreams.contains { upstream in
                upstream.id == selectedID &&
                    upstream.enabled &&
                    upstream.protocols[proto]?.enabled == true
            }

            if !selectedIsAvailable {
                config.routing[proto]?.selectedUpstreamID = nil
            }
        }
    }
}
