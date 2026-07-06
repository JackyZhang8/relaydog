import AppKit
import SwiftUI

@MainActor
public protocol RelayDogSettingsWindowing: AnyObject {
    var isVisible: Bool { get }
    func center()
    func makeKeyAndOrderFront(_ sender: Any?)
    func orderFrontRegardless()
}

extension NSWindow: RelayDogSettingsWindowing {}

@MainActor
public final class RelayDogSettingsWindowPresenter: ObservableObject {
    private var window: (any RelayDogSettingsWindowing)?
    private let makeWindow: @MainActor (AnyView) -> any RelayDogSettingsWindowing
    private let activateApp: @MainActor () -> Void
    private let scheduleFromMenu: (@escaping @MainActor () -> Void) -> Void

    public init(
        makeWindow: @escaping @MainActor (AnyView) -> any RelayDogSettingsWindowing = { rootView in
            RelayDogSettingsWindowPresenter.makeDefaultWindow(rootView: rootView)
        },
        activateApp: @escaping @MainActor () -> Void = {
            NSApp.activate(ignoringOtherApps: true)
        },
        scheduleFromMenu: @escaping (@escaping @MainActor () -> Void) -> Void = { action in
            Task { @MainActor in
                action()
            }
        }
    ) {
        self.makeWindow = makeWindow
        self.activateApp = activateApp
        self.scheduleFromMenu = scheduleFromMenu
    }

    public func show<Content: View>(@ViewBuilder content: () -> Content) {
        if let window {
            present(window, shouldCenter: false)
            return
        }

        let newWindow = makeWindow(AnyView(content()))
        window = newWindow
        present(newWindow, shouldCenter: true)
    }

    public func showOnLaunch<Content: View>(@ViewBuilder content: () -> Content) {
        show {
            content()
        }
    }

    public func showFromMenu<Content: View>(@ViewBuilder content: @escaping @MainActor () -> Content) {
        scheduleFromMenu { [weak self] in
            self?.show {
                content()
            }
        }
    }

    public static func makeDefaultWindow(rootView: AnyView) -> any RelayDogSettingsWindowing {
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 660),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "RelayDog Settings"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace]
        window.minSize = NSSize(width: 860, height: 620)
        return window
    }

    private func present(_ window: any RelayDogSettingsWindowing, shouldCenter: Bool) {
        if shouldCenter {
            window.center()
        }
        activateApp()
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}
