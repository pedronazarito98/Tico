import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let lifecycle: any ApplicationLifecycleControlling

    init(lifecycle: (any ApplicationLifecycleControlling)? = nil) {
        self.lifecycle = lifecycle ?? ApplicationLifecycleService()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        lifecycle.configureOnLaunch()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        lifecycle.handleReopen(hasVisibleWindows: flag) {
            NotificationCenter.default.post(name: .airShortcutOpenMainWindow, object: nil)
        }
    }
}
