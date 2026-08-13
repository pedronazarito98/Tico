import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let lifecycle: any ApplicationLifecycleControlling

    override init() {
        self.lifecycle = ApplicationLifecycleService()
        super.init()
    }

    init(lifecycle: any ApplicationLifecycleControlling) {
        self.lifecycle = lifecycle
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
            NotificationCenter.default.post(name: .ticoOpenMainWindow, object: nil)
        }
    }
}
