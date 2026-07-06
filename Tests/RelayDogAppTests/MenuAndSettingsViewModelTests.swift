import XCTest
import AppKit
import RelayDogCore
@testable import RelayDogApp

final class MenuAndSettingsViewModelTests: XCTestCase {
    func testBrandResourceBundlePrefersStandardAppResourcesDirectory() throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent("relaydog-resource-bundle-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: root) }

        let appBundleURL = root.appendingPathComponent("RelayDog.app", isDirectory: true)
        let resourcesURL = appBundleURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        let standardBundleURL = resourcesURL.appendingPathComponent("RelayDog_RelayDogApp.bundle", isDirectory: true)
        let legacyBundleURL = appBundleURL.appendingPathComponent("RelayDog_RelayDogApp.bundle", isDirectory: true)

        try fileManager.createDirectory(at: standardBundleURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: legacyBundleURL, withIntermediateDirectories: true)

        XCTAssertEqual(
            RelayDogBrandAssets.resourceBundleURL(
                mainBundleURL: appBundleURL,
                mainResourceURL: resourcesURL
            )?.standardizedFileURL,
            standardBundleURL.standardizedFileURL
        )
    }

    func testBrandLogoAssetIsBundledWithGeneratedAppIconArtwork() throws {
        let image = try XCTUnwrap(RelayDogBrandAssets.logoImage)
        XCTAssertEqual(image.size.width, 1024)
        XCTAssertEqual(image.size.height, 1024)

        let topLeftAlpha = try XCTUnwrap(RelayDogBrandAssets.cornerAlpha())
        XCTAssertGreaterThanOrEqual(topLeftAlpha, 250)
    }

    func testBundledBrandLogoUsesGeneratedOutputArtwork() throws {
        let packageRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let outputArtwork = packageRoot.appendingPathComponent("output/app_1024x1024.png")
        let bundledArtwork = packageRoot.appendingPathComponent("Sources/RelayDogApp/Resources/relaydog-logo.png")

        XCTAssertEqual(try Data(contentsOf: bundledArtwork), try Data(contentsOf: outputArtwork))
    }

    func testApplicationIconInstallerUsesBrandLogoArtwork() throws {
        var installedImage: NSImage?

        RelayDogApplicationIcon.install { image in
            installedImage = image
        }

        let image = try XCTUnwrap(installedImage)
        XCTAssertEqual(image.size.width, RelayDogBrandAssets.logoImage?.size.width)
        XCTAssertEqual(image.size.height, RelayDogBrandAssets.logoImage?.size.height)
    }

    func testMenuBarIconUsesBundledBrandLogoInsteadOfLegacySymbol() throws {
        let image = try XCTUnwrap(RelayDogMenuBarPresentation.iconImage)
        let logoImage = try XCTUnwrap(RelayDogBrandAssets.logoImage)

        XCTAssertEqual(RelayDogMenuBarPresentation.title, "RelayDog")
        XCTAssertEqual(RelayDogMenuBarPresentation.statusItemTitle, "")
        XCTAssertFalse(RelayDogMenuBarPresentation.statusItemShowsTitle)
        XCTAssertEqual(RelayDogMenuBarPresentation.statusItemIconSize.width, 18)
        XCTAssertEqual(RelayDogMenuBarPresentation.statusItemIconSize.height, 18)
        XCTAssertEqual(RelayDogMenuBarPresentation.statusItemIconSourceInset, 96)
        XCTAssertTrue(RelayDogMenuBarPresentation.statusItemIconRemovesLightEdge)
        XCTAssertEqual(RelayDogMenuBarPresentation.fallbackSystemImage, "pawprint.fill")
        XCTAssertLessThan(image.size.width, logoImage.size.width)
        XCTAssertLessThan(image.size.height, logoImage.size.height)
        XCTAssertEqual(menuBarLightEdgePixelCount(for: image), 0)
        XCTAssertTrue(menuBarCornerAlphas(for: image).allSatisfy { $0 <= 24 })
    }

    func testTopLevelMenuContainsOnlyCommonActionsWithoutProxyPause() {
        let viewModel = RelayDogMenuViewModel(config: menuConfig())

        XCTAssertEqual(viewModel.topLevelItems.map(\.title), [
            "RelayDog Running",
            "Local Listener: 127.0.0.1:18787",
            "Open Settings",
            "Copy OpenAI Base URL",
            "Copy Claude Base URL",
            "OpenAI Route: Auto",
            "Claude Route: Dual Gateway",
            "Request Logs: Off",
            "Reveal Log Folder",
            "Quit RelayDog"
        ])
        XCTAssertFalse(viewModel.topLevelItems.contains { $0.title.contains("Pause") || $0.title.contains("Proxy") })
    }

    func testTopLevelMenuLocalizesCommonTitlesToChinese() {
        var config = menuConfig()
        config.language = .zh
        let viewModel = RelayDogMenuViewModel(config: config)

        XCTAssertEqual(viewModel.topLevelItems.map(\.title), [
            "RelayDog 正在运行",
            "本机监听: 127.0.0.1:18787",
            "打开设置",
            "复制 OpenAI 地址",
            "复制 Claude 地址",
            "OpenAI 路由: 自动",
            "Claude 路由: Dual Gateway",
            "请求日志: 关闭",
            "显示日志文件夹",
            "退出 RelayDog"
        ])
    }

    func testMenuClientEndpointItemsExposeCopyTitlesAndValues() {
        let viewModel = RelayDogMenuViewModel(config: menuConfig())

        XCTAssertEqual(viewModel.clientEndpointItems, [
            .init(title: "Copy OpenAI Base URL", value: "http://127.0.0.1:18787/v1", kind: .copyOpenAIEndpoint),
            .init(title: "Copy Claude Base URL", value: "http://127.0.0.1:18787", kind: .copyClaudeEndpoint)
        ])
    }

    func testRouteMenusOnlyShowUpstreamsEnabledForThatProtocol() {
        let viewModel = RelayDogMenuViewModel(config: menuConfig())

        XCTAssertEqual(viewModel.routeItems(for: .openAI).map(\.title), [
            "Auto",
            "GLM Gateway",
            "Dual Gateway"
        ])
        XCTAssertEqual(viewModel.routeItems(for: .claude).map(\.title), [
            "Auto",
            "Dual Gateway"
        ])
        XCTAssertFalse(viewModel.routeItems(for: .openAI).contains { $0.kind == .manageRoutes })
        XCTAssertFalse(viewModel.routeItems(for: .claude).contains { $0.kind == .manageRoutes })
    }

    func testRequestLogMenuShowsViewerToggleAndRevealFolder() {
        let offViewModel = RelayDogMenuViewModel(config: menuConfig())
        var onConfig = menuConfig()
        onConfig.requestLogging.enabled = true
        let onViewModel = RelayDogMenuViewModel(config: onConfig)

        XCTAssertEqual(offViewModel.requestLogItems.map(\.title), [
            "Turn Request Logging On"
        ])
        XCTAssertEqual(onViewModel.requestLogItems.map(\.title), [
            "Turn Request Logging Off"
        ])
        XCTAssertFalse(offViewModel.requestLogItems.contains { $0.kind == .openViewer })
        XCTAssertFalse(onViewModel.requestLogItems.contains { $0.kind == .openViewer })
        XCTAssertFalse(offViewModel.requestLogItems.contains { $0.kind == .revealLogFolder })
        XCTAssertFalse(onViewModel.requestLogItems.contains { $0.kind == .revealLogFolder })
    }

    func testSettingsSectionsMatchProductSkeleton() {
        XCTAssertEqual(SettingsSection.allCases.map(\.title), [
            "Overview",
            "Upstreams",
            "Routing",
            "Request Logs",
            "Health & Statistics",
            "General",
            "Advanced",
            "About"
        ])
    }

    func testSettingsTabsGroupFunctionalAreas() {
        XCTAssertEqual(RelayDogSettingsTab.allCases.map(\.title), [
            "Overview",
            "Connections",
            "Logs",
            "System",
            "About"
        ])
        XCTAssertEqual(RelayDogSettingsTab.overview.sections, [.overview, .routing])
        XCTAssertEqual(RelayDogSettingsTab.connections.sections, [.upstreams])
        XCTAssertEqual(RelayDogSettingsTab.logs.sections, [.requestLogs])
        XCTAssertEqual(RelayDogSettingsTab.system.sections, [.general, .advanced])
        XCTAssertEqual(RelayDogSettingsTab.about.sections, [.about])
    }

    func testSettingsTabsLocalizeToChinese() {
        let language = RelayDogResolvedLanguage.zh

        XCTAssertEqual(RelayDogSettingsTab.allCases.map { $0.localizedTitle(language: language) }, [
            "概览",
            "连接",
            "日志",
            "系统",
            "关于"
        ])
    }

    func testSettingsAboutDetailsDescribeProject() {
        let paths = AppPaths(homeDirectory: URL(fileURLWithPath: "/tmp/relaydog-home", isDirectory: true))
        let viewModel = RelayDogSettingsViewModel(config: menuConfig(), paths: paths)

        XCTAssertEqual(viewModel.aboutDetails.title, "RelayDog")
        XCTAssertTrue(viewModel.aboutDetails.description.contains("local AI model relay"))
        XCTAssertEqual(viewModel.aboutDetails.featureTitles, [
            "Single local endpoint",
            "OpenAI and Claude routing",
            "Per-upstream models and mappings",
            "Request logs and debug tests"
        ])
        XCTAssertTrue(viewModel.aboutDetails.storageNote.contains("plaintext"))
    }

    func testSettingsLocalDataItemsExposeFilesWithoutLocalEndpoint() {
        let paths = AppPaths(homeDirectory: URL(fileURLWithPath: "/tmp/relaydog-home", isDirectory: true))
        let viewModel = RelayDogSettingsViewModel(config: menuConfig(), paths: paths)

        XCTAssertEqual(viewModel.localDataItems, [
            .init(title: "Config File", value: "/tmp/relaydog-home/.relaydog/config.json"),
            .init(title: "Logs Folder", value: "/tmp/relaydog-home/.relaydog/logs")
        ])
        XCTAssertFalse(viewModel.localDataItems.contains { $0.title == "Local Endpoint" })
    }

    func testSettingsHeaderUsesTaglineInsteadOfLocalEndpointAndLogToggle() {
        var config = menuConfig()
        config.language = .zh
        let viewModel = RelayDogSettingsViewModel(config: config, preferredLanguages: ["zh-Hans-CN"])

        XCTAssertEqual(viewModel.headerTagline, "本机 AI 模型中转站，一个客户端地址连接多路模型。")
        XCTAssertTrue(RelayDogControlMetrics.headerShowsTagline)
        XCTAssertFalse(RelayDogControlMetrics.headerShowsLocalEndpoint)
        XCTAssertFalse(RelayDogControlMetrics.headerShowsRequestLogToggle)
        XCTAssertTrue(RelayDogControlMetrics.overviewShowsRoutingBelowClientURLs)
        XCTAssertFalse(RelayDogControlMetrics.overviewShowsProtocolSummaryTiles)
        XCTAssertFalse(RelayDogControlMetrics.overviewShowsLocalDataPanel)
        XCTAssertFalse(RelayDogControlMetrics.connectionsShowsRoutingPanel)
        XCTAssertFalse(RelayDogControlMetrics.logsShowsHealthAndStatisticsPanel)
        XCTAssertTrue(RelayDogControlMetrics.upstreamPanelUsesInlineAddButton)
        XCTAssertFalse(RelayDogControlMetrics.upstreamRowShowsSubtitle)
    }

    func testSettingsControlMetricsUseRoomierButtonsAndPlainPickerChrome() {
        XCTAssertGreaterThanOrEqual(RelayDogControlMetrics.topTabHorizontalPadding, 18)
        XCTAssertGreaterThanOrEqual(RelayDogControlMetrics.topTabVerticalPadding, 10)
        XCTAssertGreaterThanOrEqual(RelayDogControlMetrics.topTabMinHeight, 42)
        XCTAssertGreaterThanOrEqual(RelayDogControlMetrics.actionButtonHorizontalPadding, 16)
        XCTAssertGreaterThanOrEqual(RelayDogControlMetrics.actionButtonVerticalPadding, 8)
        XCTAssertGreaterThanOrEqual(RelayDogControlMetrics.actionButtonMinHeight, 38)
        XCTAssertEqual(RelayDogControlMetrics.iconButtonMinSize, 34)
        XCTAssertGreaterThanOrEqual(RelayDogControlMetrics.iconButtonVerticalPadding, 4)
        XCTAssertTrue(RelayDogControlMetrics.iconButtonsUseSquareFrame)
        XCTAssertTrue(RelayDogControlMetrics.copyButtonsShowCopiedFeedback)
        XCTAssertEqual(RelayDogControlMetrics.copyFeedbackMessage(language: .zh), "已复制")
        XCTAssertEqual(RelayDogControlMetrics.copyFeedbackMessage(language: .en), "Copied")
        XCTAssertEqual(RelayDogControlMetrics.headerLogoSize, 42)
        XCTAssertGreaterThan(RelayDogControlMetrics.headerTopPadding, RelayDogControlMetrics.headerBottomPadding)
        XCTAssertGreaterThanOrEqual(RelayDogControlMetrics.headerTopPadding - RelayDogControlMetrics.headerBottomPadding, 8)
        XCTAssertTrue(RelayDogControlMetrics.clickableButtonsUsePointingHandCursor)
        XCTAssertFalse(RelayDogControlMetrics.menuFieldUsesOuterBackground)
        XCTAssertTrue(RelayDogControlMetrics.menuFieldUsesBorderlessButtonStyle)
        XCTAssertFalse(RelayDogControlMetrics.openURLIconUsesBorder)
        XCTAssertGreaterThanOrEqual(RelayDogControlMetrics.openURLIconSize, 18)
        XCTAssertLessThanOrEqual(RelayDogControlMetrics.upstreamTestPromptMaxHeight, 56)
        XCTAssertLessThanOrEqual(RelayDogControlMetrics.upstreamTestDebugTextHeight, 80)
        XCTAssertTrue(RelayDogControlMetrics.upstreamTestCloseUsesIconOnly)
        XCTAssertFalse(RelayDogControlMetrics.popupCloseButtonsUseBorder)
        XCTAssertTrue(RelayDogControlMetrics.upstreamTestDebugUsesTerminalChrome)
        XCTAssertTrue(RelayDogControlMetrics.upstreamListUsesInlineEnabledToggle)
        XCTAssertFalse(RelayDogControlMetrics.upstreamEditorShowsUpstreamEnabledToggle)
        XCTAssertTrue(RelayDogControlMetrics.upstreamEditorCloseUsesIconOnly)
        XCTAssertTrue(RelayDogControlMetrics.deleteActionsRequireConfirmation)
    }

    func testLanguagePreferenceResolvesSystemFromPreferredLanguages() {
        XCTAssertEqual(RelayDogLanguage.system.resolved(preferredLanguages: ["zh-Hans-CN"]), .zh)
        XCTAssertEqual(RelayDogLanguage.system.resolved(preferredLanguages: ["en-US"]), .en)
        XCTAssertEqual(RelayDogLanguage.zh.resolved(preferredLanguages: ["en-US"]), .zh)
        XCTAssertEqual(RelayDogLanguage.en.resolved(preferredLanguages: ["zh-Hans-CN"]), .en)
    }

    func testSimpleTranslationHelperUsesResolvedLanguage() {
        XCTAssertEqual(t("中文", "English", language: .zh), "中文")
        XCTAssertEqual(t("中文", "English", language: .en), "English")
    }

    func testSettingsLanguageOptionsExposeSystemChineseAndEnglish() {
        var config = menuConfig()
        config.language = .system
        let viewModel = RelayDogSettingsViewModel(config: config, preferredLanguages: ["zh-Hans-CN"])

        XCTAssertEqual(viewModel.effectiveLanguage, .zh)
        XCTAssertEqual(viewModel.languageOptions.map(\.title), [
            "跟随系统 / Follow System",
            "中文",
            "English"
        ])
        XCTAssertEqual(viewModel.languageOptions.first?.preference, .system)
        XCTAssertEqual(viewModel.languageOptions.first?.isSelected, true)
    }

    func testSettingsEndpointItemsExposeSinglePortClientUrls() {
        let viewModel = RelayDogSettingsViewModel(config: menuConfig())

        XCTAssertEqual(viewModel.endpointItems, [
            .init(title: "OpenAI Base URL", value: "http://127.0.0.1:18787/v1"),
            .init(title: "Claude Base URL", value: "http://127.0.0.1:18787")
        ])
        XCTAssertFalse(viewModel.endpointItems.contains { $0.title == "Local Endpoint" })
    }

    func testSettingsProtocolSummariesSurfaceRoutesAndCounts() throws {
        let viewModel = RelayDogSettingsViewModel(config: menuConfig())

        let openAI = try XCTUnwrap(viewModel.protocolSummaries.first { $0.proto == .openAI })
        XCTAssertEqual(openAI.routeTitle, "Auto")
        XCTAssertEqual(openAI.enabledUpstreamCount, 2)
        XCTAssertEqual(openAI.modelCount, 1)
        XCTAssertEqual(openAI.modelMappingCount, 0)

        let claude = try XCTUnwrap(viewModel.protocolSummaries.first { $0.proto == .claude })
        XCTAssertEqual(claude.routeTitle, "Dual Gateway")
        XCTAssertEqual(claude.enabledUpstreamCount, 1)
    }

    func testProtocolDisplayNamesUseCompatibleLabels() {
        XCTAssertEqual(ProxyProtocol.openAI.displayName, "OpenAI兼容")
        XCTAssertEqual(ProxyProtocol.claude.displayName, "Claude兼容")
    }

    func testSettingsModelMappingRowsExposeOnlyUpstreamMappings() {
        var config = menuConfig()
        config.globalModelMappings[.openAI] = ["gpt-5.5": "glm5.2"]
        config.upstreams[0].protocols[.openAI]?.modelMappings = ["codex-pro": "glm5.2"]

        let rows = RelayDogSettingsViewModel(config: config).modelMappingRows

        XCTAssertFalse(rows.contains(.init(scope: "Global", proto: .openAI, clientModel: "gpt-5.5", upstreamModel: "glm5.2")))
        XCTAssertTrue(rows.contains(.init(scope: "GLM Gateway", proto: .openAI, clientModel: "codex-pro", upstreamModel: "glm5.2")))
    }

    func testStatusIsOfflineWhenListenerIsNotRunning() {
        let viewModel = RelayDogMenuViewModel(
            config: menuConfig(),
            runtimeState: .stopped
        )

        XCTAssertEqual(viewModel.status, .offline)
    }

    private func menuConfig() -> RelayDogConfig {
        RelayDogConfig(
            listener: .init(host: "127.0.0.1", port: 18787, enabled: true),
            upstreams: [
                .init(
                    id: "glm",
                    name: "GLM Gateway",
                    enabled: true,
                    weight: 100,
                    timeoutSeconds: 60,
                    note: "",
                    protocols: [
                        .openAI: .init(enabled: true, baseURL: "https://example.com/openai/v1", apiKey: "sk", headerOverrides: [:], healthCheckPath: "/v1/models", modelSync: .manual, models: ["glm5.2"], modelMappings: [:])
                    ]
                ),
                .init(
                    id: "dual",
                    name: "Dual Gateway",
                    enabled: true,
                    weight: 100,
                    timeoutSeconds: 60,
                    note: "",
                    protocols: [
                        .openAI: .init(enabled: true, baseURL: "https://example.com/dual/v1", apiKey: "openai", headerOverrides: [:], healthCheckPath: "/v1/models", modelSync: .manual, models: [], modelMappings: [:]),
                        .claude: .init(enabled: true, baseURL: "https://example.com/anthropic", apiKey: "claude", headerOverrides: [:], healthCheckPath: "/v1/messages", modelSync: .manual, models: [], modelMappings: [:])
                    ]
                ),
                .init(
                    id: "disabled",
                    name: "Disabled Gateway",
                    enabled: false,
                    weight: 100,
                    timeoutSeconds: 60,
                    note: "",
                    protocols: [
                        .openAI: .init(enabled: true, baseURL: "https://example.com/disabled/v1", apiKey: "disabled", headerOverrides: [:], healthCheckPath: "/v1/models", modelSync: .manual, models: [], modelMappings: [:])
                    ]
                )
            ],
            routing: [
                .openAI: .init(mode: .roundRobin, selectedUpstreamID: nil),
                .claude: .init(mode: .single, selectedUpstreamID: "dual")
            ],
            globalModelMappings: [:],
            requestLogging: .init(enabled: false, maxFileBytes: 50 * 1024 * 1024, retentionDays: 7, recordResponseBody: true),
            language: .en
        )
    }

    private func menuBarLightEdgePixelCount(for image: NSImage) -> Int {
        let pixels = menuBarRenderedPixels(for: image)
        guard !pixels.isEmpty else {
            return Int.max
        }
        let width = Int(RelayDogMenuBarPresentation.statusItemIconSize.width)
        let height = Int(RelayDogMenuBarPresentation.statusItemIconSize.height)

        var count = 0
        for y in 0..<height {
            for x in 0..<width where x == 0 || y == 0 || x == width - 1 || y == height - 1 {
                let index = (y * width + x) * 4
                let red = pixels[index]
                let green = pixels[index + 1]
                let blue = pixels[index + 2]
                let alpha = pixels[index + 3]
                if red > 235, green > 225, blue > 220, alpha > 200 {
                    count += 1
                }
            }
        }
        return count
    }

    private func menuBarCornerAlphas(for image: NSImage) -> [UInt8] {
        let pixels = menuBarRenderedPixels(for: image)
        guard !pixels.isEmpty else {
            return [255]
        }
        let width = Int(RelayDogMenuBarPresentation.statusItemIconSize.width)
        let height = Int(RelayDogMenuBarPresentation.statusItemIconSize.height)
        let cornerIndexes = [
            0,
            width - 1,
            (height - 1) * width,
            height * width - 1
        ]
        return cornerIndexes.map { pixels[$0 * 4 + 3] }
    }

    private func menuBarRenderedPixels(for image: NSImage) -> [UInt8] {
        let width = Int(RelayDogMenuBarPresentation.statusItemIconSize.width)
        let height = Int(RelayDogMenuBarPresentation.statusItemIconSize.height)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return []
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }
}
