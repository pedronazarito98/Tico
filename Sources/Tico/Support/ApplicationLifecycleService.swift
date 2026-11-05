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
    func configureTermination(_ coordinator: ApplicationTerminationCoordinator)
    func requestTermination(reply: @escaping (Bool) -> Void) -> NSApplication.TerminateReply
}

/// Mantém AppKit na main e delega a drenagem assíncrona ao owner da aplicação.
@MainActor
final class ApplicationLifecycleService: ApplicationLifecycleControlling {
    private let application: NSApplication
    private var termination: ApplicationTerminationCoordinator?
    private let failurePresenter: any ApplicationTerminationFailurePresenting

    init(application: NSApplication? = nil,
         failurePresenter: (any ApplicationTerminationFailurePresenting)? = nil) {
        let application = application ?? .shared
        self.application = application
        self.failurePresenter = failurePresenter ?? ApplicationTerminationFailurePresenter(application: application)
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

    func configureTermination(_ coordinator: ApplicationTerminationCoordinator) { termination = coordinator }

    func requestTermination(reply: @escaping (Bool) -> Void) -> NSApplication.TerminateReply {
        guard let termination else { return .terminateNow }
        // Uma única superfície apresenta esta falha, mesmo sem ContentView.
        // O fallback do target é reservado aos consumidores sem lifecycle.
        termination.request(onFailure: { [weak self] error in
            self?.failurePresenter.present(error)
        }, reply: { [weak self] allowed in
            if allowed { self?.failurePresenter.dismiss() }
            reply(allowed)
        })
        return .terminateLater
    }

    func terminate() {
        application.terminate(nil)
    }
}
