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
    func testDelegatePresentsQuitFailureWithoutMainWindowAndRetryDismissesIt() async throws {
        XCTAssertFalse(NSApplication.shared.windows.contains(where: \.isVisible))
        let presenter = LifecycleFailurePresenter()
        let lifecycle = ApplicationLifecycleService(failurePresenter: presenter)
        let target = LifecycleFailureDrain()
        target.error = CocoaError(.fileWriteNoPermission)
        let termination = ApplicationTerminationCoordinator(target: target)
        var replies: [Bool] = []
        let delegate = AppDelegate(lifecycle: lifecycle, terminationReply: { _, value in replies.append(value) })
        delegate.lifecycle.configureTermination(termination)
        XCTAssertEqual(delegate.applicationShouldTerminate(NSApplication.shared), .terminateLater)
        XCTAssertEqual(delegate.applicationShouldTerminate(NSApplication.shared), .terminateLater)
        await waitUntil { replies == [false] }
        XCTAssertEqual(target.suspensions, 1)
        XCTAssertTrue(target.accepting)
        XCTAssertEqual(presenter.messages, [CocoaError(.fileWriteNoPermission).localizedDescription])
        XCTAssertEqual(target.fallbackErrors, 0, "O erro nativo não pode abrir também o alert da ContentView")
        target.error = nil
        XCTAssertEqual(delegate.applicationShouldTerminate(NSApplication.shared), .terminateLater)
        await waitUntil { replies == [false, true] }
        XCTAssertEqual(presenter.messages.count, 1)
        XCTAssertEqual(presenter.dismissals, 1)
        XCTAssertFalse(target.accepting)
    }

    func testDelegatePresentsTimeoutWithoutWindowAndLateDrainDoesNotDuplicateReplyOrAlert() async throws {
        XCTAssertFalse(NSApplication.shared.windows.contains(where: \.isVisible))
        let presenter = LifecycleFailurePresenter()
        let lifecycle = ApplicationLifecycleService(failurePresenter: presenter)
        let target = LifecycleFailureDrain()
        target.holdDrain = true
        var replies: [Bool] = []
        let replied = expectation(description: "Timeout da lifecycle sem janela")
        let delegate = AppDelegate(lifecycle: lifecycle, terminationReply: { _, value in
            replies.append(value)
            if replies.count == 1 { replied.fulfill() }
        })
        delegate.lifecycle.configureTermination(ApplicationTerminationCoordinator(target: target))
        XCTAssertEqual(delegate.applicationShouldTerminate(NSApplication.shared), .terminateLater)
        await waitUntil { target.pending != nil }
        var uiUpdated = false
        Task { @MainActor in uiUpdated = true }
        await waitUntil { uiUpdated }
        await fulfillment(of: [replied], timeout: 2.5)
        XCTAssertEqual(replies, [false])
        XCTAssertTrue(target.accepting)
        XCTAssertEqual(presenter.messages, [ApplicationTerminationError.timedOut.localizedDescription])
        XCTAssertEqual(target.fallbackErrors, 0)
        target.pending?.resume(); target.pending = nil
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(replies, [false])
        XCTAssertEqual(presenter.messages.count, 1)
        target.holdDrain = false
        XCTAssertEqual(delegate.applicationShouldTerminate(NSApplication.shared), .terminateLater)
        await waitUntil { replies == [false, true] }
        XCTAssertEqual(presenter.dismissals, 1)
        XCTAssertEqual(presenter.messages.count, 1)
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<500 where !condition() { try? await Task.sleep(for: .milliseconds(1)) }
        XCTAssertTrue(condition(), "A fronteira de término não progrediu")
    }

    func testDelegateUsesItsSharedLifecycleForAsynchronousTermination() async throws {
        let lifecycle = ApplicationLifecycleService()
        let target = LifecycleDrain()
        let termination = ApplicationTerminationCoordinator(target: target)
        var replies: [Bool] = []
        let delegate = AppDelegate(lifecycle: lifecycle, terminationReply: { _, value in replies.append(value) })
        // Mesmo acesso utilizado pelo composition root e pelo MenuBarContentView.
        delegate.lifecycle.configureTermination(termination)
        XCTAssertTrue((delegate.lifecycle as AnyObject) === lifecycle)
        XCTAssertEqual(delegate.applicationShouldTerminate(NSApplication.shared), .terminateLater)
        for _ in 0..<100 where target.pending == nil { await Task.yield() }
        XCTAssertEqual(target.suspensions, 1)
        XCTAssertTrue(replies.isEmpty)
        target.pending?.resume(); target.pending = nil
        for _ in 0..<100 where replies.isEmpty { await Task.yield() }
        XCTAssertEqual(replies, [true])
        XCTAssertFalse(target.accepting)
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
    func configureTermination(_ coordinator: ApplicationTerminationCoordinator) {}
    func requestTermination(reply: @escaping (Bool) -> Void) -> NSApplication.TerminateReply { .terminateNow }
}

@MainActor
private final class LifecycleDrain: ApplicationTerminationPreparing {
    var accepting = true
    var suspensions = 0
    var pending: CheckedContinuation<Void, Never>?
    func suspendForTermination() -> Bool { suspensions += 1; let previous = accepting; accepting = false; return previous }
    func drainForTermination() async throws { await withCheckedContinuation { pending = $0 } }
    func restoreAfterFailedTermination(wasAccepting: Bool) { accepting = wasAccepting }
    func presentTerminationFailure(_ error: Error) {}
}

/// Spy sem janela: comprova roteamento e exclusividade, sem iniciar UI do AppKit.
@MainActor
private final class LifecycleFailurePresenter: ApplicationTerminationFailurePresenting {
    var messages: [String] = []
    var dismissals = 0
    func present(_ error: Error) { messages.append(error.localizedDescription) }
    func dismiss() { dismissals += 1 }
}

@MainActor
private final class LifecycleFailureDrain: ApplicationTerminationPreparing {
    var accepting = true
    var suspensions = 0
    var error: Error?
    var holdDrain = false
    var pending: CheckedContinuation<Void, Never>?
    var fallbackErrors = 0
    func suspendForTermination() -> Bool { suspensions += 1; let prior = accepting; accepting = false; return prior }
    func drainForTermination() async throws {
        if holdDrain { await withCheckedContinuation { pending = $0 } }
        if let error { throw error }
    }
    func restoreAfterFailedTermination(wasAccepting: Bool) { accepting = wasAccepting }
    func presentTerminationFailure(_ error: Error) { fallbackErrors += 1 }
}
