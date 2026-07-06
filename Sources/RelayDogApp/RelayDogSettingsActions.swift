import RelayDogCore

public struct RelayDogSettingsActions {
    public var setLanguage: (RelayDogLanguage) -> Void
    public var setListenerEnabled: (Bool) -> Void
    public var setListenerHost: (String) -> Void
    public var setListenerPort: (Int) -> Void
    public var setRequestLoggingEnabled: (Bool) -> Void
    public var updateRequestLogging: (RequestLoggingConfig) -> Void
    public var selectRoute: (ProxyProtocol, String?) -> Void
    public var upsertUpstream: (UpstreamConfig) -> Void
    public var deleteUpstream: (String) -> Void
    public var fetchModels: (UpstreamConfig, ProxyProtocol) async throws -> [String]
    public var debugUpstream: (UpstreamConfig, ProxyProtocol, String, String) async throws -> UpstreamDebugResult
    public var checkUpstreamHealth: (UpstreamConfig, ProxyProtocol) async -> UpstreamHealth?

    public init(
        setLanguage: @escaping (RelayDogLanguage) -> Void = { _ in },
        setListenerEnabled: @escaping (Bool) -> Void = { _ in },
        setListenerHost: @escaping (String) -> Void = { _ in },
        setListenerPort: @escaping (Int) -> Void = { _ in },
        setRequestLoggingEnabled: @escaping (Bool) -> Void = { _ in },
        updateRequestLogging: @escaping (RequestLoggingConfig) -> Void = { _ in },
        selectRoute: @escaping (ProxyProtocol, String?) -> Void = { _, _ in },
        upsertUpstream: @escaping (UpstreamConfig) -> Void = { _ in },
        deleteUpstream: @escaping (String) -> Void = { _ in },
        fetchModels: @escaping (UpstreamConfig, ProxyProtocol) async throws -> [String] = { _, _ in [] },
        debugUpstream: @escaping (UpstreamConfig, ProxyProtocol, String, String) async throws -> UpstreamDebugResult = { _, _, _, _ in UpstreamDebugResult(requestText: "", responseText: "") },
        checkUpstreamHealth: @escaping (UpstreamConfig, ProxyProtocol) async -> UpstreamHealth? = { _, _ in nil }
    ) {
        self.setLanguage = setLanguage
        self.setListenerEnabled = setListenerEnabled
        self.setListenerHost = setListenerHost
        self.setListenerPort = setListenerPort
        self.setRequestLoggingEnabled = setRequestLoggingEnabled
        self.updateRequestLogging = updateRequestLogging
        self.selectRoute = selectRoute
        self.upsertUpstream = upsertUpstream
        self.deleteUpstream = deleteUpstream
        self.fetchModels = fetchModels
        self.debugUpstream = debugUpstream
        self.checkUpstreamHealth = checkUpstreamHealth
    }
}
