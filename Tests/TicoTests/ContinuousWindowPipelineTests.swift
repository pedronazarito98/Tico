import Foundation
import XCTest
@testable import Tico

@MainActor
final class ContinuousWindowPipelineTests: XCTestCase {
    func testCoordinatorCoalescesBurstDuringBeginAndCommitsEndedValue() async throws {
        let backend = SyntheticContinuousAX(holdBegin: true)
        let fixture = try fixture(backend)
        defer { fixture.remove() }
        let id = UUID()
        fixture.send(id, .began)
        try await waitUntil { backend.enteredBegin }
        for value in 1...99 { fixture.send(id, .changed, Double(value) / 100) }
        fixture.send(id, .ended, 0.8)
        XCTAssertTrue(fixture.reports.isEmpty)
        XCTAssertTrue(backend.updates.isEmpty)
        backend.releaseBegin()
        try await waitUntil { fixture.reports.count == 1 }
        XCTAssertEqual(backend.updates.map(\.progress), [0.8])
        XCTAssertEqual(backend.position, 180, accuracy: 0.001)
        XCTAssertEqual(backend.committed, [id])
        XCTAssertTrue(fixture.reports[0].success)
        XCTAssertFalse(backend.usedMain)
        XCTAssertEqual(backend.maximumInFlight, 1)
        fixture.send(id, .changed, 0.1)
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(backend.updates.count, 1, "Nenhuma escrita depois da confirmação terminal")
    }

    func testCoordinatorKeepsOneLatestPendingWhileUpdateIsInFlight() async throws {
        let backend = SyntheticContinuousAX(holdUpdate: true)
        let fixture = try fixture(backend)
        defer { fixture.remove() }
        let id = UUID()
        fixture.send(id, .began)
        try await waitUntil { backend.begun.count == 1 }
        fixture.send(id, .changed, 0.1)
        try await waitUntil { backend.enteredUpdate }
        for value in 2...8 { fixture.send(id, .changed, Double(value) / 10) }
        fixture.send(id, .ended, 0.9)
        XCTAssertTrue(fixture.reports.isEmpty)
        backend.releaseUpdate()
        try await waitUntil { fixture.reports.count == 1 }
        XCTAssertEqual(backend.updates.map(\.progress), [0.1, 0.9])
        XCTAssertEqual(backend.position, 190, accuracy: 0.001)
        XCTAssertEqual(backend.committed, [id])
        XCTAssertEqual(backend.maximumInFlight, 1)
    }

    func testCancelledDiscardsPendingAndRestoresOnceBeforeConfirmation() async throws {
        let backend = SyntheticContinuousAX(holdUpdate: true)
        let fixture = try fixture(backend)
        defer { fixture.remove() }
        let id = UUID()
        fixture.send(id, .began)
        try await waitUntil { backend.begun.count == 1 }
        fixture.send(id, .changed, 0.1)
        try await waitUntil { backend.enteredUpdate }
        fixture.send(id, .changed, 0.9)
        fixture.send(id, .cancelled)
        let confirmation = fixture.service.cancel(sessionID: id)
        backend.releaseUpdate()
        let outcome = try await confirmation.wait()
        XCTAssertEqual(outcome, .cancelled)
        XCTAssertEqual(backend.updates.map(\.progress), [0.1])
        XCTAssertEqual(backend.restored, [id])
        XCTAssertEqual(backend.position, 100)
        XCTAssertTrue(backend.committed.isEmpty)
        XCTAssertTrue(fixture.reports.isEmpty)
        XCTAssertThrowsError(try fixture.service.update(sessionID: id, progress: 0.5, curve: .linear))
        let repeated = try await fixture.service.cancel(sessionID: id).wait()
        XCTAssertEqual(repeated, .cancelled)
        XCTAssertEqual(backend.restored, [id])
    }

    func testRestartDuringBeginCleansOldSessionBeforeNewSession() async throws {
        let backend = SyntheticContinuousAX(holdBegin: true)
        let fixture = try fixture(backend)
        defer { fixture.remove() }
        let old = UUID(), current = UUID()
        fixture.send(old, .began)
        try await waitUntil { backend.enteredBegin }
        fixture.send(old, .changed, 0.8)
        fixture.coordinator.cancelContinuousSessions()
        fixture.coordinator.cancelContinuousSessions()
        fixture.send(current, .began)
        fixture.send(current, .changed, 0.4)
        fixture.send(current, .ended, 0.5)
        backend.releaseBegin()
        try await waitUntil { fixture.reports.count == 1 }
        XCTAssertEqual(backend.restored, [old])
        XCTAssertEqual(backend.updates.map(\.sessionID), [current])
        XCTAssertEqual(backend.updates.map(\.progress), [0.5])
        XCTAssertEqual(backend.committed, [current])
        XCTAssertEqual(backend.operations, ["begin", "restore", "begin", "update", "commit"])
        XCTAssertEqual(backend.position, 150)
    }

    func testNewSessionOnSamePIDWaitsForCleanupOfStillActiveSession() async throws {
        let backend = SyntheticContinuousAX()
        let fixture = try fixture(backend)
        defer { fixture.remove() }
        let old = UUID(), current = UUID()
        fixture.send(old, .began)
        try await waitUntil { backend.begun.count == 1 }
        // A está ociosa, ainda ativa: não há update nem cancel em voo.
        fixture.send(current, .began)
        fixture.send(current, .ended, 0.4)
        try await waitUntil { fixture.reports.count == 1 }
        XCTAssertEqual(backend.restored, [old])
        XCTAssertEqual(backend.operations, ["begin", "restore", "begin", "update", "commit"])
        fixture.send(old, .changed, 0.9)
        fixture.send(old, .ended, 0.9)
        _ = await fixture.coordinator.drainContinuousSessions()
        XCTAssertEqual(backend.updates.map(\.sessionID), [current])
        XCTAssertEqual(backend.position, 140)
        XCTAssertEqual(backend.restored, [old], "Cleanup antigo nunca desfaz a sessão nova")
        XCTAssertEqual(fixture.reports.count, 1)
    }

    func testPartialFailureRestoresAndNeverReportsSuccess() async throws {
        let backend = SyntheticContinuousAX(failUpdate: true)
        let fixture = try fixture(backend)
        defer { fixture.remove() }
        let id = UUID()
        fixture.send(id, .began)
        fixture.send(id, .changed, 0.4)
        fixture.send(id, .ended, 0.8)
        try await waitUntil { !fixture.errors.isEmpty }
        XCTAssertEqual(backend.restored, [id])
        XCTAssertEqual(backend.position, 100)
        XCTAssertTrue(backend.committed.isEmpty)
        XCTAssertTrue(fixture.reports.isEmpty)
        XCTAssertNil(fixture.coordinator.lastWorkflowReport)
    }

    func testExpiredBeginAndRevokedFocusNeverStartAXAfterQueueWait() async throws {
        let backend = SyntheticContinuousAX(holdBegin: true)
        let clock = ContinuousTestClock()
        let service = ContinuousWindowActionService(backend: backend,
            captureTarget: { _ in ContinuousWindowTarget(processIdentifier: 11, displays: []) })
        let first = UUID(), expired = UUID(), stale = UUID()
        try service.begin(sessionID: first, target: .frontmost, operation: .moveHorizontal)
        try await waitUntil { backend.enteredBegin }
        let expiredTarget = ContinuousWindowTarget(processIdentifier: 22, displays: [], budget: AXOperationBudget(now: { clock.now }))
        try service.begin(sessionID: expired, target: .frontmost, operation: .moveHorizontal, capturedTarget: expiredTarget)
        let generation = CaptureGeneration()
        let staleTarget = ContinuousWindowTarget(processIdentifier: 33, displays: [], generation: generation)
        try service.begin(sessionID: stale, target: .frontmost, operation: .moveHorizontal, capturedTarget: staleTarget)
        let expiredConfirmation = service.commit(sessionID: expired)
        let staleConfirmation = service.commit(sessionID: stale)
        let cancelled = service.cancel(sessionID: first)
        clock.advance(to: 0.150)
        generation.invalidate()
        backend.releaseBegin()
        _ = try await cancelled.wait()
        do { _ = try await expiredConfirmation.wait(); XCTFail("Budget vencido não pode confirmar") } catch { }
        do { _ = try await staleConfirmation.wait(); XCTFail("Foco revogado não pode confirmar") } catch { }
        XCTAssertEqual(backend.begun.map(\.pid), [11])
        XCTAssertTrue(backend.updates.isEmpty)
        XCTAssertTrue(backend.committed.isEmpty)
    }

    func testContextWaitKeepsCapturedPIDAndCoalescesBeforeBegin() async throws {
        let backend = SyntheticContinuousAX()
        let context = ContinuousDelayedContext()
        var pid: Int32 = 11
        var captures = 0
        let fixture = try fixture(backend, context: context, needsWindow: true, capture: { _ in
            captures += 1
            return ContinuousWindowTarget(processIdentifier: pid, displays: [])
        })
        defer { fixture.remove() }
        let id = UUID()
        fixture.send(id, .began)
        try await waitUntil { context.pending != nil }
        pid = 22
        for value in 1...99 { fixture.send(id, .changed, Double(value) / 100) }
        fixture.send(id, .ended, 0.6)
        XCTAssertEqual(captures, 1)
        context.complete()
        try await waitUntil { fixture.reports.count == 1 }
        XCTAssertEqual(backend.begun.map(\.pid), [11])
        XCTAssertEqual(backend.updates.map(\.progress), [0.6])
        XCTAssertEqual(context.requests, 1)
    }

    func testLateUpdateBudgetFailureRestoresAndCannotBecomeSuccess() async throws {
        let backend = SyntheticContinuousAX(holdUpdate: true)
        let clock = ContinuousTestClock()
        let fixture = try fixture(backend, budgetFactory: { AXOperationBudget(now: { clock.now }) })
        defer { fixture.remove() }
        let id = UUID()
        fixture.send(id, .began)
        try await waitUntil { backend.begun.count == 1 }
        fixture.send(id, .changed, 0.2)
        try await waitUntil { backend.enteredUpdate }
        fixture.send(id, .ended, 0.8)
        clock.advance(to: 0.150)
        backend.releaseUpdate()
        try await waitUntil { !fixture.errors.isEmpty }
        XCTAssertEqual(backend.restored, [id])
        XCTAssertEqual(backend.position, 100)
        XCTAssertTrue(fixture.reports.isEmpty)
        XCTAssertTrue(backend.committed.isEmpty)
    }

    private func fixture(_ backend: SyntheticContinuousAX,
                         context: (any ContextSnapshotProviding)? = nil, needsWindow: Bool = false,
                         capture: (@MainActor (ApplicationTarget) -> ContinuousWindowTarget?)? = nil,
                         budgetFactory: @escaping @Sendable () -> AXOperationBudget = { AXOperationBudget() }) throws -> ContinuousFixture {
        try ContinuousFixture(backend: backend, context: context ?? ContinuousReadyContext(), needsWindow: needsWindow,
            capture: capture, budgetFactory: budgetFactory)
    }
    private func waitUntil(_ condition: @escaping @MainActor () -> Bool) async throws {
        for _ in 0..<150 { if condition() { return }; try await Task.sleep(for: .milliseconds(2)) }
        XCTFail("Condição não atendida")
    }
}

@MainActor private final class ContinuousFixture {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let service: ContinuousWindowActionService
    let coordinator: AutomationCoordinator
    var reports: [WorkflowExecutionReport] = []
    var errors: [String] = []
    init(backend: SyntheticContinuousAX, context: any ContextSnapshotProviding, needsWindow: Bool,
         capture: (@MainActor (ApplicationTarget) -> ContinuousWindowTarget?)?,
         budgetFactory: @escaping @Sendable () -> AXOperationBudget) throws {
        service = ContinuousWindowActionService(backend: backend, captureTarget: capture ?? { _ in
            ContinuousWindowTarget(processIdentifier: 11, displays: [])
        }, budgetFactory: budgetFactory)
        let rules = ShortcutStore(fileURL: directory.appendingPathComponent("rules.json"), seedExamples: false)
        var rule = ShortcutRule(name: "Synthetic", trigger: .trackpad(spec: TrackpadTriggerSpec(gesture: .swipeRight, fingerCount: 3)),
            action: .continuousWindow(target: .frontmost, operation: .moveHorizontal, curve: .linear))
        if needsWindow { rule.conditions = [.windowTitle(RuleTextMatcher(value: "Allowed"))] }
        try rules.add(rule)
        coordinator = AutomationCoordinator(shortcutStore: rules,
            eventLogStore: EventLogStore(fileURL: directory.appendingPathComponent("events.json")),
            metricsStore: MetricsStore(fileURL: directory.appendingPathComponent("metrics.json")),
            continuousWindowController: service, contextSnapshotService: context, setContinuousPhasesEnabled: { _ in })
        coordinator.onExecutionFinished = { [weak self] _, report, _ in self?.reports.append(report) }
        coordinator.setErrorHandler { [weak self] in self?.errors.append($0) }
    }
    func send(_ id: UUID, _ phase: GesturePhase, _ progress: Double = 0) {
        coordinator.handle(event: .trackpad(GestureEvent(sessionID: id, kind: .swipeRight, phase: phase,
            fingerCount: 3, startRegion: .any, endRegion: .any, progress: progress, confidence: 1, occurredAt: Date())), modifiers: [])
    }
    func remove() { coordinator.stop(); try? FileManager.default.removeItem(at: directory) }
}

/// Double de IPC isolado: somente o lock acessa observações; sem AX/CGEvent.
private final class SyntheticContinuousAX: ContinuousWindowAXOperating, @unchecked Sendable {
    struct Begun { let id: UUID; let pid: Int32 }
    struct Update { let sessionID: UUID; let progress: Double }
    private let lock = NSLock()
    private let beginGate = DispatchSemaphore(value: 0), updateGate = DispatchSemaphore(value: 0)
    private let holdBegin: Bool, holdUpdate: Bool, failUpdate: Bool
    private var didEnterBegin = false, didEnterUpdate = false
    private var begins: [Begun] = [], values: [Update] = [], restores: [UUID] = [], commits: [UUID] = [], steps: [String] = []
    private var currentPosition = 100.0, onMain = false, inFlight = 0, maximum = 0
    init(holdBegin: Bool = false, holdUpdate: Bool = false, failUpdate: Bool = false) {
        self.holdBegin = holdBegin; self.holdUpdate = holdUpdate; self.failUpdate = failUpdate
    }
    var enteredBegin: Bool { locked { didEnterBegin } }
    var enteredUpdate: Bool { locked { didEnterUpdate } }
    var begun: [Begun] { locked { begins } }
    var updates: [Update] { locked { values } }
    var restored: [UUID] { locked { restores } }
    var committed: [UUID] { locked { commits } }
    var operations: [String] { locked { steps } }
    var position: Double { locked { currentPosition } }
    var usedMain: Bool { locked { onMain } }
    var maximumInFlight: Int { locked { maximum } }
    func releaseBegin() { beginGate.signal() }
    func releaseUpdate() { updateGate.signal() }
    func begin(sessionID: UUID, target: ContinuousWindowTarget, operation: ContinuousWindowOperation, budget: AXOperationBudget) throws {
        enter(); defer { leave() }
        let shouldHold = locked { let first = !didEnterBegin; didEnterBegin = true; return holdBegin && first }
        if shouldHold { _ = beginGate.wait(timeout: .now() + 1) }
        locked { begins.append(Begun(id: sessionID, pid: target.processIdentifier)); steps.append("begin") }
    }
    func update(sessionID: UUID, progress: Double, curve: ContinuousResponseCurve, budget: AXOperationBudget) throws {
        enter(); defer { leave() }
        let shouldHold = locked { let first = !didEnterUpdate; didEnterUpdate = true; return holdUpdate && first }
        if shouldHold { _ = updateGate.wait(timeout: .now() + 1) }
        locked { values.append(Update(sessionID: sessionID, progress: progress)); currentPosition = 100 + progress * 100; steps.append("update") }
        if failUpdate { throw WindowControlError.operationFailed("falha sintética parcial") }
    }
    func finish(sessionID: UUID, restoring: Bool, budget: AXOperationBudget) throws {
        enter(); defer { leave() }
        locked {
            guard begins.contains(where: { $0.id == sessionID }) else { return }
            if restoring { restores.append(sessionID); currentPosition = 100; steps.append("restore") }
            else { commits.append(sessionID); steps.append("commit") }
        }
    }
    private func enter() { locked { inFlight += 1; maximum = max(maximum, inFlight); onMain = onMain || Thread.isMainThread } }
    private func leave() { locked { inFlight -= 1 } }
    private func locked<T>(_ body: () -> T) -> T { lock.lock(); defer { lock.unlock() }; return body() }
}
private final class ContinuousTestClock: @unchecked Sendable {
    private let lock = NSLock(); private var value = 0.0
    var now: TimeInterval { lock.lock(); defer { lock.unlock() }; return value }
    func advance(to value: TimeInterval) { lock.lock(); self.value = value; lock.unlock() }
}
@MainActor private final class ContinuousReadyContext: ContextSnapshotProviding {
    func snapshot(modifiers: Set<InputModifier>, at date: Date) -> ContextSnapshot { ContextSnapshot(modifiers: modifiers, capturedAt: date) }
}
@MainActor private final class ContinuousDelayedContext: ContextSnapshotProviding {
    var pending: (ContextSnapshotRequest, CheckedContinuation<ContextSnapshot?, Never>)?
    var requests = 0
    func snapshot(modifiers: Set<InputModifier>, at date: Date) -> ContextSnapshot { ContextSnapshot(modifiers: modifiers, capturedAt: date) }
    func makeRequest(modifiers: Set<InputModifier>, at date: Date, includeWindowContext: Bool) -> ContextSnapshotRequest {
        requests += 1
        return ContextSnapshotRequest(base: snapshot(modifiers: modifiers, at: date), requiresResolution: true)
    }
    func resolve(_ request: ContextSnapshotRequest) async -> ContextSnapshot? { await withCheckedContinuation { pending = (request, $0) } }
    func complete() {
        guard let (request, continuation) = pending else { return }
        pending = nil
        var result = request.base; result.frontmostWindowTitle = "Allowed"
        continuation.resume(returning: result)
    }
}
