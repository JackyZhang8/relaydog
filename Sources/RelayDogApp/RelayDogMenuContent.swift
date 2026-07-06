import SwiftUI
import RelayDogCore

public struct RelayDogMenuContent: View {
    private let viewModel: RelayDogMenuViewModel
    private let selectRoute: (ProxyProtocol, String?) -> Void
    private let copyClientEndpoint: (String) -> Void
    private let openRequestLogViewer: () -> Void
    private let toggleRequestLogging: () -> Void
    private let revealLogFolder: () -> Void
    private let openSettings: () -> Void
    private let quit: () -> Void

    public init(
        viewModel: RelayDogMenuViewModel,
        selectRoute: @escaping (ProxyProtocol, String?) -> Void,
        copyClientEndpoint: @escaping (String) -> Void = { _ in },
        openRequestLogViewer: @escaping () -> Void,
        toggleRequestLogging: @escaping () -> Void,
        revealLogFolder: @escaping () -> Void,
        openSettings: @escaping () -> Void,
        quit: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.selectRoute = selectRoute
        self.copyClientEndpoint = copyClientEndpoint
        self.openRequestLogViewer = openRequestLogViewer
        self.toggleRequestLogging = toggleRequestLogging
        self.revealLogFolder = revealLogFolder
        self.openSettings = openSettings
        self.quit = quit
    }

    public var body: some View {
        Label(viewModel.statusHeadlineTitle, systemImage: viewModel.status.systemImage)
        Text(viewModel.listenerTitle)

        Divider()

        Button(action: openSettings) {
            Label(viewModel.text("打开设置", "Open Settings"), systemImage: "gearshape")
        }
        ForEach(viewModel.clientEndpointItems, id: \.title) { item in
            Button {
                copyClientEndpoint(item.value)
            } label: {
                Label(item.title, systemImage: "doc.on.doc")
            }
        }

        Divider()

        routeMenu(title: viewModel.routeMenuTitle(for: .openAI), protocol: .openAI)
        routeMenu(title: viewModel.routeMenuTitle(for: .claude), protocol: .claude)

        Divider()

        requestLogsMenu
        Button(action: revealLogFolder) {
            Label(viewModel.text("显示日志文件夹", "Reveal Log Folder"), systemImage: "folder")
        }

        Divider()

        Button(action: quit) {
            Label(viewModel.text("退出 RelayDog", "Quit RelayDog"), systemImage: "power")
        }
    }

    private func routeMenu(title: String, protocol proto: ProxyProtocol) -> some View {
        Menu {
            ForEach(viewModel.routeItems(for: proto), id: \.title) { item in
                Button {
                    switch item.kind {
                    case .automatic:
                        selectRoute(proto, nil)
                    case .upstream(let upstreamID):
                        selectRoute(proto, upstreamID)
                    case .manageRoutes:
                        openSettings()
                    }
                } label: {
                    HStack {
                        if item.isSelected {
                            Image(systemName: "checkmark")
                        }
                        Text(item.title)
                    }
                }
            }
        } label: {
            Label(title, systemImage: proto.systemImage)
        }
    }

    private var requestLogsMenu: some View {
        Menu {
            ForEach(viewModel.requestLogItems, id: \.title) { item in
                Button(item.title) {
                    switch item.kind {
                    case .openViewer:
                        openRequestLogViewer()
                    case .toggleLogging:
                        toggleRequestLogging()
                    case .revealLogFolder:
                        revealLogFolder()
                    }
                }
            }
        } label: {
            Label("\(viewModel.text("请求日志", "Request Logs")): \(viewModel.requestLoggingTitle)", systemImage: "doc.text.magnifyingglass")
        }
    }
}

private extension RelayDogMenuStatus {
    var systemImage: String {
        switch self {
        case .running:
            return "checkmark.circle.fill"
        case .degraded:
            return "exclamationmark.triangle.fill"
        case .offline:
            return "xmark.circle.fill"
        }
    }
}

private extension ProxyProtocol {
    var systemImage: String {
        switch self {
        case .openAI:
            return "terminal"
        case .claude:
            return "text.bubble"
        }
    }
}
