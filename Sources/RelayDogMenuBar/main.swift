import AppKit
import SwiftUI
import RelayDogApp
import RelayDogCore

@main
struct RelayDogMenuBarExecutable: App {
    @NSApplicationDelegateAdaptor(RelayDogMenuBarAppDelegate.self) private var appDelegate

    init() {
        RelayDogApplicationIcon.install()
    }

    var body: some Scene {
        Settings {
            RelayDogSettingsRootView(appModel: appDelegate.appModel)
        }
    }
}

@MainActor
private final class RelayDogMenuBarAppDelegate: NSObject, NSApplicationDelegate {
    let appModel = RelayDogAppModel(autostart: true)
    private let settingsWindowPresenter = RelayDogSettingsWindowPresenter()
    private var statusItemController: RelayDogStatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        RelayDogApplicationIcon.install()
        statusItemController = RelayDogStatusItemController(
            appModel: appModel,
            settingsWindowPresenter: settingsWindowPresenter
        )
        settingsWindowPresenter.showOnLaunch {
            RelayDogSettingsRootView(appModel: appModel)
        }
    }
}

@MainActor
private final class RelayDogStatusItemController: NSObject, NSMenuDelegate {
    private let appModel: RelayDogAppModel
    private let settingsWindowPresenter: RelayDogSettingsWindowPresenter
    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    init(
        appModel: RelayDogAppModel,
        settingsWindowPresenter: RelayDogSettingsWindowPresenter
    ) {
        self.appModel = appModel
        self.settingsWindowPresenter = settingsWindowPresenter
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        super.init()

        configureButton()
        menu.delegate = self
        statusItem.menu = menu
        statusItem.isVisible = true
        populateMenu()
    }

    func menuWillOpen(_ menu: NSMenu) {
        populateMenu()
    }

    private func configureButton() {
        guard let button = statusItem.button else {
            return
        }

        button.title = RelayDogMenuBarPresentation.statusItemTitle
        button.font = .systemFont(ofSize: 12, weight: .medium)
        button.image = statusIcon()
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = RelayDogMenuBarPresentation.title
        button.setAccessibilityLabel(RelayDogMenuBarPresentation.title)
    }

    private func statusIcon() -> NSImage? {
        if let image = RelayDogMenuBarPresentation.iconImage?.copy() as? NSImage {
            image.size = RelayDogMenuBarPresentation.statusItemIconSize
            image.isTemplate = false
            return image
        }

        let image = NSImage(
            systemSymbolName: RelayDogMenuBarPresentation.fallbackSystemImage,
            accessibilityDescription: RelayDogMenuBarPresentation.title
        )
        image?.size = RelayDogMenuBarPresentation.statusItemIconSize
        image?.isTemplate = true
        return image
    }

    private func populateMenu() {
        menu.removeAllItems()

        let viewModel = appModel.menuViewModel
        let statusItem = NSMenuItem(
            title: viewModel.statusHeadlineTitle,
            action: nil,
            keyEquivalent: ""
        )
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        let listenerItem = NSMenuItem(
            title: viewModel.listenerTitle,
            action: nil,
            keyEquivalent: ""
        )
        listenerItem.isEnabled = false
        menu.addItem(listenerItem)

        menu.addItem(.separator())
        menu.addItem(RelayDogMenuActionItem(title: viewModel.text("打开设置", "Open Settings")) { [weak self] in
            self?.openSettings()
        })
        for endpointItem in viewModel.clientEndpointItems {
            menu.addItem(RelayDogMenuActionItem(title: endpointItem.title) {
                copyToPasteboard(endpointItem.value)
            })
        }

        menu.addItem(.separator())
        addRouteSubmenu(title: viewModel.routeMenuTitle(for: .openAI), proto: .openAI, viewModel: viewModel)
        addRouteSubmenu(title: viewModel.routeMenuTitle(for: .claude), proto: .claude, viewModel: viewModel)

        menu.addItem(.separator())
        addRequestLogsSubmenu(viewModel: viewModel)
        menu.addItem(RelayDogMenuActionItem(title: viewModel.text("显示日志文件夹", "Reveal Log Folder")) { [weak self] in
            guard let self else {
                return
            }
            NSWorkspace.shared.open(appModel.paths.logsDirectory)
        })

        menu.addItem(.separator())
        menu.addItem(RelayDogMenuActionItem(title: viewModel.text("退出 RelayDog", "Quit RelayDog")) {
            NSApplication.shared.terminate(nil)
        })
    }

    private func addRouteSubmenu(
        title: String,
        proto: ProxyProtocol,
        viewModel: RelayDogMenuViewModel
    ) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        for routeItem in viewModel.routeItems(for: proto) {
            let menuItem = RelayDogMenuActionItem(title: routeItem.title) { [weak self] in
                switch routeItem.kind {
                case .automatic:
                    Task { @MainActor in
                        try? await self?.appModel.selectRoute(protocol: proto, upstreamID: nil)
                    }
                case .upstream(let upstreamID):
                    Task { @MainActor in
                        try? await self?.appModel.selectRoute(protocol: proto, upstreamID: upstreamID)
                    }
                case .manageRoutes:
                    self?.openSettings()
                }
            }
            menuItem.state = routeItem.isSelected ? .on : .off
            submenu.addItem(menuItem)
        }

        item.submenu = submenu
        menu.addItem(item)
    }

    private func addRequestLogsSubmenu(viewModel: RelayDogMenuViewModel) {
        let item = NSMenuItem(
            title: "\(viewModel.text("请求日志", "Request Logs")): \(viewModel.requestLoggingTitle)",
            action: nil,
            keyEquivalent: ""
        )
        let submenu = NSMenu()

        for logItem in viewModel.requestLogItems {
            submenu.addItem(RelayDogMenuActionItem(title: logItem.title) { [weak self] in
                guard let self else {
                    return
                }

                switch logItem.kind {
                case .openViewer:
                    NSWorkspace.shared.open(appModel.paths.logsDirectory)
                case .toggleLogging:
                    Task { @MainActor in
                        try? await appModel.setRequestLoggingEnabled(!appModel.config.requestLogging.enabled)
                    }
                case .revealLogFolder:
                    NSWorkspace.shared.open(appModel.paths.logsDirectory)
                }
            })
        }

        item.submenu = submenu
        menu.addItem(item)
    }

    private func openSettings() {
        settingsWindowPresenter.showFromMenu { [appModel] in
            RelayDogSettingsRootView(appModel: appModel)
        }
    }
}

private func copyToPasteboard(_ value: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
}

@MainActor
private final class RelayDogMenuActionItem: NSMenuItem {
    private let handler: @MainActor () -> Void

    init(title: String, keyEquivalent: String = "", handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: keyEquivalent)
        target = self
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func run() {
        handler()
    }
}

private struct RelayDogSettingsRootView: View {
    @ObservedObject var appModel: RelayDogAppModel

    var body: some View {
        RelayDogSettingsView(
            viewModel: appModel.settingsViewModel,
            actions: RelayDogSettingsActions(
                setLanguage: { language in
                    try? appModel.setLanguage(language)
                },
                setListenerEnabled: { enabled in
                    Task { @MainActor in
                        try? await appModel.setListenerEnabled(enabled)
                    }
                },
                setListenerHost: { host in
                    Task { @MainActor in
                        try? await appModel.setListenerHost(host)
                    }
                },
                setListenerPort: { port in
                    Task { @MainActor in
                        try? await appModel.setListenerPort(port)
                    }
                },
                setRequestLoggingEnabled: { enabled in
                    Task { @MainActor in
                        try? await appModel.setRequestLoggingEnabled(enabled)
                    }
                },
                updateRequestLogging: { requestLogging in
                    Task { @MainActor in
                        try? await appModel.updateRequestLogging(requestLogging)
                    }
                },
                selectRoute: { proto, upstreamID in
                    Task { @MainActor in
                        try? await appModel.selectRoute(protocol: proto, upstreamID: upstreamID)
                    }
                },
                upsertUpstream: { upstream in
                    Task { @MainActor in
                        try? await appModel.upsertUpstream(upstream)
                    }
                },
                deleteUpstream: { upstreamID in
                    Task { @MainActor in
                        try? await appModel.deleteUpstream(id: upstreamID)
                    }
                },
                fetchModels: { upstream, proto in
                    try await appModel.fetchModels(upstream: upstream, protocol: proto)
                },
                debugUpstream: { upstream, proto, model, prompt in
                    try await appModel.debugUpstream(upstream: upstream, protocol: proto, model: model, prompt: prompt)
                },
                checkUpstreamHealth: { upstream, proto in
                    await appModel.checkUpstreamHealth(upstream: upstream, protocol: proto)
                }
            )
        )
    }
}
