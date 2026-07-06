import Foundation
import RelayDogCore

public enum RelayDogMenuStatus: String, Equatable, Sendable {
    case running = "Running"
    case degraded = "Degraded"
    case offline = "Offline"
}

public enum RelayDogMenuItemKind: Equatable, Sendable {
    case status
    case listener
    case copyOpenAIEndpoint
    case copyClaudeEndpoint
    case openAIRoutes
    case claudeRoutes
    case requestLogs
    case revealLogFolder
    case settings
    case quit
}

public struct RelayDogMenuItem: Equatable, Sendable {
    public var title: String
    public var kind: RelayDogMenuItemKind

    public init(title: String, kind: RelayDogMenuItemKind) {
        self.title = title
        self.kind = kind
    }
}

public enum RelayDogClientEndpointMenuItemKind: Equatable, Sendable {
    case copyOpenAIEndpoint
    case copyClaudeEndpoint
}

public struct RelayDogClientEndpointMenuItem: Equatable, Sendable {
    public var title: String
    public var value: String
    public var kind: RelayDogClientEndpointMenuItemKind

    public init(title: String, value: String, kind: RelayDogClientEndpointMenuItemKind) {
        self.title = title
        self.value = value
        self.kind = kind
    }
}

public enum RelayDogRouteMenuItemKind: Equatable, Sendable {
    case automatic
    case upstream(String)
    case manageRoutes
}

public struct RelayDogRouteMenuItem: Equatable, Sendable {
    public var title: String
    public var kind: RelayDogRouteMenuItemKind
    public var isSelected: Bool

    public init(title: String, kind: RelayDogRouteMenuItemKind, isSelected: Bool) {
        self.title = title
        self.kind = kind
        self.isSelected = isSelected
    }
}

public enum RelayDogRequestLogMenuItemKind: Equatable, Sendable {
    case openViewer
    case toggleLogging
    case revealLogFolder
}

public struct RelayDogRequestLogMenuItem: Equatable, Sendable {
    public var title: String
    public var kind: RelayDogRequestLogMenuItemKind

    public init(title: String, kind: RelayDogRequestLogMenuItemKind) {
        self.title = title
        self.kind = kind
    }
}

public struct RelayDogMenuViewModel: Sendable {
    private var config: RelayDogConfig
    private var health: HealthState
    private var runtimeState: RelayDogServerState?

    public init(
        config: RelayDogConfig,
        health: HealthState = HealthState(),
        runtimeState: RelayDogServerState? = nil
    ) {
        self.config = config
        self.health = health
        self.runtimeState = runtimeState
    }

    public var status: RelayDogMenuStatus {
        guard config.listener.enabled else {
            return .offline
        }

        if runtimeState == .stopped {
            return .offline
        }

        let enabledProtocols = ProxyProtocol.allCases.filter { proto in
            !enabledUpstreams(for: proto).isEmpty
        }

        guard !enabledProtocols.isEmpty else {
            return .degraded
        }

        let allProtocolsHaveAvailableRoute = enabledProtocols.allSatisfy { proto in
            !availableUpstreams(for: proto).isEmpty
        }

        return allProtocolsHaveAvailableRoute ? .running : .degraded
    }

    public var topLevelItems: [RelayDogMenuItem] {
        [
            .init(title: statusHeadlineTitle, kind: .status),
            .init(title: listenerTitle, kind: .listener),
            .init(title: text("打开设置", "Open Settings"), kind: .settings),
            .init(title: clientEndpointItems[0].title, kind: .copyOpenAIEndpoint),
            .init(title: clientEndpointItems[1].title, kind: .copyClaudeEndpoint),
            .init(title: routeMenuTitle(for: .openAI), kind: .openAIRoutes),
            .init(title: routeMenuTitle(for: .claude), kind: .claudeRoutes),
            .init(title: "\(text("请求日志", "Request Logs")): \(requestLoggingTitle)", kind: .requestLogs),
            .init(title: text("显示日志文件夹", "Reveal Log Folder"), kind: .revealLogFolder),
            .init(title: text("退出 RelayDog", "Quit RelayDog"), kind: .quit)
        ]
    }

    public var clientEndpointItems: [RelayDogClientEndpointMenuItem] {
        [
            .init(
                title: text("复制 OpenAI 地址", "Copy OpenAI Base URL"),
                value: openAIBaseURL,
                kind: .copyOpenAIEndpoint
            ),
            .init(
                title: text("复制 Claude 地址", "Copy Claude Base URL"),
                value: claudeBaseURL,
                kind: .copyClaudeEndpoint
            )
        ]
    }

    public var statusHeadlineTitle: String {
        switch status {
        case .running:
            return text("RelayDog 正在运行", "RelayDog Running")
        case .degraded:
            return text("RelayDog 异常", "RelayDog Degraded")
        case .offline:
            return text("RelayDog 离线", "RelayDog Offline")
        }
    }

    public var listenerTitle: String {
        "\(text("本机监听", "Local Listener")): \(config.listener.host):\(config.listener.port)"
    }

    public var requestLoggingTitle: String {
        config.requestLogging.enabled ? text("开启", "On") : text("关闭", "Off")
    }

    public var statusTitle: String {
        switch status {
        case .running:
            return text("运行", "Running")
        case .degraded:
            return text("异常", "Degraded")
        case .offline:
            return text("离线", "Offline")
        }
    }

    public func selectedRouteTitle(for proto: ProxyProtocol) -> String {
        guard let selectedID = config.routing[proto]?.selectedUpstreamID,
              let upstream = config.upstreams.first(where: { $0.id == selectedID }) else {
            return text("自动", "Auto")
        }
        return upstream.name
    }

    public func routeMenuTitle(for proto: ProxyProtocol) -> String {
        "\(proto.shortRouteName) \(text("路由", "Route")): \(selectedRouteTitle(for: proto))"
    }

    public func routeItems(for proto: ProxyProtocol) -> [RelayDogRouteMenuItem] {
        let routing = config.routing[proto]
        let autoIsSelected = routing?.selectedUpstreamID == nil || routing?.mode != .single
        var items: [RelayDogRouteMenuItem] = [
            .init(title: text("自动", "Auto"), kind: .automatic, isSelected: autoIsSelected)
        ]

        items += availableUpstreams(for: proto).map { upstream in
            RelayDogRouteMenuItem(
                title: upstream.name,
                kind: .upstream(upstream.id),
                isSelected: routing?.mode == .single && routing?.selectedUpstreamID == upstream.id
            )
        }

        return items
    }

    public var requestLogItems: [RelayDogRequestLogMenuItem] {
        [
            .init(
                title: config.requestLogging.enabled
                    ? text("关闭请求日志", "Turn Request Logging Off")
                    : text("开启请求日志", "Turn Request Logging On"),
                kind: .toggleLogging
            )
        ]
    }

    public var effectiveLanguage: RelayDogResolvedLanguage {
        config.language.resolved()
    }

    public func text(_ zh: String, _ en: String) -> String {
        t(zh, en, language: effectiveLanguage)
    }

    private var localEndpoint: String {
        "http://\(config.listener.host):\(config.listener.port)"
    }

    private var openAIBaseURL: String {
        localEndpoint + "/v1"
    }

    private var claudeBaseURL: String {
        localEndpoint
    }

    private func enabledUpstreams(for proto: ProxyProtocol) -> [UpstreamConfig] {
        config.upstreams.filter { upstream in
            upstream.enabled && upstream.protocols[proto]?.enabled == true
        }
    }

    private func availableUpstreams(for proto: ProxyProtocol) -> [UpstreamConfig] {
        enabledUpstreams(for: proto).filter { upstream in
            health.isReachable(upstreamID: upstream.id, proto: proto) != false
        }
    }
}

public extension ProxyProtocol {
    var displayName: String {
        switch self {
        case .openAI:
            return "OpenAI兼容"
        case .claude:
            return "Claude兼容"
        }
    }

    var shortRouteName: String {
        switch self {
        case .openAI:
            return "OpenAI"
        case .claude:
            return "Claude"
        }
    }
}
