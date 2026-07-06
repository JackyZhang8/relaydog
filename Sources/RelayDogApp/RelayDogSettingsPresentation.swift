import Foundation
import RelayDogCore

public enum RelayDogSettingsTab: String, CaseIterable, Hashable, Identifiable, Sendable {
    case overview
    case connections
    case logs
    case system
    case about

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .overview:
            return "Overview"
        case .connections:
            return "Connections"
        case .logs:
            return "Logs"
        case .system:
            return "System"
        case .about:
            return "About"
        }
    }

    public func localizedTitle(language: RelayDogResolvedLanguage) -> String {
        switch self {
        case .overview:
            return t("概览", "Overview", language: language)
        case .connections:
            return t("连接", "Connections", language: language)
        case .logs:
            return t("日志", "Logs", language: language)
        case .system:
            return t("系统", "System", language: language)
        case .about:
            return t("关于", "About", language: language)
        }
    }

    public var systemImage: String {
        switch self {
        case .overview:
            return "gauge"
        case .connections:
            return "point.3.connected.trianglepath.dotted"
        case .logs:
            return "doc.text.magnifyingglass"
        case .system:
            return "gearshape"
        case .about:
            return "info.circle"
        }
    }

    public var sections: [SettingsSection] {
        switch self {
        case .overview:
            return [.overview, .routing]
        case .connections:
            return [.upstreams]
        case .logs:
            return [.requestLogs]
        case .system:
            return [.general, .advanced]
        case .about:
            return [.about]
        }
    }
}

public struct RelayDogSettingsAboutDetails: Equatable, Sendable {
    public var title: String
    public var description: String
    public var featureTitles: [String]
    public var storageNote: String

    public init(
        title: String,
        description: String,
        featureTitles: [String],
        storageNote: String
    ) {
        self.title = title
        self.description = description
        self.featureTitles = featureTitles
        self.storageNote = storageNote
    }
}

public struct RelayDogSettingsEndpointItem: Equatable, Sendable {
    public var title: String
    public var value: String

    public init(title: String, value: String) {
        self.title = title
        self.value = value
    }
}

public struct RelayDogSettingsProtocolSummary: Equatable, Sendable {
    public var proto: ProxyProtocol
    public var routeTitle: String
    public var enabledUpstreamCount: Int
    public var modelCount: Int
    public var modelMappingCount: Int

    public init(
        proto: ProxyProtocol,
        routeTitle: String,
        enabledUpstreamCount: Int,
        modelCount: Int,
        modelMappingCount: Int
    ) {
        self.proto = proto
        self.routeTitle = routeTitle
        self.enabledUpstreamCount = enabledUpstreamCount
        self.modelCount = modelCount
        self.modelMappingCount = modelMappingCount
    }
}

public struct RelayDogSettingsUpstreamRow: Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var isEnabled: Bool
    public var protocolTitles: [String]
    public var weight: Int
    public var timeoutTitle: String
    public var note: String

    public init(
        id: String,
        name: String,
        isEnabled: Bool,
        protocolTitles: [String],
        weight: Int,
        timeoutTitle: String,
        note: String
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.protocolTitles = protocolTitles
        self.weight = weight
        self.timeoutTitle = timeoutTitle
        self.note = note
    }
}

public struct RelayDogSettingsModelMappingRow: Equatable, Sendable, Identifiable {
    public var id: String {
        "\(scope)|\(proto.rawValue)|\(clientModel)|\(upstreamModel)"
    }

    public var scope: String
    public var proto: ProxyProtocol
    public var clientModel: String
    public var upstreamModel: String

    public init(scope: String, proto: ProxyProtocol, clientModel: String, upstreamModel: String) {
        self.scope = scope
        self.proto = proto
        self.clientModel = clientModel
        self.upstreamModel = upstreamModel
    }
}
