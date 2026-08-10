import AppKit

@MainActor
protocol ApplicationLifecycleControlling {
    func configureOnLaunch()
    func handleReopen(
        hasVisibleWindows: Bool,
        openMainWindow: @escaping () -> Void
    ) -> Bool
    func activateAndOpenMainWindow(_ openWindow: @escaping () -> Void)
    func terminate()
}

/// Keeps direct `NSApplication` and `NSWindow` operations behind one narrow port.
@MainActor
final class ApplicationLifecycleService: ApplicationLifecycleControlling {
    private let application: NSApplication

    init(application: NSApplication? = nil) {
        self.application = application ?? .shared
    }

    func configureOnLaunch() {
        application.setActivationPolicy(.regular)
        application.activate(ignoringOtherApps: true)
    }

    func handleReopen(
        hasVisibleWindows: Bool,
        openMainWindow: @escaping () -> Void
    ) -> Bool {
        if !hasVisibleWindows {
            if let window = application.windows.first(where: { $0.canBecomeMain }) {
                window.makeKeyAndOrderFront(nil)
            } else {
                openMainWindow()
            }
            application.activate(ignoringOtherApps: true)
        }
        return true
    }

    func activateAndOpenMainWindow(_ openWindow: @escaping () -> Void) {
        application.activate(ignoringOtherApps: true)
        openWindow()
    }

    func terminate() {
        application.terminate(nil)
    }
}
