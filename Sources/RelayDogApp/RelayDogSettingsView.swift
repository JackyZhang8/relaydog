import AppKit
import SwiftUI
import RelayDogCore

private let automaticRouteTag = "__relaydog_auto__"
private let formLabelWidth: CGFloat = 132
private let formCornerRadius: CGFloat = 8
private let formHorizontalPadding: CGFloat = 12
private let formVerticalPadding: CGFloat = 10

enum RelayDogControlMetrics {
    static let topTabHorizontalPadding: CGFloat = 18
    static let topTabVerticalPadding: CGFloat = 10
    static let topTabMinHeight: CGFloat = 42
    static let actionButtonHorizontalPadding: CGFloat = 16
    static let actionButtonVerticalPadding: CGFloat = 8
    static let actionButtonMinHeight: CGFloat = 38
    static let iconButtonMinSize: CGFloat = 34
    static let iconButtonVerticalPadding: CGFloat = 4
    static let iconButtonHorizontalPadding: CGFloat = 8
    static let headerLogoSize: CGFloat = 42
    static let headerTopPadding: CGFloat = 22
    static let headerBottomPadding: CGFloat = 10
    static let headerShowsTagline = true
    static let headerShowsLocalEndpoint = false
    static let headerShowsRequestLogToggle = false
    static let overviewShowsRoutingBelowClientURLs = true
    static let overviewShowsProtocolSummaryTiles = false
    static let overviewShowsLocalDataPanel = false
    static let connectionsShowsRoutingPanel = false
    static let logsShowsHealthAndStatisticsPanel = false
    static let upstreamPanelUsesInlineAddButton = true
    static let upstreamRowShowsSubtitle = false
    static let iconButtonsUseSquareFrame = true
    static let deleteActionsRequireConfirmation = true
    static let menuFieldUsesOuterBackground = false
    static let menuFieldUsesBorderlessButtonStyle = true
    static let clickableButtonsUsePointingHandCursor = true
    static let openURLIconUsesBorder = false
    static let openURLIconSize: CGFloat = 19
    static let popupCloseButtonsUseBorder = false
    static let popupCloseButtonSize: CGFloat = 32
    static let upstreamTestPromptMinHeight: CGFloat = 42
    static let upstreamTestPromptMaxHeight: CGFloat = 55
    static let upstreamTestDebugTextHeight: CGFloat = 76
    static let upstreamTestCloseUsesIconOnly = true
    static let upstreamTestDebugUsesTerminalChrome = true
    static let upstreamListUsesInlineEnabledToggle = true
    static let upstreamEditorShowsUpstreamEnabledToggle = false
    static let upstreamEditorCloseUsesIconOnly = true
    static let copyButtonsShowCopiedFeedback = true
    static let copyFeedbackDurationNanoseconds: UInt64 = 1_200_000_000

    static func copyFeedbackMessage(language: RelayDogResolvedLanguage) -> String {
        t("已复制", "Copied", language: language)
    }
}

private extension View {
    func relayDogTextFieldFrame() -> some View {
        font(.body)
            .padding(.horizontal, formHorizontalPadding)
            .padding(.vertical, formVerticalPadding)
            .background(FormFieldBackground())
    }

    func relayDogMenuField(width: CGFloat? = nil) -> some View {
        modifier(RelayDogMenuFieldModifier(width: width))
    }

    func relayDogSecondaryButton() -> some View {
        buttonStyle(RelayDogActionButtonStyle(prominence: .secondary))
    }

    func relayDogPrimaryButton() -> some View {
        buttonStyle(RelayDogActionButtonStyle(prominence: .primary))
    }

    func relayDogLargeButton() -> some View {
        buttonStyle(RelayDogActionButtonStyle(prominence: .secondary))
    }

    func relayDogIconButton() -> some View {
        labelStyle(.iconOnly)
            .buttonStyle(RelayDogIconButtonStyle())
            .contentShape(Rectangle())
    }

    func relayDogPopupCloseButton() -> some View {
        buttonStyle(.plain)
            .labelStyle(.iconOnly)
            .foregroundStyle(.secondary)
            .frame(
                width: RelayDogControlMetrics.popupCloseButtonSize,
                height: RelayDogControlMetrics.popupCloseButtonSize
            )
            .contentShape(Rectangle())
            .relayDogClickableCursor()
    }

    func relayDogOpenURLIconButton() -> some View {
        buttonStyle(.plain)
            .labelStyle(.iconOnly)
            .font(.system(size: RelayDogControlMetrics.openURLIconSize, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
            .relayDogClickableCursor()
    }

    func relayDogClickableCursor(enabled: Bool = true) -> some View {
        onHover { isHovering in
            guard enabled else {
                return
            }

            if isHovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

private struct RelayDogMenuFieldModifier: ViewModifier {
    var width: CGFloat?

    @ViewBuilder
    func body(content: Content) -> some View {
        let field = content
            .pickerStyle(.menu)
            .labelsHidden()
            .buttonStyle(.borderless)
            .controlSize(.large)
            .frame(minHeight: 34)

        if let width {
            field.frame(width: width, alignment: .leading)
        } else {
            field.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct RelayDogIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, RelayDogControlMetrics.iconButtonHorizontalPadding)
            .padding(.vertical, RelayDogControlMetrics.iconButtonVerticalPadding)
            .frame(
                width: RelayDogControlMetrics.iconButtonMinSize,
                height: RelayDogControlMetrics.iconButtonMinSize
            )
            .foregroundStyle(isEnabled ? Color(nsColor: .labelColor) : Color(nsColor: .disabledControlTextColor))
            .background(
                RoundedRectangle(cornerRadius: formCornerRadius)
                    .fill(configuration.isPressed ? pressedBackgroundColor : Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: formCornerRadius)
                    .stroke(Color(nsColor: .separatorColor).opacity(isEnabled ? 0.55 : 0.25), lineWidth: 1)
            )
            .relayDogClickableCursor(enabled: isEnabled)
    }

    private var pressedBackgroundColor: Color {
        Color(nsColor: .selectedControlColor).opacity(0.18)
    }
}

private struct RelayDogActionButtonStyle: ButtonStyle {
    enum Prominence {
        case primary
        case secondary
    }

    @Environment(\.isEnabled) private var isEnabled
    let prominence: Prominence

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.medium))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, RelayDogControlMetrics.actionButtonHorizontalPadding)
            .padding(.vertical, RelayDogControlMetrics.actionButtonVerticalPadding)
            .frame(minHeight: RelayDogControlMetrics.actionButtonMinHeight)
            .foregroundStyle(foregroundColor)
            .background(
                RoundedRectangle(cornerRadius: formCornerRadius)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: formCornerRadius)
                    .stroke(borderColor, lineWidth: 1)
            )
            .opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.5)
            .relayDogClickableCursor(enabled: isEnabled)
    }

    private var foregroundColor: Color {
        prominence == .primary && isEnabled ? .white : Color(nsColor: .labelColor)
    }

    private var backgroundColor: Color {
        if prominence == .primary && isEnabled {
            return Color.accentColor
        }
        return Color(nsColor: .controlBackgroundColor)
    }

    private var borderColor: Color {
        if prominence == .primary && isEnabled {
            return Color.accentColor.opacity(0.85)
        }
        return Color(nsColor: .separatorColor).opacity(0.65)
    }
}

public struct RelayDogSettingsView: View {
    @State private var selection: RelayDogSettingsTab = .overview
    private let viewModel: RelayDogSettingsViewModel
    private let actions: RelayDogSettingsActions

    public init(
        viewModel: RelayDogSettingsViewModel,
        actions: RelayDogSettingsActions = RelayDogSettingsActions()
    ) {
        self.viewModel = viewModel
        self.actions = actions
    }

    public var body: some View {
        VStack(spacing: 0) {
            SettingsHeaderView(viewModel: viewModel, actions: actions)
                .padding(.horizontal, 20)
                .padding(.top, RelayDogControlMetrics.headerTopPadding)
                .padding(.bottom, RelayDogControlMetrics.headerBottomPadding)

            Divider()

            SettingsTabBar(selection: $selection, language: viewModel.effectiveLanguage)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 2)

            SettingsTabContent(tab: selection, viewModel: viewModel, actions: actions)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(minWidth: 860, minHeight: 620)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct SettingsTabBar: View {
    @Binding var selection: RelayDogSettingsTab
    let language: RelayDogResolvedLanguage

    var body: some View {
        HStack(spacing: 8) {
            ForEach(RelayDogSettingsTab.allCases) { tab in
                SettingsTabButton(
                    tab: tab,
                    language: language,
                    isSelected: selection == tab,
                    select: { selection = tab }
                )
            }
        }
    }
}

private struct SettingsTabButton: View {
    let tab: RelayDogSettingsTab
    let language: RelayDogResolvedLanguage
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            Label(tab.localizedTitle(language: language), systemImage: tab.systemImage)
                .font(.callout.weight(.medium))
                .labelStyle(.titleAndIcon)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, RelayDogControlMetrics.topTabHorizontalPadding)
                .padding(.vertical, RelayDogControlMetrics.topTabVerticalPadding)
                .frame(maxWidth: .infinity, minHeight: RelayDogControlMetrics.topTabMinHeight)
                .background(
                    RoundedRectangle(cornerRadius: formCornerRadius)
                        .fill(isSelected ? Color.accentColor.opacity(0.14) : Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: formCornerRadius)
                        .stroke(isSelected ? Color.accentColor.opacity(0.45) : Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.accentColor : Color(nsColor: .labelColor))
        .relayDogClickableCursor()
    }
}

private struct SettingsHeaderView: View {
    let viewModel: RelayDogSettingsViewModel
    let actions: RelayDogSettingsActions

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            HeaderLogo()

            VStack(alignment: .leading, spacing: 4) {
                Text("RelayDog")
                    .font(.title3.weight(.semibold))
                Text(viewModel.headerTagline)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            HeaderToggle(
                title: viewModel.text("监听", "Listener"),
                systemImage: "network",
                isOn: viewModel.config.listener.enabled,
                setIsOn: actions.setListenerEnabled
            )
        }
    }
}

private struct HeaderLogo: View {
    var body: some View {
        if let image = RelayDogBrandAssets.logoImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(
                    width: RelayDogControlMetrics.headerLogoSize,
                    height: RelayDogControlMetrics.headerLogoSize
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
        }
    }
}

private struct SettingsTabContent: View {
    let tab: RelayDogSettingsTab
    let viewModel: RelayDogSettingsViewModel
    let actions: RelayDogSettingsActions

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch tab {
                case .overview:
                    OverviewSettingsPage(viewModel: viewModel, actions: actions)
                case .connections:
                    ConnectionsSettingsPage(viewModel: viewModel, actions: actions)
                case .logs:
                    LogsSettingsPage(viewModel: viewModel, actions: actions)
                case .system:
                    SystemSettingsPage(viewModel: viewModel, actions: actions)
                case .about:
                    AboutSettingsPage(viewModel: viewModel)
                }
            }
            .padding(.top, 16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

private struct OverviewSettingsPage: View {
    let viewModel: RelayDogSettingsViewModel
    let actions: RelayDogSettingsActions

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsPanel(viewModel.text("客户端地址", "Client URLs"), systemImage: "link") {
                VStack(spacing: 0) {
                    ForEach(viewModel.endpointItems, id: \.title) { item in
                        CopyableValueRow(
                            title: item.title,
                            value: item.value,
                            copiedMessage: RelayDogControlMetrics.copyFeedbackMessage(language: viewModel.effectiveLanguage)
                        )
                        if item.title != viewModel.endpointItems.last?.title {
                            Divider()
                        }
                    }
                }
            }

            RoutingSettingsPanel(viewModel: viewModel, actions: actions)
        }
    }
}

private struct AboutSettingsPage: View {
    let viewModel: RelayDogSettingsViewModel

    var body: some View {
        let details = viewModel.aboutDetails

        VStack(alignment: .leading, spacing: 16) {
            SettingsPanel(details.title, systemImage: "info.circle") {
                VStack(alignment: .leading, spacing: 14) {
                    Text(details.description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], alignment: .leading, spacing: 10) {
                        ForEach(details.featureTitles, id: \.self) { title in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text(title)
                                    .font(.callout.weight(.medium))
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(FormFieldBackground())
                        }
                    }
                }
            }

            SettingsPanel(viewModel.text("项目", "Project"), systemImage: "curlybraces") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(details.storageNote)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    OpenURLRow(title: "GitHub", value: "https://github.com/JackyZhang8/relaydog", url: URL(string: "https://github.com/JackyZhang8/relaydog")!)
                }
            }
        }
    }
}

private struct RoutingSettingsPanel: View {
    let viewModel: RelayDogSettingsViewModel
    let actions: RelayDogSettingsActions

    var body: some View {
        SettingsPanel(viewModel.text("路由", "Routing"), systemImage: "arrow.triangle.branch") {
            VStack(spacing: 0) {
                ForEach(viewModel.protocolSummaries, id: \.proto) { summary in
                    EditableRouteRow(
                        proto: summary.proto,
                        language: viewModel.effectiveLanguage,
                        selectedUpstreamID: viewModel.config.routing[summary.proto]?.selectedUpstreamID,
                        upstreams: routeUpstreams(for: summary.proto),
                        modelCount: summary.modelCount,
                        modelMappingCount: summary.modelMappingCount,
                        selectRoute: actions.selectRoute
                    )
                    if summary.proto != viewModel.protocolSummaries.last?.proto {
                        Divider()
                    }
                }
            }
        }
    }

    private func routeUpstreams(for proto: ProxyProtocol) -> [UpstreamConfig] {
        viewModel.config.upstreams.filter { upstream in
            upstream.enabled && upstream.protocols[proto]?.enabled == true
        }
    }
}

private struct ConnectionsSettingsPage: View {
    let viewModel: RelayDogSettingsViewModel
    let actions: RelayDogSettingsActions
    @State private var editingUpstream: UpstreamEditorSelection?
    @State private var testingUpstream: UpstreamEditorSelection?
    @State private var isAddingUpstream = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsPanelWithAction(
                viewModel.text("中转站", "Upstreams"),
                systemImage: "server.rack"
            ) {
                Button {
                    isAddingUpstream = true
                } label: {
                    Label(viewModel.text("添加中转站", "Add Upstream"), systemImage: "plus")
                }
                .relayDogSecondaryButton()
            } content: {
                VStack(alignment: .leading, spacing: 10) {
                    if viewModel.config.upstreams.isEmpty {
                        EmptyStateRow(title: viewModel.text("尚未配置中转站", "No upstreams configured"), systemImage: "tray")
                    } else {
                        VStack(spacing: 0) {
                            ForEach(viewModel.config.upstreams, id: \.id) { upstream in
                                EditableUpstreamRow(
                                    upstream: upstream,
                                    language: viewModel.effectiveLanguage,
                                    setEnabled: { isEnabled in
                                        var updated = upstream
                                        updated.enabled = isEnabled
                                        actions.upsertUpstream(updated)
                                    },
                                    edit: { editingUpstream = UpstreamEditorSelection(upstream: upstream) },
                                    test: { testingUpstream = UpstreamEditorSelection(upstream: upstream) },
                                    delete: { actions.deleteUpstream(upstream.id) }
                                )
                                if upstream.id != viewModel.config.upstreams.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isAddingUpstream) {
            UpstreamEditorSheet(
                title: viewModel.text("添加中转站", "Add Upstream"),
                language: viewModel.effectiveLanguage,
                upstream: nil,
                fetchModels: actions.fetchModels,
                checkHealth: actions.checkUpstreamHealth,
                save: actions.upsertUpstream
            )
        }
        .sheet(item: $editingUpstream) { selection in
            UpstreamEditorSheet(
                title: viewModel.text("编辑中转站", "Edit Upstream"),
                language: viewModel.effectiveLanguage,
                upstream: selection.upstream,
                fetchModels: actions.fetchModels,
                checkHealth: actions.checkUpstreamHealth,
                save: actions.upsertUpstream
            )
        }
        .sheet(item: $testingUpstream) { selection in
            UpstreamTestSheet(
                upstream: selection.upstream,
                language: viewModel.effectiveLanguage,
                debugUpstream: actions.debugUpstream
            )
        }
    }
}

private struct LogsSettingsPage: View {
    let viewModel: RelayDogSettingsViewModel
    let actions: RelayDogSettingsActions

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsPanel(viewModel.text("请求日志", "Request Logs"), systemImage: "doc.text.magnifyingglass") {
                VStack(spacing: 0) {
                    ToggleSettingRow(
                        title: viewModel.text("请求日志", "Request Logging"),
                        isOn: viewModel.config.requestLogging.enabled,
                        setIsOn: actions.setRequestLoggingEnabled
                    )
                    Divider()
                    EditableIntegerRow(
                        title: viewModel.text("最大文件大小", "Max File Size"),
                        value: max(1, viewModel.config.requestLogging.maxFileBytes / 1024 / 1024),
                        suffix: "MB",
                        range: 1...4096,
                        save: { megabytes in
                            var requestLogging = viewModel.config.requestLogging
                            requestLogging.maxFileBytes = megabytes * 1024 * 1024
                            actions.updateRequestLogging(requestLogging)
                        }
                    )
                    Divider()
                    EditableIntegerRow(
                        title: viewModel.text("保留时间", "Retention"),
                        value: viewModel.config.requestLogging.retentionDays,
                        suffix: viewModel.text("天", "days"),
                        range: 1...365,
                        save: { days in
                            var requestLogging = viewModel.config.requestLogging
                            requestLogging.retentionDays = days
                            actions.updateRequestLogging(requestLogging)
                        }
                    )
                    Divider()
                    ToggleSettingRow(
                        title: viewModel.text("响应 Body", "Response Body"),
                        isOn: viewModel.config.requestLogging.recordResponseBody,
                        setIsOn: { enabled in
                            var requestLogging = viewModel.config.requestLogging
                            requestLogging.recordResponseBody = enabled
                            actions.updateRequestLogging(requestLogging)
                        }
                    )
                    Divider()
                    OpenURLRow(title: viewModel.text("文件夹", "Folder"), value: viewModel.paths.logsDirectory.path, url: viewModel.paths.logsDirectory)
                }
            }
        }
    }
}

private struct SystemSettingsPage: View {
    let viewModel: RelayDogSettingsViewModel
    let actions: RelayDogSettingsActions

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsPanel(viewModel.text("语言", "Language"), systemImage: "globe") {
                HStack(spacing: 12) {
                    FormPickerRow(
                        title: viewModel.text("界面语言", "Interface Language"),
                        selection: Binding(
                            get: { viewModel.config.language },
                            set: { actions.setLanguage($0) }
                        )
                    ) {
                        ForEach(viewModel.languageOptions) { option in
                            Text(option.title).tag(option.preference)
                        }
                    }
                }
            }

            SettingsPanel(viewModel.text("监听", "Listener"), systemImage: "network") {
                VStack(spacing: 0) {
                    ListenerHostRow(
                        language: viewModel.effectiveLanguage,
                        host: viewModel.config.listener.host,
                        save: actions.setListenerHost
                    )
                    Divider()
                    EditableIntegerRow(
                        title: "Port",
                        value: viewModel.config.listener.port,
                        suffix: "",
                        range: 1...65_535,
                        save: actions.setListenerPort
                    )
                    Divider()
                    ToggleSettingRow(
                        title: viewModel.text("状态", "State"),
                        isOn: viewModel.config.listener.enabled,
                        setIsOn: actions.setListenerEnabled
                    )
                }
            }

            SettingsPanel(viewModel.text("文件", "Files"), systemImage: "folder.badge.gearshape") {
                VStack(spacing: 0) {
                    OpenURLRow(title: viewModel.text("数据目录", "Data Directory"), value: viewModel.paths.dataDirectory.path, url: viewModel.paths.dataDirectory)
                    Divider()
                    OpenURLRow(title: viewModel.text("配置文件", "Config File"), value: viewModel.paths.configFile.path, url: viewModel.paths.configFile)
                }
            }
        }
    }
}

private struct SettingsPanel<Content: View>: View {
    private let title: String
    private let systemImage: String
    private let content: Content

    init(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.semibold))

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        )
    }
}

private struct SettingsPanelWithAction<Content: View, Action: View>: View {
    private let title: String
    private let systemImage: String
    private let action: Action
    private let content: Content

    init(
        _ title: String,
        systemImage: String,
        @ViewBuilder action: () -> Action,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.action = action()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Label(title, systemImage: systemImage)
                    .font(.headline.weight(.semibold))
                Spacer()
                action
            }

            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 1)
        )
    }
}

private struct HeaderToggle: View {
    let title: String
    let systemImage: String
    let isOn: Bool
    let setIsOn: (Bool) -> Void

    var body: some View {
        Toggle(
            isOn: Binding(
                get: { isOn },
                set: { setIsOn($0) }
            )
        ) {
            Label(title, systemImage: systemImage)
                .font(.callout.weight(.medium))
        }
        .toggleStyle(.switch)
        .fixedSize()
    }
}

private struct ToggleSettingRow: View {
    let title: String
    let isOn: Bool
    let setIsOn: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: formLabelWidth, alignment: .leading)
            Spacer()
            Toggle(
                "",
                isOn: Binding(
                    get: { isOn },
                    set: { setIsOn($0) }
                )
            )
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding(.vertical, 9)
    }
}

private struct EditableIntegerRow: View {
    let title: String
    let value: Int
    let suffix: String
    let range: ClosedRange<Int>
    let save: (Int) -> Void
    @State private var text: String

    init(title: String, value: Int, suffix: String, range: ClosedRange<Int>, save: @escaping (Int) -> Void) {
        self.title = title
        self.value = value
        self.suffix = suffix
        self.range = range
        self.save = save
        _text = State(initialValue: "\(value)")
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: formLabelWidth, alignment: .leading)
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.body.monospacedDigit())
                .multilineTextAlignment(.trailing)
                .frame(width: 84)
                .relayDogTextFieldFrame()
                .onSubmit(commit)
            if !suffix.isEmpty {
                Text(suffix)
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .leading)
            }
            Spacer()
            Button(action: commit) {
                Image(systemName: "checkmark")
            }
            .relayDogIconButton()
            .help("Save")
            .disabled(parsedValue == nil)
        }
        .padding(.vertical, 9)
        .onChange(of: value) { newValue in
            text = "\(newValue)"
        }
    }

    private var parsedValue: Int? {
        guard let value = Int(text.trimmingCharacters(in: .whitespacesAndNewlines)),
              range.contains(value) else {
            return nil
        }
        return value
    }

    private func commit() {
        guard let parsedValue else {
            return
        }
        save(parsedValue)
    }
}

private struct ListenerHostRow: View {
    let language: RelayDogResolvedLanguage
    let host: String
    let save: (String) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("Host")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: formLabelWidth, alignment: .leading)

            Picker(
                "",
                selection: Binding(
                    get: { host },
                    set: { newHost in
                        save(newHost)
                    }
                )
            ) {
                Text(t("本机 127.0.0.1", "Local 127.0.0.1", language: language)).tag("127.0.0.1")
                Text(t("局域网 0.0.0.0", "LAN 0.0.0.0", language: language)).tag("0.0.0.0")
            }
            .relayDogMenuField(width: 240)

            Spacer()

            Text(host == "0.0.0.0" ? t("允许外部连接", "External connections", language: language) : t("仅本机", "Local only", language: language))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 9)
    }
}

private struct OpenURLRow: View {
    let title: String
    let value: String
    let url: URL

    var body: some View {
        HStack(spacing: 12) {
            ValueRow(title: title, value: value)

            Button {
                openURL(url)
            } label: {
                Image(systemName: iconName)
            }
            .relayDogOpenURLIconButton()
            .help("Open")
        }
    }

    private var iconName: String {
        guard url.isFileURL else {
            return "arrow.up.forward.app"
        }
        return url.hasDirectoryPath ? "folder" : "doc.text"
    }
}

private struct EditableRouteRow: View {
    let proto: ProxyProtocol
    let language: RelayDogResolvedLanguage
    let selectedUpstreamID: String?
    let upstreams: [UpstreamConfig]
    let modelCount: Int
    let modelMappingCount: Int
    let selectRoute: (ProxyProtocol, String?) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ProtocolBadge(title: proto.displayName)
                .frame(width: 86, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(t("当前路由", "Current Route", language: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(routeTitle)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    ValuePill(title: "\(modelCount) \(t("个模型", "models", language: language))")
                    ValuePill(title: "\(modelMappingCount) \(t("个映射", "mappings", language: language))")
                }
            }

            Spacer()

            Picker(
                "",
                selection: Binding(
                    get: { selectedUpstreamID ?? automaticRouteTag },
                    set: { selectRoute(proto, $0 == automaticRouteTag ? nil : $0) }
                )
            ) {
                Text(t("自动", "Auto", language: language)).tag(automaticRouteTag)
                ForEach(upstreams, id: \.id) { upstream in
                    Text(upstream.name).tag(upstream.id)
                }
            }
            .relayDogMenuField(width: 240)
        }
        .padding(.vertical, 10)
    }

    private var routeTitle: String {
        upstreams.first(where: { $0.id == selectedUpstreamID })?.name ?? t("自动", "Auto", language: language)
    }
}

private struct EditableUpstreamRow: View {
    let upstream: UpstreamConfig
    let language: RelayDogResolvedLanguage
    let setEnabled: (Bool) -> Void
    let edit: () -> Void
    let test: () -> Void
    let delete: () -> Void
    @State private var isConfirmingDelete = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Toggle(
                "",
                isOn: Binding(
                    get: { upstream.enabled },
                    set: { setEnabled($0) }
                )
            )
            .toggleStyle(.switch)
            .labelsHidden()
            .frame(width: 46, alignment: .leading)
            .help(upstream.enabled ? t("停用", "Disable", language: language) : t("启用", "Enable", language: language))

            VStack(alignment: .leading, spacing: 5) {
                Text(upstream.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 6) {
                ForEach(protocolTitles, id: \.self) { title in
                    ProtocolBadge(title: title)
                }
            }

            Text("w\(upstream.weight)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)

            Text("\(upstream.timeoutSeconds)s")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .trailing)

            Button(action: test) {
                Label(t("测试", "Test", language: language), systemImage: "play.circle")
            }
            .relayDogSecondaryButton()
            .help("Test")

            Button(action: edit) {
                Image(systemName: "pencil")
            }
            .relayDogIconButton()
            .help("Edit")

            Button(role: .destructive) {
                isConfirmingDelete = true
            } label: {
                Image(systemName: "trash")
            }
            .relayDogIconButton()
            .help("Delete")
        }
        .padding(.vertical, 10)
        .confirmationDialog(
            t("删除中转站？", "Delete upstream?", language: language),
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button(t("删除", "Delete", language: language), role: .destructive) {
                delete()
            }
            Button(t("取消", "Cancel", language: language), role: .cancel) {}
        } message: {
            Text(t("删除后将移除此中转站配置。", "This removes the upstream configuration.", language: language))
        }
    }

    private var protocolTitles: [String] {
        ProxyProtocol.allCases.compactMap { proto in
            upstream.protocols[proto]?.enabled == true ? proto.displayName : nil
        }
    }
}

private struct UpstreamEditorSelection: Identifiable {
    var upstream: UpstreamConfig

    var id: String {
        upstream.id
    }
}

private enum UpstreamEditorTab: String, CaseIterable, Identifiable {
    case basic
    case models
    case configuration

    var id: String {
        rawValue
    }

    func localizedTitle(language: RelayDogResolvedLanguage) -> String {
        switch self {
        case .basic:
            return t("基础", "Basic", language: language)
        case .models:
            return t("模型", "Models", language: language)
        case .configuration:
            return t("配置", "Config", language: language)
        }
    }
}

private struct UpstreamEditorSheet: View {
    let title: String
    let language: RelayDogResolvedLanguage
    let fetchModels: (UpstreamConfig, ProxyProtocol) async throws -> [String]
    let checkHealth: (UpstreamConfig, ProxyProtocol) async -> UpstreamHealth?
    let save: (UpstreamConfig) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var enabled: Bool
    @State private var weight: String
    @State private var timeoutSeconds: String
    @State private var note: String
    @State private var openAI: ProtocolCapabilityDraft
    @State private var claude: ProtocolCapabilityDraft
    @State private var selectedProtocol: ProxyProtocol = .openAI
    @State private var selectedTab: UpstreamEditorTab = .basic
    private let id: String

    init(
        title: String,
        language: RelayDogResolvedLanguage,
        upstream: UpstreamConfig?,
        fetchModels: @escaping (UpstreamConfig, ProxyProtocol) async throws -> [String],
        checkHealth: @escaping (UpstreamConfig, ProxyProtocol) async -> UpstreamHealth?,
        save: @escaping (UpstreamConfig) -> Void
    ) {
        self.title = title
        self.language = language
        self.fetchModels = fetchModels
        self.checkHealth = checkHealth
        self.save = save
        let draft = RelayDogUpstreamEditorDraft(upstream: upstream)
        id = draft.id
        _name = State(initialValue: draft.name)
        _enabled = State(initialValue: draft.enabled)
        _weight = State(initialValue: draft.weightText)
        _timeoutSeconds = State(initialValue: draft.timeoutSecondsText)
        _note = State(initialValue: draft.note)
        _openAI = State(initialValue: ProtocolCapabilityDraft(proto: .openAI, capability: draft.openAI))
        _claude = State(initialValue: ProtocolCapabilityDraft(proto: .claude, capability: draft.claude))
        let initialProtocol: ProxyProtocol
        if upstream?.protocols[.openAI]?.enabled == true {
            initialProtocol = .openAI
        } else if upstream?.protocols[.claude]?.enabled == true {
            initialProtocol = .claude
        } else {
            initialProtocol = .openAI
        }
        _selectedProtocol = State(initialValue: initialProtocol)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Text(title)
                    .font(.title3.weight(.semibold))

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                }
                .relayDogPopupCloseButton()
                .help(t("关闭", "Close", language: language))
                .accessibilityLabel(t("关闭", "Close", language: language))
            }

            Picker("", selection: $selectedTab) {
                ForEach(UpstreamEditorTab.allCases) { tab in
                    Text(tab.localizedTitle(language: language)).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.large)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case .basic:
                        UpstreamBasicEditor(
                            language: language,
                            name: $name,
                            selectedProtocol: $selectedProtocol,
                            note: $note,
                            openAI: $openAI,
                            claude: $claude
                        )
                    case .models:
                        UpstreamModelsEditor(
                            proto: selectedProtocol,
                            language: language,
                            draft: selectedDraft,
                            upstream: makeUpstream,
                            fetchModels: fetchModels
                        )
                    case .configuration:
                        UpstreamConfigurationEditor(
                            language: language,
                            weight: $weight,
                            timeoutSeconds: $timeoutSeconds,
                            healthCheckPath: selectedHealthCheckPath,
                            proto: selectedProtocol,
                            upstream: makeUpstream,
                            checkHealth: checkHealth
                        )
                    }
                }
                .padding(.trailing, 4)
            }

            HStack {
                Spacer()
                Button(t("取消", "Cancel", language: language)) {
                    dismiss()
                }
                .relayDogSecondaryButton()
                Button(t("保存", "Save", language: language)) {
                    save(makeUpstream())
                    dismiss()
                }
                .relayDogPrimaryButton()
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 760, height: 580)
        .onAppear {
            enableSelectedProtocol()
        }
        .onChange(of: selectedProtocol) { _ in
            enableSelectedProtocol()
        }
    }

    private func enableSelectedProtocol() {
        if selectedProtocol == .openAI {
            openAI.enabled = true
        } else {
            claude.enabled = true
        }
    }

    private var selectedDraft: Binding<ProtocolCapabilityDraft> {
        selectedProtocol == .openAI ? $openAI : $claude
    }

    private var selectedHealthCheckPath: Binding<String> {
        Binding(
            get: {
                selectedProtocol == .openAI ? openAI.healthCheckPath : claude.healthCheckPath
            },
            set: { newValue in
                if selectedProtocol == .openAI {
                    openAI.healthCheckPath = newValue
                } else {
                    claude.healthCheckPath = newValue
                }
            }
        )
    }

    private func makeUpstream() -> UpstreamConfig {
        RelayDogUpstreamEditorDraft(
            id: id,
            name: name,
            enabled: enabled,
            weightText: weight,
            timeoutSecondsText: timeoutSeconds,
            note: note,
            openAI: openAI.makeConfig(),
            claude: claude.makeConfig()
        ).makeUpstream()
    }
}

private struct ProtocolCapabilityDraft {
    var enabled: Bool
    var baseURL: String
    var apiKey: String
    var healthCheckPath: String
    var modelSync: ModelSyncMode
    var modelsText: String
    var headerOverrides: [String: String]
    var modelMappings: [String: String]

    init(proto: ProxyProtocol, capability: ProtocolCapabilityConfig?) {
        enabled = capability?.enabled ?? false
        baseURL = capability?.baseURL ?? (proto == .openAI ? "https://api.example.com/v1" : "https://api.example.com")
        apiKey = capability?.apiKey ?? ""
        healthCheckPath = capability?.healthCheckPath ?? "/v1/models"
        modelSync = capability?.modelSync ?? .manual
        modelsText = (capability?.models ?? []).joined(separator: ", ")
        headerOverrides = capability?.headerOverrides ?? [:]
        modelMappings = capability?.modelMappings ?? [:]
    }

    func makeConfig() -> ProtocolCapabilityConfig {
        ProtocolCapabilityConfig(
            enabled: enabled,
            baseURL: baseURL.trimmingCharacters(in: .whitespacesAndNewlines),
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            headerOverrides: headerOverrides,
            healthCheckPath: healthCheckPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "/v1/models" : healthCheckPath.trimmingCharacters(in: .whitespacesAndNewlines),
            modelSync: modelSync,
            models: commaSeparatedValues(modelsText),
            modelMappings: modelMappings
        )
    }
}

private struct UpstreamBasicEditor: View {
    let language: RelayDogResolvedLanguage
    @Binding var name: String
    @Binding var selectedProtocol: ProxyProtocol
    @Binding var note: String
    @Binding var openAI: ProtocolCapabilityDraft
    @Binding var claude: ProtocolCapabilityDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            FormTextRow(title: t("名称", "Name", language: language), text: $name)
            ProtocolChoiceRow(language: language, selectedProtocol: $selectedProtocol)
            FormTextRow(title: "Base URL", text: selectedBaseURL)
            FormTextRow(title: "API Key", text: selectedAPIKey)
            FormTextRow(title: t("备注", "Note", language: language), text: $note)
        }
    }

    private var selectedBaseURL: Binding<String> {
        Binding(
            get: {
                selectedProtocol == .openAI ? openAI.baseURL : claude.baseURL
            },
            set: { newValue in
                if selectedProtocol == .openAI {
                    openAI.baseURL = newValue
                } else {
                    claude.baseURL = newValue
                }
            }
        )
    }

    private var selectedAPIKey: Binding<String> {
        Binding(
            get: {
                selectedProtocol == .openAI ? openAI.apiKey : claude.apiKey
            },
            set: { newValue in
                if selectedProtocol == .openAI {
                    openAI.apiKey = newValue
                } else {
                    claude.apiKey = newValue
                }
            }
        )
    }
}

private struct ProtocolChoiceRow: View {
    let language: RelayDogResolvedLanguage
    @Binding var selectedProtocol: ProxyProtocol

    var body: some View {
        HStack(spacing: 12) {
            Text(t("类型", "Type", language: language))
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: formLabelWidth, alignment: .leading)

            HStack(spacing: 10, content: protocolButtons)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func protocolButtons() -> some View {
        ForEach(ProxyProtocol.allCases, id: \.self) { proto in
            protocolButton(proto)
        }
    }

    private func protocolButton(_ proto: ProxyProtocol) -> some View {
        let isSelected = selectedProtocol == proto
        return Button {
            selectedProtocol = proto
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                Text(proto.displayName)
                    .font(.body.weight(.medium))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(FormFieldBackground())
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor.opacity(0.75) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .relayDogClickableCursor()
    }
}

private struct UpstreamModelsEditor: View {
    let proto: ProxyProtocol
    let language: RelayDogResolvedLanguage
    @Binding var draft: ProtocolCapabilityDraft
    let upstream: () -> UpstreamConfig
    let fetchModels: (UpstreamConfig, ProxyProtocol) async throws -> [String]
    @State private var manualModel = ""
    @State private var isSyncing = false
    @State private var syncError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("模型列表", "Model List", language: language))
                        .font(.headline)
                    Text(proto.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    syncModels()
                } label: {
                    Label(isSyncing ? t("同步中", "Syncing", language: language) : t("同步", "Sync", language: language), systemImage: "arrow.triangle.2.circlepath")
                }
                .relayDogLargeButton()
                .disabled(isSyncing || draft.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            ModelListView(
                models: commaSeparatedValues(draft.modelsText),
                language: language,
                remove: removeModel
            )
            .padding(.top, 2)

            HStack(spacing: 10) {
                TextField(t("手工填写模型名称", "Enter model name manually", language: language), text: $manualModel)
                    .textFieldStyle(.plain)
                    .relayDogTextFieldFrame()
                    .onSubmit(addManualModel)

                Button {
                    addManualModel()
                } label: {
                    Label(t("添加", "Add", language: language), systemImage: "plus")
                }
                .relayDogLargeButton()
                .disabled(manualModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let syncError {
                Text(syncError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            Divider()
                .padding(.vertical, 4)

            DraftModelMappingsEditor(
                language: language,
                mappings: $draft.modelMappings
            )
        }
    }

    private func addManualModel() {
        let model = manualModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else {
            return
        }
        setModels(mergeModels(commaSeparatedValues(draft.modelsText), [model]))
        draft.modelSync = .manual
        manualModel = ""
    }

    private func removeModel(_ model: String) {
        setModels(commaSeparatedValues(draft.modelsText).filter { $0 != model })
    }

    private func syncModels() {
        isSyncing = true
        syncError = nil
        draft.modelSync = .remote

        Task { @MainActor in
            do {
                let models = try await fetchModels(upstream(), proto)
                setModels(models)
            } catch {
                syncError = String(describing: error)
            }
            isSyncing = false
        }
    }

    private func setModels(_ models: [String]) {
        draft.modelsText = mergeModels([], models).joined(separator: ", ")
    }
}

private struct DraftModelMappingsEditor: View {
    let language: RelayDogResolvedLanguage
    @Binding var mappings: [String: String]
    @State private var clientModel = ""
    @State private var upstreamModel = ""
    @State private var editingClientModel: String?
    @State private var pendingDeleteClientModel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(t("模型映射", "Model Mappings", language: language))
                    .font(.headline)
                Spacer()
                if editingClientModel != nil {
                    Button(t("取消编辑", "Cancel Edit", language: language)) {
                        resetEditor()
                    }
                    .relayDogSecondaryButton()
                }
            }

            if sortedMappings.isEmpty {
                Text(t("暂无模型映射", "No model mappings", language: language))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(FormFieldBackground())
            } else {
                VStack(spacing: 0) {
                    ForEach(sortedMappings, id: \.client) { mapping in
                        HStack(spacing: 10) {
                            Text(mapping.client)
                                .font(.callout.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Image(systemName: "arrow.right")
                                .foregroundStyle(.secondary)

                            Text(mapping.upstream)
                                .font(.callout.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button {
                                edit(mapping)
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .relayDogIconButton()
                            .help("Edit")

                            Button(role: .destructive) {
                                pendingDeleteClientModel = mapping.client
                            } label: {
                                Image(systemName: "trash")
                            }
                            .relayDogIconButton()
                            .help("Delete")
                        }
                        .padding(.vertical, 9)

                        if mapping.client != sortedMappings.last?.client {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 12)
                .background(FormFieldBackground())
            }

            HStack(spacing: 10) {
                TextField(t("客户端模型", "Client model", language: language), text: $clientModel)
                    .textFieldStyle(.plain)
                    .relayDogTextFieldFrame()

                TextField(t("上游模型", "Upstream model", language: language), text: $upstreamModel)
                    .textFieldStyle(.plain)
                    .relayDogTextFieldFrame()

                Button {
                    saveMapping()
                } label: {
                    Label(editingClientModel == nil ? t("添加", "Add", language: language) : t("保存", "Save", language: language), systemImage: editingClientModel == nil ? "plus" : "checkmark")
                }
                .relayDogLargeButton()
                .disabled(!canSave)
            }
        }
        .confirmationDialog(
            t("删除模型映射？", "Delete model mapping?", language: language),
            isPresented: isConfirmingMappingDelete,
            titleVisibility: .visible
        ) {
            Button(t("删除", "Delete", language: language), role: .destructive) {
                confirmDeleteMapping()
            }
            Button(t("取消", "Cancel", language: language), role: .cancel) {
                pendingDeleteClientModel = nil
            }
        } message: {
            if let pendingDeleteClientModel {
                Text(
                    t(
                        "删除后将移除 \(pendingDeleteClientModel) 的模型映射。",
                        "This removes the mapping for \(pendingDeleteClientModel).",
                        language: language
                    )
                )
            }
        }
    }

    private var sortedMappings: [(client: String, upstream: String)] {
        mappings
            .map { (client: $0.key, upstream: $0.value) }
            .sorted { lhs, rhs in
                lhs.client < rhs.client
            }
    }

    private var canSave: Bool {
        !clientModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !upstreamModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isConfirmingMappingDelete: Binding<Bool> {
        Binding(
            get: { pendingDeleteClientModel != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeleteClientModel = nil
                }
            }
        )
    }

    private func edit(_ mapping: (client: String, upstream: String)) {
        editingClientModel = mapping.client
        clientModel = mapping.client
        upstreamModel = mapping.upstream
    }

    private func saveMapping() {
        let client = clientModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let upstream = upstreamModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !client.isEmpty, !upstream.isEmpty else {
            return
        }

        if let editingClientModel, editingClientModel != client {
            mappings[editingClientModel] = nil
        }
        mappings[client] = upstream
        resetEditor()
    }

    private func confirmDeleteMapping() {
        guard let pendingDeleteClientModel else {
            return
        }

        mappings[pendingDeleteClientModel] = nil
        if editingClientModel == pendingDeleteClientModel {
            resetEditor()
        }
        self.pendingDeleteClientModel = nil
    }

    private func resetEditor() {
        editingClientModel = nil
        clientModel = ""
        upstreamModel = ""
    }
}

private struct UpstreamConfigurationEditor: View {
    let language: RelayDogResolvedLanguage
    @Binding var weight: String
    @Binding var timeoutSeconds: String
    @Binding var healthCheckPath: String
    let proto: ProxyProtocol
    let upstream: () -> UpstreamConfig
    let checkHealth: (UpstreamConfig, ProxyProtocol) async -> UpstreamHealth?
    @State private var isChecking = false
    @State private var checkStatus: String?
    @State private var isReachable = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            FormTextRow(title: t("权重", "Weight", language: language), text: $weight)
            Divider()
            FormTextRow(title: t("超时秒数", "Timeout Seconds", language: language), text: $timeoutSeconds)
            Divider()
            healthCheckRow
        }
    }

    private var healthCheckRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text(t("健康检查", "Health Check", language: language))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .frame(width: formLabelWidth, alignment: .leading)

                TextField("", text: $healthCheckPath)
                    .textFieldStyle(.plain)
                    .relayDogTextFieldFrame()

                Button {
                    runHealthCheck()
                } label: {
                    Label(isChecking ? t("检查中", "Checking", language: language) : t("检查", "Check", language: language), systemImage: "checkmark.circle")
                }
                .relayDogLargeButton()
                .disabled(isChecking)
            }
            .padding(.vertical, 6)

            if let checkStatus {
                Text(checkStatus)
                    .font(.caption)
                    .foregroundStyle(isReachable ? .green : .red)
                    .textSelection(.enabled)
                    .padding(.leading, 144)
            }
        }
    }

    private func runHealthCheck() {
        isChecking = true
        checkStatus = nil

        Task { @MainActor in
            let health = await checkHealth(upstream(), proto)
            if let health {
                isReachable = health.isReachable
                if health.isReachable {
                    let latency = health.latencyMilliseconds.map { "\($0)ms" } ?? "-"
                    checkStatus = t("检查通过", "Check passed", language: language) + " · " + latency
                } else {
                    checkStatus = t("检查失败", "Check failed", language: language) + ": " + (health.lastError ?? "-")
                }
            } else {
                isReachable = false
                checkStatus = t("无法检查：请确认中转站和当前类型已启用", "Unable to check: make sure the upstream and selected type are enabled", language: language)
            }
            isChecking = false
        }
    }
}

private struct UpstreamTestSheet: View {
    let upstream: UpstreamConfig
    let language: RelayDogResolvedLanguage
    let debugUpstream: (UpstreamConfig, ProxyProtocol, String, String) async throws -> UpstreamDebugResult
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProtocol: ProxyProtocol
    @State private var selectedModel: String
    @State private var prompt = "hi"
    @State private var requestText = ""
    @State private var responseText = ""
    @State private var errorText: String?
    @State private var isRunning = false

    init(
        upstream: UpstreamConfig,
        language: RelayDogResolvedLanguage,
        debugUpstream: @escaping (UpstreamConfig, ProxyProtocol, String, String) async throws -> UpstreamDebugResult
    ) {
        self.upstream = upstream
        self.language = language
        self.debugUpstream = debugUpstream
        let initialProtocol = Self.enabledProtocols(for: upstream).first ?? .openAI
        _selectedProtocol = State(initialValue: initialProtocol)
        _selectedModel = State(initialValue: upstream.protocols[initialProtocol]?.models.first ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("测试中转站", "Test Upstream", language: language))
                        .font(.title3.weight(.semibold))
                    Text(upstream.name)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                }
                .relayDogPopupCloseButton()
                .help(t("关闭", "Close", language: language))
                .accessibilityLabel(t("关闭", "Close", language: language))
            }

            VStack(alignment: .leading, spacing: 4) {
                FormPickerRow(title: t("协议", "Protocol", language: language), selection: $selectedProtocol) {
                    ForEach(availableProtocols, id: \.self) { proto in
                        Text(proto.displayName).tag(proto)
                    }
                }
                .disabled(availableProtocols.count <= 1)

                if selectedModels.isEmpty {
                    FormTextRow(title: t("模型", "Model", language: language), text: $selectedModel, prompt: t("填写模型名称", "Enter model name", language: language))
                } else {
                    FormPickerRow(title: t("模型", "Model", language: language), selection: $selectedModel) {
                        ForEach(selectedModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    Text(t("输入", "Input", language: language))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: formLabelWidth, alignment: .leading)
                        .padding(.top, 10)
                    TextEditor(text: $prompt)
                        .font(.body)
                        .frame(
                            minHeight: RelayDogControlMetrics.upstreamTestPromptMinHeight,
                            maxHeight: RelayDogControlMetrics.upstreamTestPromptMaxHeight
                        )
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(FormFieldBackground())
                }
                .padding(.vertical, 6)
            }

            HStack {
                Spacer()
                Button {
                    send()
                } label: {
                    Label(isRunning ? t("发送中", "Sending", language: language) : t("发送测试", "Send Test", language: language), systemImage: "paperplane.fill")
                }
                .relayDogPrimaryButton()
                .keyboardShortcut(.defaultAction)
                .disabled(isRunning || selectedModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            HStack(alignment: .top, spacing: 12) {
                DebugTextBox(title: t("请求", "Request", language: language), text: requestText)
                DebugTextBox(title: t("响应", "Response", language: language), text: responseText)
            }
        }
        .padding(20)
        .frame(width: 780, height: 620)
        .onChange(of: selectedProtocol) { _ in
            reconcileModel()
        }
        .onAppear {
            reconcileModel()
        }
    }

    private var availableProtocols: [ProxyProtocol] {
        let protocols = Self.enabledProtocols(for: upstream)
        return protocols.isEmpty ? [.openAI] : protocols
    }

    private var selectedModels: [String] {
        upstream.protocols[selectedProtocol]?.models ?? []
    }

    private static func enabledProtocols(for upstream: UpstreamConfig) -> [ProxyProtocol] {
        ProxyProtocol.allCases.filter { proto in
            upstream.protocols[proto]?.enabled == true
        }
    }

    private func reconcileModel() {
        let models = selectedModels
        if models.isEmpty {
            return
        }
        if !models.contains(selectedModel) {
            selectedModel = models.first ?? ""
        }
    }

    private func send() {
        let model = selectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else {
            return
        }

        isRunning = true
        errorText = nil
        requestText = ""
        responseText = ""

        Task { @MainActor in
            do {
                let result = try await debugUpstream(upstream, selectedProtocol, model, prompt)
                requestText = result.requestText
                responseText = result.responseText
            } catch {
                errorText = String(describing: error)
            }
            isRunning = false
        }
    }
}

private struct EditorPanel<Content: View>: View {
    let title: String
    let systemImage: String
    let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }
}

private struct FormTextRow: View {
    let title: String
    @Binding var text: String
    var prompt: String = ""
    var labelWidth: CGFloat = formLabelWidth

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: labelWidth, alignment: .leading)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .relayDogTextFieldFrame()
        }
        .padding(.vertical, 6)
    }
}

private struct FormPickerRow<SelectionValue: Hashable, Content: View>: View {
    let title: String
    @Binding var selection: SelectionValue
    var labelWidth: CGFloat = formLabelWidth
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: labelWidth, alignment: .leading)

            Picker("", selection: $selection) {
                content()
            }
            .relayDogMenuField()
        }
        .padding(.vertical, 6)
    }
}

private struct FormFieldBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: formCornerRadius)
            .fill(Color(nsColor: .textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: formCornerRadius)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
            )
    }
}

private struct ModelListView: View {
    let models: [String]
    let language: RelayDogResolvedLanguage
    let remove: (String) -> Void
    @State private var pendingRemoval: String?

    var body: some View {
        Group {
            if models.isEmpty {
                Text(t("暂无模型", "No models", language: language))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 12)
                    .background(FormFieldBackground())
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 172), spacing: 10)], alignment: .leading, spacing: 10) {
                    ForEach(models, id: \.self) { model in
                        HStack(spacing: 6) {
                            Text(model)
                                .font(.callout.monospaced())
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer(minLength: 4)
                            Button {
                                pendingRemoval = model
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption2.weight(.bold))
                            }
                            .relayDogIconButton()
                            .help("Remove")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
                        )
                    }
                }
            }
        }
        .confirmationDialog(
            t("移除模型？", "Remove model?", language: language),
            isPresented: isConfirmingModelRemoval,
            titleVisibility: .visible
        ) {
            Button(t("移除", "Remove", language: language), role: .destructive) {
                confirmModelRemoval()
            }
            Button(t("取消", "Cancel", language: language), role: .cancel) {
                pendingRemoval = nil
            }
        } message: {
            if let pendingRemoval {
                Text(
                    t(
                        "移除后将从当前中转站模型列表删除 \(pendingRemoval)。",
                        "This removes \(pendingRemoval) from the current upstream model list.",
                        language: language
                    )
                )
            }
        }
    }

    private var isConfirmingModelRemoval: Binding<Bool> {
        Binding(
            get: { pendingRemoval != nil },
            set: { isPresented in
                if !isPresented {
                    pendingRemoval = nil
                }
            }
        )
    }

    private func confirmModelRemoval() {
        guard let pendingRemoval else {
            return
        }

        remove(pendingRemoval)
        self.pendingRemoval = nil
    }
}

private struct DebugTextBox: View {
    let title: String
    let text: String
    private let terminalBackground = Color(red: 0.045, green: 0.052, blue: 0.064)
    private let terminalBorder = Color.white.opacity(0.14)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView {
                Text(text.isEmpty ? "-" : text)
                    .font(.caption.monospaced())
                    .foregroundStyle(.white)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(10)
            }
            .scrollContentBackground(.hidden)
            .frame(height: RelayDogControlMetrics.upstreamTestDebugTextHeight)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(terminalBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(terminalBorder, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProtocolRouteRow: View {
    let proto: ProxyProtocol
    let routeTitle: String
    let mode: RoutingMode
    let enabledUpstreamCount: Int
    let language: RelayDogResolvedLanguage

    var body: some View {
        HStack(spacing: 12) {
            ProtocolBadge(title: proto.displayName)
                .frame(width: 86, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(routeTitle)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(mode.displayTitle(language: language))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(enabledUpstreamCount) \(t("个中转站", "upstreams", language: language))")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
    }
}

private struct UpstreamRowView: View {
    let row: RelayDogSettingsUpstreamRow

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            StatusDot(isOn: row.isEnabled)

            VStack(alignment: .leading, spacing: 5) {
                Text(row.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                if !row.note.isEmpty {
                    Text(row.note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                ForEach(row.protocolTitles, id: \.self) { title in
                    ProtocolBadge(title: title)
                }
            }

            Text("w\(row.weight)")
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)

            Text(row.timeoutTitle)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .trailing)
        }
        .padding(.vertical, 10)
    }
}

private struct CopyableValueRow: View {
    let title: String
    let value: String
    let copiedMessage: String
    @State private var isShowingCopied = false
    @State private var feedbackTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 12) {
            ValueRow(title: title, value: value)

            Button {
                copyToPasteboard(value)
                showCopiedFeedback()
            } label: {
                Image(systemName: isShowingCopied ? "checkmark" : "doc.on.doc")
                    .imageScale(.medium)
            }
            .relayDogIconButton()
            .help(isShowingCopied ? copiedMessage : "Copy")
            .popover(isPresented: $isShowingCopied, arrowEdge: .trailing) {
                Text(copiedMessage)
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
        }
        .onDisappear {
            feedbackTask?.cancel()
        }
    }

    private func showCopiedFeedback() {
        feedbackTask?.cancel()
        isShowingCopied = true
        feedbackTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: RelayDogControlMetrics.copyFeedbackDurationNanoseconds)
            guard !Task.isCancelled else {
                return
            }
            isShowingCopied = false
        }
    }
}

private struct ValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: formLabelWidth, alignment: .leading)
            Text(value)
                .font(.callout.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 9)
    }
}

private struct EmptyStateRow: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
            Text(title)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
    }
}

private struct StatusPill: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.callout.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(color.opacity(0.12))
            )
    }
}

private struct StatusDot: View {
    let isOn: Bool

    var body: some View {
        Circle()
            .fill(isOn ? Color.green : Color.secondary.opacity(0.45))
            .frame(width: 9, height: 9)
    }
}

private struct ProtocolBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.accentColor.opacity(0.12))
            )
            .foregroundStyle(Color.accentColor)
    }
}

private struct ValuePill: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.18))
            )
            .foregroundStyle(.secondary)
    }
}

private func copyToPasteboard(_ value: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
}

private func openURL(_ url: URL) {
    NSWorkspace.shared.open(url)
}

private func commaSeparatedValues(_ value: String) -> [String] {
    value
        .split(separator: ",")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
}

private func mergeModels(_ existing: [String], _ incoming: [String]) -> [String] {
    var seen: Set<String> = []
    var result: [String] = []

    for model in existing + incoming {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !seen.contains(trimmed) else {
            continue
        }
        seen.insert(trimmed)
        result.append(trimmed)
    }

    return result
}

private extension RoutingMode {
    func displayTitle(language: RelayDogResolvedLanguage) -> String {
        switch self {
        case .single:
            return t("单一", "Single", language: language)
        case .roundRobin:
            return t("轮询", "Round Robin", language: language)
        case .weightedRoundRobin:
            return t("加权轮询", "Weighted Round Robin", language: language)
        case .failover:
            return t("故障转移", "Failover", language: language)
        case .lowestLatency:
            return t("最低延迟", "Lowest Latency", language: language)
        }
    }
}
