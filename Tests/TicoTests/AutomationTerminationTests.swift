import AppKit
import Foundation
import XCTest
@testable import Tico

@MainActor
final class AutomationTerminationTests: XCTestCase {
    func testCompletedEffectAndNextActivationDoNotWaitForHistoryWriter() async throws {
        let fixture = try TerminationFixture()
        defer { fixture.remove() }
        let first = try XCTUnwrap(fixture.automation.runManually(fixture.rule))
        await waitUntil { fixture.history.pendingCount == 1 }
        XCTAssertTrue(fixture.automation.runningRuleIDs.isEmpty)
        XCTAssertEqual(fixture.reports.count, 1, "Efeito concluído deve publicar feedback sem esperar disco")
        let second = try XCTUnwrap(fixture.automation.runManually(fixture.rule))
        await waitUntil { fixture.notifications.count == 2 }
        XCTAssertEqual(fixture.reports.count, 2)
        XCTAssertTrue(fixture.log.entries.isEmpty, "ACK retido não é durabilidade")
        fixture.history.release()
        _ = await first.value; _ = await second.value
        try await fixture.automation.flushFeedback()
        XCTAssertTrue(fixture.reports.allSatisfy { !$0.wasCancelled && $0.success })
    }

    func testReplacementStillWaitsForPreviousEffectCleanup() async throws {
        let notification = TerminationNotifications(holdFirst: true)
        let fixture = try TerminationFixture(notifications: notification)
        defer { fixture.remove() }
        let first = try XCTUnwrap(fixture.automation.runManually(fixture.rule))
        await waitUntil { notification.count == 1 }
        let second = try XCTUnwrap(fixture.automation.runManually(fixture.rule))
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(notification.count, 1, "Cancel não confirma cleanup")
        XCTAssertTrue(fixture.reports.isEmpty)
        notification.release()
        await waitUntil { notification.count == 2 }
        fixture.history.release()
        _ = await first.value; _ = await second.value
        try await fixture.automation.flushFeedback()
        XCTAssertEqual(notification.count, 2)
    }

    func testQuitWaitsForCleanupThenFinalFeedbackThenFlushAndSuspendsAllIngress() async throws {
        let notification = TerminationNotifications(holdFirst: true)
        let fixture = try TerminationFixture(notifications: notification)
        defer { fixture.remove() }
        let effect = try XCTUnwrap(fixture.automation.runManually(fixture.rule))
        await waitUntil { notification.count == 1 }
        let termination = ApplicationTerminationCoordinator(target: fixture.automation)
        var replies: [Bool] = []
        termination.request { replies.append($0) }
        XCTAssertFalse(fixture.automation.acceptsInput)
        XCTAssertNil(fixture.automation.runManually(fixture.rule))
        fixture.automation.handle(event: .keyboard(keyCode: 12), modifiers: [])
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(notification.count, 1)
        XCTAssertEqual(fixture.history.pendingCount, 0, "Flush só depois do cleanup e feedback")
        XCTAssertTrue(replies.isEmpty)
        notification.release()
        _ = await effect.value
        await waitUntil { fixture.history.pendingCount == 1 }
        XCTAssertEqual(fixture.reports.count, 1)
        XCTAssertTrue(fixture.reports[0].wasCancelled)
        XCTAssertTrue(replies.isEmpty)
        fixture.history.release()
        await waitUntil { replies == [true] }
        XCTAssertEqual(fixture.log.entries.count, 1)
        XCTAssertEqual(MetricsStore(fileURL: fixture.metrics.fileURL).events.map(\.outcome), [.cancelled])
    }

    func testQuitFailureRestoresPreviousAcceptanceAndNeverRestartsCancelledEffect() async throws {
        for initiallyAccepting in [true, false] {
            let fixture = try TerminationFixture()
            defer { fixture.remove() }
            fixture.history.fail = true
            fixture.history.release()
            if !initiallyAccepting { _ = fixture.automation.suspendForTermination() }
            let termination = ApplicationTerminationCoordinator(target: fixture.automation)
            var replies: [Bool] = []
            termination.request { replies.append($0) }
            await waitUntil { replies == [false] }
            XCTAssertEqual(fixture.automation.acceptsInput, initiallyAccepting)
            XCTAssertEqual(fixture.notifications.count, 0)
            XCTAssertFalse(fixture.errors.isEmpty)
            XCTAssertNotNil(fixture.log.lastError)
        }
    }

    func testQuitTimeoutRepliesOnceWhileUncooperativeCleanupIsStillRetained() async throws {
        let notification = TerminationNotifications(holdFirst: true)
        let fixture = try TerminationFixture(notifications: notification)
        defer { fixture.remove() }
        let effect = try XCTUnwrap(fixture.automation.runManually(fixture.rule))
        await waitUntil { notification.count == 1 }
        let termination = ApplicationTerminationCoordinator(target: fixture.automation)
        let replied = expectation(description: "Watchdog responde sem aguardar o efeito")
        var replies: [Bool] = []
        let started = ContinuousClock.now
        termination.request { replies.append($0); replied.fulfill() }
        termination.request { _ in XCTFail("Pedido duplicado não inicia outra resposta") }
        var uiUpdated = false
        Task { @MainActor in uiUpdated = true }
        await waitUntil { uiUpdated }
        await fulfillment(of: [replied], timeout: 2.5)
        let elapsed = started.duration(to: .now)
        XCTAssertGreaterThanOrEqual(elapsed, .seconds(2))
        XCTAssertLessThan(elapsed, .milliseconds(2_300), "2s é o orçamento; a margem mede apenas o agendamento do runner")
        XCTAssertEqual(replies, [false])
        XCTAssertTrue(fixture.automation.acceptsInput)
        XCTAssertEqual(notification.count, 1)
        XCTAssertEqual(fixture.history.pendingCount, 0)
        XCTAssertTrue(fixture.reports.isEmpty)
        XCTAssertFalse(fixture.errors.isEmpty)
        notification.release()
        _ = await effect.value
        fixture.history.release()
        try await fixture.automation.flushFeedback()
        XCTAssertEqual(replies, [false], "Conclusão tardia não pode confirmar quit")
        XCTAssertEqual(fixture.reports.count, 1)
        XCTAssertTrue(fixture.reports[0].wasCancelled)
        XCTAssertEqual(notification.count, 1, "Restaurar aceitação não reinicia o efeito")
    }

    func testQuitRejectsContextAlreadyInFlightAndManualInput() async throws {
        let context = TerminationDelayedContext()
        let fixture = try TerminationFixture(context: context)
        defer { fixture.remove() }
        fixture.automation.handle(event: .keyboard(keyCode: 12), modifiers: [])
        await waitUntil { context.pending != nil }
        let termination = ApplicationTerminationCoordinator(target: fixture.automation)
        var replies: [Bool] = []
        termination.request { replies.append($0) }
        XCTAssertNil(fixture.automation.runManually(fixture.rule))
        fixture.automation.handle(event: .keyboard(keyCode: 12), modifiers: [])
        context.release()
        fixture.history.release()
        await waitUntil { replies == [true] }
        XCTAssertEqual(fixture.notifications.count, 0)
        XCTAssertTrue(fixture.reports.isEmpty)
        XCTAssertTrue(fixture.log.entries.isEmpty)
    }

    func testQuitPreservesAlreadyCommittedContinuousResultBeforeFlush() async throws {
        let continuous = TerminationContinuous()
        let rule = ShortcutRule(name: "Contínua", trigger: .trackpad(spec: TrackpadTriggerSpec(gesture: .swipeRight, fingerCount: 3)),
            action: .continuousWindow(target: .frontmost, operation: .moveHorizontal, curve: .linear))
        let fixture = try TerminationFixture(rule: rule, continuous: continuous)
        defer { fixture.remove() }
        let id = UUID()
        for phase in [GesturePhase.began, .changed, .ended] {
            fixture.automation.handle(event: .trackpad(GestureEvent(sessionID: id, kind: .swipeRight, phase: phase,
                fingerCount: 3, startRegion: .any, endRegion: .any, progress: 0.5, confidence: 1, occurredAt: Date())), modifiers: [])
        }
        fixture.automation.onExecutionFinished = { _, report, _ in
            fixture.history.observeCompletionCallback()
            fixture.reports.append(report)
        }
        continuous.completion.finish(.success(.committed))
        let termination = ApplicationTerminationCoordinator(target: fixture.automation)
        var replies: [Bool] = []
        termination.request { replies.append($0) }
        await waitUntil { fixture.history.pendingCount == 1 }
        XCTAssertEqual(fixture.reports.count, 1)
        XCTAssertTrue(fixture.reports[0].success)
        XCTAssertFalse(fixture.reports[0].wasCancelled)
        XCTAssertEqual(continuous.cancelCount, 1)
        XCTAssertEqual(fixture.automation.lastWorkflowReport, fixture.reports[0])
        XCTAssertEqual(fixture.history.observations, [.completionCallback, .flush],
            "O feedback contínuo precede flush, sem criar persistência que não existia nesse fluxo")
        XCTAssertTrue(fixture.metrics.events.isEmpty)
        XCTAssertTrue(replies.isEmpty)
        fixture.history.release()
        await waitUntil { replies == [true] }
        XCTAssertEqual(fixture.reports.count, 1, "Drenar não duplica o callback contínuo")
        XCTAssertTrue(fixture.log.entries.isEmpty)
        XCTAssertTrue(MetricsStore(fileURL: fixture.metrics.fileURL).events.isEmpty)
    }

    func testFailedFeedbackRemainsRetryableAndQuitRetryNeverRepeatsEffect() async throws {
        let files = TerminationFailingFiles()
        let fixture = try TerminationFixture(historyFileManager: files)
        defer { fixture.remove() }
        files.failWrites = true
        let effect = try XCTUnwrap(fixture.automation.runManually(fixture.rule))
        _ = await effect.value
        await waitUntil { fixture.log.lastError != nil }
        XCTAssertEqual(fixture.notifications.count, 1)
        XCTAssertEqual(fixture.reports.count, 1)
        XCTAssertTrue(fixture.log.entries.isEmpty)
        XCTAssertEqual(fixture.metrics.events.map(\.outcome), [.success])
        let termination = ApplicationTerminationCoordinator(target: fixture.automation)
        var replies: [Bool] = []
        termination.request { replies.append($0) }
        await waitUntil { replies == [false] }
        XCTAssertTrue(fixture.automation.acceptsInput)
        XCTAssertNotNil(fixture.log.lastError)
        files.failWrites = false
        termination.request { replies.append($0) }
        await waitUntil { replies == [false, true] }
        XCTAssertEqual(EventLogStore(fileURL: fixture.log.fileURL).entries.count, 1)
        XCTAssertEqual(fixture.notifications.count, 1)
        XCTAssertEqual(fixture.reports.count, 1)
        XCTAssertNil(fixture.log.lastError)
    }

    func testQuitRoutesDrainFailureOnlyToLifecyclePresenterAndKeepsDurableError() async throws {
        let fixture = try TerminationFixture()
        defer { fixture.remove() }
        let effect = try XCTUnwrap(fixture.automation.runManually(fixture.rule))
        _ = await effect.value
        await waitUntil { fixture.history.pendingCount == 1 }
        fixture.history.fail = true
        let presenter = TerminationFailurePresenter()
        let lifecycle = ApplicationLifecycleService(failurePresenter: presenter)
        var replies: [Bool] = []
        let delegate = AppDelegate(lifecycle: lifecycle, terminationReply: { _, value in replies.append(value) })
        delegate.lifecycle.configureTermination(ApplicationTerminationCoordinator(target: fixture.automation))
        XCTAssertEqual(delegate.applicationShouldTerminate(NSApplication.shared), .terminateLater)
        fixture.history.release()
        await waitUntil { replies == [false] }
        XCTAssertEqual(presenter.messages.count, 1)
        XCTAssertTrue(fixture.errors.isEmpty, "Não duplicar o erro de dreno no canal de alert da ContentView")
        XCTAssertNotNil(fixture.log.lastError, "O estado de persistência conserva a falha")
        XCTAssertTrue(fixture.automation.acceptsInput)
        XCTAssertEqual(fixture.notifications.count, 1)
    }

    func testQuitTimeoutDuringPersistenceDoesNotReplySuccessAfterLateACK() async throws {
        let fixture = try TerminationFixture()
        defer { fixture.remove() }
        let effect = try XCTUnwrap(fixture.automation.runManually(fixture.rule))
        _ = await effect.value
        await waitUntil { fixture.history.pendingCount == 1 }
        let termination = ApplicationTerminationCoordinator(target: fixture.automation)
        let replied = expectation(description: "Timeout de disco")
        var replies: [Bool] = []
        termination.request { replies.append($0); replied.fulfill() }
        await fulfillment(of: [replied], timeout: 2.5)
        XCTAssertEqual(replies, [false])
        XCTAssertTrue(fixture.automation.acceptsInput)
        XCTAssertEqual(fixture.history.pendingCount, 1, "A dependência permanece retida após o timeout")
        XCTAssertTrue(fixture.log.entries.isEmpty)
        fixture.history.release()
        try await fixture.automation.flushFeedback()
        XCTAssertEqual(replies, [false])
        XCTAssertEqual(fixture.log.entries.count, 1)
        XCTAssertEqual(fixture.notifications.count, 1)
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<500 where !condition() { try? await Task.sleep(for: .milliseconds(1)) }
        XCTAssertTrue(condition(), "A fronteira controlada não progrediu")
    }
}

@MainActor
private final class TerminationFixture {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Tico-quit-\(UUID())")
    let suite = "Tico-quit-\(UUID())"
    let history = TerminationHistory()
    let notifications: TerminationNotifications
    let rule: ShortcutRule
    let log: EventLogStore
    let metrics: MetricsStore
    let automation: AutomationCoordinator
    var reports: [WorkflowExecutionReport] = []
    var errors: [String] = []
    init(notifications: TerminationNotifications = TerminationNotifications(),
         rule: ShortcutRule? = nil,
         historyFileManager: FileManager? = nil,
         context: (any ContextSnapshotProviding)? = nil,
         continuous: (any ContinuousWindowActionControlling)? = nil) throws {
        self.notifications = notifications
        self.rule = rule ?? ShortcutRule(name: "Ensaio", trigger: .keyboard(keyCode: 12, modifiers: []),
            action: .notification(title: "Teste", body: "Inerte"))
        let store = ShortcutStore(fileURL: directory.appendingPathComponent("rules.json"), seedExamples: false)
        try store.add(self.rule)
        log = EventLogStore(fileURL: directory.appendingPathComponent("events.json"),
            fileManager: historyFileManager ?? .default, repository: historyFileManager == nil ? history : nil)
        metrics = MetricsStore(fileURL: directory.appendingPathComponent("metrics.json"))
        automation = AutomationCoordinator(shortcutStore: store, eventLogStore: log, metricsStore: metrics,
            actionRunner: ActionRunner(notificationService: notifications), continuousWindowController: continuous,
            approvalStore: AutomationApprovalStore(defaults: UserDefaults(suiteName: suite)!),
            contextSnapshotService: context ?? TerminationContext(), setContinuousPhasesEnabled: { _ in })
        automation.onExecutionFinished = { [weak self] _, report, _ in self?.reports.append(report) }
        automation.setErrorHandler { [weak self] in self?.errors.append($0) }
    }
    func remove() { try? FileManager.default.removeItem(at: directory); UserDefaults.standard.removePersistentDomain(forName: suite) }
}

@MainActor
private final class TerminationContext: ContextSnapshotProviding {
    func snapshot(modifiers: Set<InputModifier>, at date: Date) -> ContextSnapshot {
        ContextSnapshot(modifiers: modifiers, capturedAt: date)
    }
}

/// Estado de efeito e continuation protegidos por lock: o executor não é main.
private final class TerminationNotifications: NotificationDelivering, @unchecked Sendable {
    private let lock = NSLock()
    private let holdFirst: Bool
    private var calls = 0
    private var continuation: CheckedContinuation<Void, Never>?
    init(holdFirst: Bool = false) { self.holdFirst = holdFirst }
    var count: Int { lock.withLock { calls } }
    func deliver(title: String, body: String) async throws {
        await withCheckedContinuation { continuation in
            let hold = lock.withLock {
                calls += 1
                if holdFirst, calls == 1 { self.continuation = continuation; return true }
                return false
            }
            if !hold { continuation.resume() }
        }
    }
    func release() { let value = lock.withLock { let value = continuation; continuation = nil; return value }; value?.resume() }
}

/// Retém apenas a confirmação de persistência; nunca executa efeito ou IO real.
private final class TerminationHistory: EventLogPersisting, @unchecked Sendable {
    enum Observation: Equatable { case completionCallback, record, clear, flush }
    let initialEntries: [ExecutionLogEntry] = []
    let initialError: String? = nil
    private let lock = NSLock()
    private var held = true
    private var observed: [Observation] = []
    var observations: [Observation] { lock.withLock { observed } }
    func observeCompletionCallback() { lock.withLock { observed.append(.completionCallback) } }
    private var records: [ExecutionLogEntry] = []
    private var pending: [(EventLogMutation, UInt64, @Sendable (Result<EventLogRevision, Error>) -> Void)] = []
    var pendingCount: Int { lock.withLock { pending.count } }
    private var failing = false
    var fail: Bool { get { lock.withLock { failing } } set { lock.withLock { failing = newValue } } }
    func submit(_ mutation: EventLogMutation, revision: UInt64,
                completion: @escaping @Sendable (Result<EventLogRevision, Error>) -> Void) {
        lock.lock()
        switch mutation { case .record: observed.append(.record); case .clear: observed.append(.clear); case .flush: observed.append(.flush) }
        if held { pending.append((mutation, revision, completion)); lock.unlock(); return }
        let result = result(mutation, revision)
        lock.unlock(); completion(result)
    }
    private func result(_ mutation: EventLogMutation, _ revision: UInt64) -> Result<EventLogRevision, Error> {
        if failing { return .failure(CocoaError(.fileWriteNoPermission)) }
        switch mutation { case let .record(entry): records.insert(entry, at: 0); case .clear: records = []; case .flush: break }
        return .success(EventLogRevision(revision: revision, entries: records))
    }
    func release() {
        lock.lock(); held = false
        let callbacks = pending.map { ($0.2, result($0.0, $0.1)) }; pending.removeAll()
        lock.unlock()
        for callback in callbacks { callback.0(callback.1) }
    }
}

@MainActor
private final class TerminationDelayedContext: ContextSnapshotProviding {
    var pending: CheckedContinuation<ContextSnapshot?, Never>?
    func snapshot(modifiers: Set<InputModifier>, at date: Date) -> ContextSnapshot {
        ContextSnapshot(modifiers: modifiers, capturedAt: date)
    }
    func makeRequest(modifiers: Set<InputModifier>, at date: Date, includeWindowContext: Bool) -> ContextSnapshotRequest {
        ContextSnapshotRequest(base: snapshot(modifiers: modifiers, at: date), requiresResolution: true)
    }
    func resolve(_ request: ContextSnapshotRequest) async -> ContextSnapshot? {
        await withCheckedContinuation { pending = $0 }
    }
    func release() { let value = pending; pending = nil; value?.resume(returning: snapshot(modifiers: [], at: Date())) }
}

@MainActor
private final class TerminationContinuous: ContinuousWindowActionControlling {
    let completion = ContinuousWindowCompletion()
    var cancelCount = 0
    func begin(sessionID: UUID, target: ApplicationTarget, operation: ContinuousWindowOperation,
               capturedTarget: ContinuousWindowTarget?) throws {}
    func update(sessionID: UUID, progress: Double, curve: ContinuousResponseCurve) throws {}
    func commit(sessionID: UUID) -> ContinuousWindowCompletion { completion }
    func cancel(sessionID: UUID) -> ContinuousWindowCompletion { cancelCount += 1; return completion }
}

/// Injeta falha somente na criação do diretório do histórico temporário.
private final class TerminationFailingFiles: FileManager, @unchecked Sendable {
    private let lock = NSLock()
    private var failing = false
    var failWrites: Bool { get { lock.withLock { failing } } set { lock.withLock { failing = newValue } } }
    override func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool,
                                  attributes: [FileAttributeKey: Any]? = nil) throws {
        if failWrites { throw CocoaError(.fileWriteNoPermission) }
        try super.createDirectory(at: url, withIntermediateDirectories: createIntermediates, attributes: attributes)
    }
}

@MainActor
private final class TerminationFailurePresenter: ApplicationTerminationFailurePresenting {
    var messages: [String] = []
    func present(_ error: Error) { messages.append(error.localizedDescription) }
    func dismiss() {}
}
