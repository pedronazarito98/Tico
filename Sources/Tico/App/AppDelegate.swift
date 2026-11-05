import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let lifecycle: any ApplicationLifecycleControlling
    private let terminationReply: @MainActor (NSApplication, Bool) -> Void

    override init() {
        self.lifecycle = ApplicationLifecycleService()
        self.terminationReply = { $0.reply(toApplicationShouldTerminate: $1) }
        super.init()
    }

    init(lifecycle: any ApplicationLifecycleControlling,
         terminationReply: @escaping @MainActor (NSApplication, Bool) -> Void = { $0.reply(toApplicationShouldTerminate: $1) }) {
        self.lifecycle = lifecycle
        self.terminationReply = terminationReply
        super.init()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        lifecycle.requestTermination { [terminationReply] in terminationReply(sender, $0) }
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
