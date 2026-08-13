import AppKit
import Foundation
import XCTest
@testable import Tico

@MainActor
final class ApplicationLifecycleServiceTests: XCTestCase {
    func testAppDelegateDelegatesLifecycleCallbacksToInjectedService() {
        let lifecycle = LifecycleSpy()
        let delegate = AppDelegate(lifecycle: lifecycle)

        delegate.applicationDidFinishLaunching(
            Notification(name: NSApplication.didFinishLaunchingNotification)
        )
        XCTAssertEqual(lifecycle.configureCount, 1)

        XCTAssertTrue(
            delegate.applicationShouldHandleReopen(
                NSApplication.shared,
                hasVisibleWindows: false
            )
        )
        XCTAssertEqual(lifecycle.reopenFlags, [false])
    }
}

@MainActor
private final class LifecycleSpy: ApplicationLifecycleControlling {
    var configureCount = 0
    var reopenFlags: [Bool] = []

    func configureOnLaunch() {
        configureCount += 1
    }

    func handleReopen(
        hasVisibleWindows: Bool,
        openMainWindow: @escaping () -> Void
    ) -> Bool {
        reopenFlags.append(hasVisibleWindows)
        return true
    }

    func activateAndOpenMainWindow(_ openWindow: @escaping () -> Void) {
        openWindow()
    }

    func terminate() {}
}
