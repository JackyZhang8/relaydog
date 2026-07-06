import Foundation

public enum ProxyProtocol: String, Codable, Hashable, CaseIterable, Sendable {
    case openAI = "openai"
    case claude
}

public enum RoutingMode: String, Codable, Hashable, Sendable {
    case single
    case roundRobin
    case weightedRoundRobin
    case failover
    case lowestLatency
}

public enum ModelSyncMode: String, Codable, Hashable, Sendable {
    case remote
    case manual
}

public enum RelayDogLanguage: String, Codable, Hashable, CaseIterable, Sendable {
    case system
    case zh
    case en
}

public struct RelayDogConfig: Codable, Equatable, Sendable {
    public var listener: ListenerConfig
    public var upstreams: [UpstreamConfig]
    public var routing: [ProxyProtocol: RoutingConfig]
    public var globalModelMappings: [ProxyProtocol: [String: String]]
    public var requestLogging: RequestLoggingConfig
    public var language: RelayDogLanguage

    public init(
        listener: ListenerConfig,
        upstreams: [UpstreamConfig],
        routing: [ProxyProtocol: RoutingConfig],
        globalModelMappings: [ProxyProtocol: [String: String]],
        requestLogging: RequestLoggingConfig,
        language: RelayDogLanguage = .system
    ) {
        self.listener = listener
        self.upstreams = upstreams
        self.routing = routing
        self.globalModelMappings = globalModelMappings
        self.requestLogging = requestLogging
        self.language = language
    }

    private enum CodingKeys: String, CodingKey {
        case listener
        case upstreams
        case routing
        case globalModelMappings
        case requestLogging
        case language
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        listener = try container.decode(ListenerConfig.self, forKey: .listener)
        upstreams = try container.decode([UpstreamConfig].self, forKey: .upstreams)
        routing = try container.decode([ProxyProtocol: RoutingConfig].self, forKey: .routing)
        globalModelMappings = try container.decode([ProxyProtocol: [String: String]].self, forKey: .globalModelMappings)
        requestLogging = try container.decode(RequestLoggingConfig.self, forKey: .requestLogging)
        language = try container.decodeIfPresent(RelayDogLanguage.self, forKey: .language) ?? .system
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(listener, forKey: .listener)
        try container.encode(upstreams, forKey: .upstreams)
        try container.encode(routing, forKey: .routing)
        try container.encode(globalModelMappings, forKey: .globalModelMappings)
        try container.encode(requestLogging, forKey: .requestLogging)
        try container.encode(language, forKey: .language)
    }
}

public struct ListenerConfig: Codable, Equatable, Sendable {
    public var host: String
    public var port: Int
    public var enabled: Bool

    public init(host: String, port: Int, enabled: Bool) {
        self.host = host
        self.port = port
        self.enabled = enabled
    }
}

public struct UpstreamConfig: Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var enabled: Bool
    public var weight: Int
    public var timeoutSeconds: Int
    public var note: String
    public var protocols: [ProxyProtocol: ProtocolCapabilityConfig]

    public init(
        id: String,
        name: String,
        enabled: Bool,
        weight: Int,
        timeoutSeconds: Int,
        note: String,
        protocols: [ProxyProtocol: ProtocolCapabilityConfig]
    ) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.weight = weight
        self.timeoutSeconds = timeoutSeconds
        self.note = note
        self.protocols = protocols
    }
}

public struct ProtocolCapabilityConfig: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var baseURL: String
    public var apiKey: String
    public var headerOverrides: [String: String]
    public var healthCheckPath: String
    public var modelSync: ModelSyncMode
    public var models: [String]
    public var modelMappings: [String: String]

    public init(
        enabled: Bool,
        baseURL: String,
        apiKey: String,
        headerOverrides: [String: String],
        healthCheckPath: String,
        modelSync: ModelSyncMode,
        models: [String],
        modelMappings: [String: String]
    ) {
        self.enabled = enabled
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.headerOverrides = headerOverrides
        self.healthCheckPath = healthCheckPath
        self.modelSync = modelSync
        self.models = models
        self.modelMappings = modelMappings
    }
}

public struct RoutingConfig: Codable, Equatable, Sendable {
    public var mode: RoutingMode
    public var selectedUpstreamID: String?

    public init(mode: RoutingMode, selectedUpstreamID: String?) {
        self.mode = mode
        self.selectedUpstreamID = selectedUpstreamID
    }
}

public struct RequestLoggingConfig: Codable, Equatable, Sendable {
    public var enabled: Bool
    public var maxFileBytes: Int
    public var retentionDays: Int
    public var recordResponseBody: Bool

    public init(enabled: Bool, maxFileBytes: Int, retentionDays: Int, recordResponseBody: Bool) {
        self.enabled = enabled
        self.maxFileBytes = maxFileBytes
        self.retentionDays = retentionDays
        self.recordResponseBody = recordResponseBody
    }
}

public extension JSONEncoder {
    static var relayDog: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

public extension JSONDecoder {
    static var relayDog: JSONDecoder {
        JSONDecoder()
    }
}
