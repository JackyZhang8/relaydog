import Foundation

public enum SettingsSection: String, CaseIterable, Hashable, Identifiable, Sendable {
    case overview
    case upstreams
    case routing
    case requestLogs
    case healthAndStatistics
    case general
    case advanced
    case about

    public var id: String {
        rawValue
    }

    public var title: String {
        switch self {
        case .overview:
            return "Overview"
        case .upstreams:
            return "Upstreams"
        case .routing:
            return "Routing"
        case .requestLogs:
            return "Request Logs"
        case .healthAndStatistics:
            return "Health & Statistics"
        case .general:
            return "General"
        case .advanced:
            return "Advanced"
        case .about:
            return "About"
        }
    }
}
