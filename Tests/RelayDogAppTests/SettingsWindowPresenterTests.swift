import SwiftUI
import XCTest
@testable import RelayDogApp

@MainActor
final class SettingsWindowPresenterTests: XCTestCase {
    func testShowCreatesCentersOrdersAndActivatesSettingsWindow() {
        var events: [String] = []
        let fakeWindow = FakeSettingsWindow()
        var createdWindowCount = 0
        var activationCount = 0
        var scheduledCenter: (@MainActor () -> Void)?
        let presenter = RelayDogSettingsWindowPresenter(
            makeWindow: { _ in
                createdWindowCount += 1
                fakeWindow.events = { events.append($0) }
                return fakeWindow
            },
            activateApp: {
                activationCount += 1
                events.append("activate")
            },
            scheduleAfterPresentation: { action in
                scheduledCenter = action
            }
        )

        presenter.show {
            Text("Settings")
        }

        XCTAssertEqual(createdWindowCount, 1)
        XCTAssertEqual(fakeWindow.centerCount, 1)
        XCTAssertEqual(fakeWindow.orderFrontCount, 1)
        XCTAssertEqual(fakeWindow.orderFrontRegardlessCount, 1)
        XCTAssertEqual(activationCount, 1)
        XCTAssertNotNil(scheduledCenter)
        XCTAssertEqual(events, ["activate", "makeKeyAndOrderFront", "orderFrontRegardless", "centerOnScreen"])

        scheduledCenter?()

        XCTAssertEqual(fakeWindow.centerCount, 2)
        XCTAssertEqual(events, ["activate", "makeKeyAndOrderFront", "orderFrontRegardless", "centerOnScreen", "centerOnScreen"])
    }

    func testShowReusesExistingSettingsWindow() {
        var events: [String] = []
        let fakeWindow = FakeSettingsWindow()
        fakeWindow.events = { events.append($0) }
        var createdWindowCount = 0
        var scheduledCenters: [@MainActor () -> Void] = []
        let presenter = RelayDogSettingsWindowPresenter(
            makeWindow: { _ in
                createdWindowCount += 1
                return fakeWindow
            },
            activateApp: {
                events.append("activate")
            },
            scheduleAfterPresentation: { action in
                scheduledCenters.append(action)
            }
        )

        presenter.show {
            Text("Settings")
        }
        events.removeAll()
        presenter.show {
            Text("Settings")
        }

        XCTAssertEqual(createdWindowCount, 1)
        XCTAssertEqual(fakeWindow.centerCount, 2)
        XCTAssertEqual(fakeWindow.orderFrontCount, 2)
        XCTAssertEqual(fakeWindow.orderFrontRegardlessCount, 2)
        XCTAssertEqual(scheduledCenters.count, 2)
        XCTAssertEqual(events, ["activate", "makeKeyAndOrderFront", "orderFrontRegardless", "centerOnScreen"])
    }

    func testShowFromMenuDefersPresentationUntilScheduledActionRuns() {
        let fakeWindow = FakeSettingsWindow()
        var createdWindowCount = 0
        var scheduledAction: (@MainActor () -> Void)?
        let presenter = RelayDogSettingsWindowPresenter(
            makeWindow: { _ in
                createdWindowCount += 1
                return fakeWindow
            },
            activateApp: {},
            scheduleFromMenu: { action in
                scheduledAction = action
            }
        )

        presenter.showFromMenu {
            Text("Settings")
        }

        XCTAssertEqual(createdWindowCount, 0)
        XCTAssertNotNil(scheduledAction)

        scheduledAction?()

        XCTAssertEqual(createdWindowCount, 1)
        XCTAssertEqual(fakeWindow.orderFrontRegardlessCount, 1)
    }

    func testShowOnLaunchPresentsSettingsImmediately() {
        let fakeWindow = FakeSettingsWindow()
        var createdWindowCount = 0
        var scheduledAction: (@MainActor () -> Void)?
        let presenter = RelayDogSettingsWindowPresenter(
            makeWindow: { _ in
                createdWindowCount += 1
                return fakeWindow
            },
            activateApp: {},
            scheduleFromMenu: { action in
                scheduledAction = action
            }
        )

        presenter.showOnLaunch {
            Text("Settings")
        }

        XCTAssertEqual(createdWindowCount, 1)
        XCTAssertNil(scheduledAction)
        XCTAssertEqual(fakeWindow.centerCount, 1)
        XCTAssertEqual(fakeWindow.orderFrontCount, 1)
        XCTAssertEqual(fakeWindow.orderFrontRegardlessCount, 1)
    }
}

private final class FakeSettingsWindow: RelayDogSettingsWindowing {
    var isVisible = false
    var events: ((String) -> Void)?
    private(set) var centerCount = 0
    private(set) var orderFrontCount = 0
    private(set) var orderFrontRegardlessCount = 0

    func centerOnScreen() {
        events?("centerOnScreen")
        centerCount += 1
    }

    func makeKeyAndOrderFront(_ sender: Any?) {
        isVisible = true
        events?("makeKeyAndOrderFront")
        orderFrontCount += 1
    }

    func orderFrontRegardless() {
        events?("orderFrontRegardless")
        orderFrontRegardlessCount += 1
    }
}
