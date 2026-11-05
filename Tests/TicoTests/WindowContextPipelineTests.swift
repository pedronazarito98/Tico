import Foundation
import XCTest
@testable import Tico

@MainActor
final class WindowContextPipelineTests: XCTestCase {
    func testAXBudgetCapsEachMessageAndExpiresAt150Milliseconds() {
        var seconds = 0.0
        let budget = AXOperationBudget(now: { seconds })
        XCTAssertEqual(budget.messageTimeout ?? 0, 0.05, accuracy: 0.000001)
        seconds = 0.125
        XCTAssertEqual(budget.messageTimeout ?? 0, 0.025, accuracy: 0.000001)
        seconds = 0.150
        XCTAssertNil(budget.messageTimeout)
    }

    func testContextIPCDoesNotOccupyMainWhileDependencyIsHeld() async throws {
        let entered = expectation(description: "IPC começou")
        let release = DispatchSemaphore(value: 0)
        let probe = ContextThreadProbe()
        let reader = WindowContextReader(operation: { pid, _ in
            probe.record(pid: pid, main: Thread.isMainThread)
            entered.fulfill()
            _ = release.wait(timeout: .now() + 1)
            return WindowContext(title: "Synthetic", frame: CGRect(x: 10, y: 10, width: 100, height: 100))
        })
        let task = Task { await reader.focusedWindowContext(processIdentifier: 42, budget: AXOperationBudget()) }
        await fulfillment(of: [entered], timeout: 1)
        var uiValue = 0
        uiValue += 1
        XCTAssertEqual(uiValue, 1)
        XCTAssertEqual(probe.pids, [42])
        XCTAssertEqual(probe.wasMain, false)
        release.signal()
        let result = await task.value
        XCTAssertEqual(result?.title, "Synthetic")
        XCTAssertEqual(result?.frame, CGRect(x: 10, y: 10, width: 100, height: 100))
    }

    func testWatchdogRejectsLateContextAndDoesNotWaitForBlockedIPC() async {
        let entered = expectation(description: "IPC retido")
        let release = DispatchSemaphore(value: 0)
        defer { release.signal() }
        let reader = WindowContextReader(operation: { _, _ in
            entered.fulfill()
            _ = release.wait(timeout: .now() + 1)
            return WindowContext(title: "Resposta tardia")
        })
        let started = ContinuousClock.now
        let task = Task { await reader.focusedWindowContext(processIdentifier: 42, budget: AXOperationBudget()) }
        await fulfillment(of: [entered], timeout: 1)
        let result = await task.value
        XCTAssertNil(result)
        XCTAssertLessThan(started.duration(to: .now), .milliseconds(500))
    }

    func testContextFixesPIDAndScreensAtIngressAndRejectsChangedApplication() async throws {
        let reader = DelayedContextReader()
        var environment = environment(pid: 11, bundle: "synthetic.first")
        let service = ContextSnapshotService(windowContextReader: reader, captureEnvironment: { environment }, captureDisplays: { self.displays() })
        let request = service.makeRequest(modifiers: [.command], at: Date(timeIntervalSince1970: 1), includeWindowContext: true)
        let task = Task { await service.resolve(request) }
        try await waitUntil { reader.count == 1 }
        environment = self.environment(pid: 22, bundle: "synthetic.second")
        reader.complete(WindowContext(title: "Old", frame: CGRect(x: 10, y: 10, width: 100, height: 100)))
        let result = await task.value
        XCTAssertNil(result)
        XCTAssertEqual(reader.pids, [11])
        XCTAssertEqual(request.base.frontmostApplicationBundleIdentifier, "synthetic.first")
        XCTAssertEqual(request.base.modifiers, [.command])
        let obsolete = await service.resolve(request)
        XCTAssertNil(obsolete)
        XCTAssertEqual(reader.pids, [11], "Não consulta PID novo para reaproveitar entrada antiga")
    }

    func testUnavailableOrChangedWindowFailsClosedAndCheapContextAvoidsIPC() async throws {
        let reader = DelayedContextReader()
        let environment = environment(pid: 11, bundle: "synthetic.first")
        let service = ContextSnapshotService(windowContextReader: reader, captureEnvironment: { environment }, captureDisplays: { self.displays() })
        let cheap = service.makeRequest(modifiers: [], at: Date(), includeWindowContext: false)
        let cheapResult = await service.resolve(cheap)
        XCTAssertEqual(cheapResult?.frontmostApplicationBundleIdentifier, "synthetic.first")
        XCTAssertFalse(RuleCondition.windowTitle(RuleTextMatcher(value: "Synthetic")).matches(try XCTUnwrap(cheapResult)))
        XCTAssertFalse(RuleCondition.display(identifier: "synthetic-screen").matches(try XCTUnwrap(cheapResult)))
        XCTAssertEqual(reader.count, 0)
        let request = service.makeRequest(modifiers: [], at: Date(), includeWindowContext: true)
        let task = Task { await service.resolve(request) }
        try await waitUntil { reader.count == 1 }
        reader.complete(WindowContext(title: "Synthetic", focusIsCurrent: false))
        let result = await task.value
        XCTAssertNil(result)
    }

    func testSerialEvaluationAndClosedContextObserverRejectLateResponses() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ShortcutStore(fileURL: directory.appendingPathComponent("rules.json"), seedExamples: false)
        for key in [UInt16(12), 13] {
            var rule = ShortcutRule(name: "Synthetic", trigger: .keyboard(keyCode: key, modifiers: []),
                action: .notification(title: String(key), body: ""))
            rule.conditions = [.windowTitle(RuleTextMatcher(value: "Allowed"))]
            try store.add(rule)
        }
        let provider = OrderedContextProvider()
        let notifications = ContextNotificationProbe()
        let coordinator = AutomationCoordinator(shortcutStore: store,
            eventLogStore: EventLogStore(fileURL: directory.appendingPathComponent("events.json")),
            metricsStore: MetricsStore(fileURL: directory.appendingPathComponent("metrics.json")),
            actionRunner: ActionRunner(notificationService: notifications), contextSnapshotService: provider,
            setContinuousPhasesEnabled: { _ in })
        coordinator.handle(event: .keyboard(keyCode: 12, timestamp: Date(timeIntervalSince1970: 1)), modifiers: [])
        coordinator.handle(event: .keyboard(keyCode: 13, timestamp: Date(timeIntervalSince1970: 2)), modifiers: [])
        XCTAssertEqual(provider.capturedDates, [Date(timeIntervalSince1970: 1), Date(timeIntervalSince1970: 2)])
        try await waitUntil { provider.pending.count == 1 }
        XCTAssertTrue(notifications.titles.isEmpty)
        provider.complete()
        try await waitUntil { provider.pending.count == 1 && notifications.titles == ["12"] }
        provider.complete()
        try await waitUntil { notifications.titles == ["12", "13"] }
        XCTAssertEqual(coordinator.currentContextSnapshot?.capturedAt, Date(timeIntervalSince1970: 2))
        let observer = UUID()
        coordinator.beginContextObservation(id: observer, modifiers: [.shift])
        try await waitUntil { provider.pending.count == 1 }
        coordinator.endContextObservation(id: observer)
        provider.complete(title: "Late editor")
        for _ in 0..<5 { await Task.yield() }
        XCTAssertNil(coordinator.currentContextSnapshot?.frontmostWindowTitle)
        coordinator.stop()
    }

    func testOlderObserverResponseCannotOverwriteNewerContext() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let provider = OrderedContextProvider()
        let coordinator = AutomationCoordinator(
            shortcutStore: ShortcutStore(fileURL: directory.appendingPathComponent("rules.json"), seedExamples: false),
            eventLogStore: EventLogStore(fileURL: directory.appendingPathComponent("events.json")),
            metricsStore: MetricsStore(fileURL: directory.appendingPathComponent("metrics.json")),
            contextSnapshotService: provider, setContinuousPhasesEnabled: { _ in })
        let first = UUID(), second = UUID()
        coordinator.beginContextObservation(id: first, modifiers: [])
        try await waitUntil { provider.pending.count == 1 }
        coordinator.beginContextObservation(id: second, modifiers: [.shift])
        try await waitUntil { provider.pending.count == 2 }
        provider.complete(title: "New", at: 1)
        try await waitUntil { coordinator.currentContextSnapshot?.frontmostWindowTitle == "New" }
        provider.complete(title: "Old")
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(coordinator.currentContextSnapshot?.frontmostWindowTitle, "New")
        XCTAssertEqual(coordinator.currentContextSnapshot?.modifiers, [.shift])
        coordinator.endContextObservation(id: first)
        coordinator.endContextObservation(id: second)
        coordinator.stop()
    }

    func testCapturedScreensAndExpiredRequestDoNotRetargetOrStartIPC() async throws {
        let reader = DelayedContextReader()
        let environment = environment(pid: 11, bundle: "synthetic.first")
        var screens = displays()
        let service = ContextSnapshotService(windowContextReader: reader, captureEnvironment: { environment }, captureDisplays: { screens })
        var request = service.makeRequest(modifiers: [], at: Date(), includeWindowContext: true)
        let task = Task { await service.resolve(request) }
        try await waitUntil { reader.count == 1 }
        screens = []
        reader.complete(WindowContext(title: "Synthetic", frame: CGRect(x: 10, y: 10, width: 100, height: 100)))
        let result = await task.value
        XCTAssertEqual(result?.displayIdentifier, "synthetic-screen")
        XCTAssertEqual(result?.frontmostWindowTitle, "Synthetic")
        var clock = 0.0
        request.budget = AXOperationBudget(now: { clock })
        clock = 0.150
        let expired = await service.resolve(request)
        XCTAssertNil(expired)
        XCTAssertEqual(reader.count, 1, "Espera anterior consome orçamento antes do primeiro IPC")
    }

    func testCheapRequestsAndRevalidationNeverReadScreens() async throws {
        let reader = DelayedContextReader()
        let environment = environment(pid: 11, bundle: "synthetic.first")
        var screenReads = 0
        let service = ContextSnapshotService(windowContextReader: reader,
            captureEnvironment: { environment }, captureDisplays: {
                screenReads += 1
                return []
            })
        for _ in 0..<10 {
            let request = service.makeRequest(modifiers: [], at: Date(), includeWindowContext: false)
            XCTAssertTrue(service.isCurrent(request))
        }
        XCTAssertEqual(screenReads, 0)
        let request = service.makeRequest(modifiers: [], at: Date(), includeWindowContext: true)
        XCTAssertEqual(screenReads, 1)
        XCTAssertTrue(service.isCurrent(request))
        let task = Task { await service.resolve(request) }
        try await waitUntil { reader.count == 1 }
        reader.complete(WindowContext(title: "Synthetic"))
        _ = await task.value
        XCTAssertEqual(screenReads, 1, "Revalidação só consulta PID/foco")
    }

    func testClosedPanelCannotReopenWhenItsContextArrivesLate() async throws {
        let fixture = try contextPanelFixture()
        defer { fixture.companion.closePanel(); try? FileManager.default.removeItem(at: fixture.directory) }
        fixture.companion.showActions()
        try await waitUntil { fixture.provider.pending.count == 1 }
        fixture.companion.closePanel()
        fixture.provider.complete()
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(fixture.panel.presentations.count, 0)
        XCTAssertNil(fixture.companion.context)
    }

    func testRetiredPanelCallbacksCannotCloseOrExecuteAgainstNewPanel() async throws {
        let fixture = try contextPanelFixture()
        defer { fixture.companion.closePanel(); try? FileManager.default.removeItem(at: fixture.directory) }
        var contentRequests = 0, selectionRequests = 0
        fixture.companion.onRequestContent = { contentRequests += 1 }
        fixture.companion.onRequestSelection = { selectionRequests += 1 }
        fixture.companion.showActions()
        try await waitUntil { fixture.provider.pending.count == 1 }
        fixture.provider.complete()
        try await waitUntil { fixture.panel.presentations.count == 1 }
        let old = fixture.panel.presentations[0]
        fixture.companion.closePanel()
        fixture.companion.showActions()
        try await waitUntil { fixture.provider.pending.count == 1 }
        fixture.provider.complete()
        try await waitUntil { fixture.panel.presentations.count == 2 }
        let closes = fixture.panel.closes
        old.select(fixture.ruleID)
        old.content()
        old.selection()
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(fixture.panel.closes, closes)
        XCTAssertEqual(fixture.provider.pending.count, 0)
        XCTAssertEqual(contentRequests, 0)
        XCTAssertEqual(selectionRequests, 0)
        XCTAssertTrue(fixture.notifications.titles.isEmpty)
        while !fixture.provider.pending.isEmpty { fixture.provider.complete() }
    }

    func testQueuedWindowSequenceKeepsContextForFollowingStepAndMismatch() async throws {
        for keys in [[UInt16(12), 13], [UInt16(12), 14, 13]] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = ShortcutStore(fileURL: directory.appendingPathComponent("rules.json"), seedExamples: false)
            var rule = ShortcutRule(name: "Synthetic sequence", trigger: .sequence(TriggerSequence(steps: [
                .keyboard(keyCode: 12, modifiers: []), .keyboard(keyCode: 13, modifiers: [])
            ], maximumInterval: 0.15, ambiguityPolicy: .cancelOnMismatch)), action: .notification(title: "Sequence", body: ""))
            rule.conditions = [.windowTitle(RuleTextMatcher(value: "Allowed"))]
            try store.add(rule)
            let provider = OrderedContextProvider()
            let notifications = ContextNotificationProbe()
            let coordinator = AutomationCoordinator(shortcutStore: store,
                eventLogStore: EventLogStore(fileURL: directory.appendingPathComponent("events.json")),
                metricsStore: MetricsStore(fileURL: directory.appendingPathComponent("metrics.json")),
                actionRunner: ActionRunner(notificationService: notifications), contextSnapshotService: provider,
                setContinuousPhasesEnabled: { _ in })
            let now = Date()
            for (index, key) in keys.enumerated() {
                coordinator.handle(event: .keyboard(keyCode: key,
                    timestamp: index == 0 ? now.addingTimeInterval(-0.1) : now), modifiers: [])
            }
            XCTAssertEqual(provider.windowRequests, Array(repeating: true, count: keys.count))
            for (index, _) in keys.enumerated() {
                for _ in 0..<25 {
                    if !provider.pending.isEmpty { break }
                    await Task.yield()
                }
                // O segundo evento chegou dentro do intervalo, mas sua resposta
                // AX termina depois do intervalo do primeiro. A latência de
                // processamento não altera os timestamps da sequência.
                if index == 1 { try await Task.sleep(for: .milliseconds(80)) }
                if !provider.pending.isEmpty { provider.complete() }
            }
            for _ in 0..<25 { await Task.yield() }
            XCTAssertEqual(notifications.titles, keys.count == 2 ? ["Sequence"] : [])
            coordinator.stop()
        }
    }

    func testAmbiguityDeadlineCannotOvertakeAnAlreadyQueuedLongerSequenceStep() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ShortcutStore(fileURL: directory.appendingPathComponent("rules.json"), seedExamples: false)
        for (name, keys) in [("Short", [UInt16(12), 13]), ("Long", [UInt16(12), 13, 14])] {
            var rule = ShortcutRule(name: name, trigger: .sequence(TriggerSequence(
                steps: keys.map { .keyboard(keyCode: $0, modifiers: []) }, maximumInterval: 0.15)),
                action: .notification(title: name, body: ""))
            rule.conditions = [.windowTitle(RuleTextMatcher(value: "Allowed"))]
            try store.add(rule)
        }
        let provider = OrderedContextProvider()
        let notifications = ContextNotificationProbe()
        let coordinator = AutomationCoordinator(shortcutStore: store,
            eventLogStore: EventLogStore(fileURL: directory.appendingPathComponent("events.json")),
            metricsStore: MetricsStore(fileURL: directory.appendingPathComponent("metrics.json")),
            actionRunner: ActionRunner(notificationService: notifications), contextSnapshotService: provider,
            setContinuousPhasesEnabled: { _ in })
        let now = Date()
        for (index, key) in [UInt16(12), 13, 14].enumerated() {
            coordinator.handle(event: .keyboard(keyCode: key,
                timestamp: now.addingTimeInterval(Double(index - 2) * 0.1)), modifiers: [])
        }
        for _ in 0..<2 {
            try await waitUntil { provider.pending.count == 1 }
            provider.complete()
        }
        try await waitUntil { provider.pending.count == 1 }
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertTrue(notifications.titles.isEmpty, "Deadline não ultrapassa a entrada já aceita")
        provider.complete()
        try await waitUntil { notifications.titles.contains("Long") }
        XCTAssertEqual(notifications.titles, ["Long"], "Prefixo curto não executa junto da sequência longa")
        coordinator.stop()
    }

    private func contextPanelFixture() throws -> (directory: URL, ruleID: UUID, companion: CompanionCoordinator,
        provider: OrderedContextProvider, panel: InertContextualPanel, notifications: ContextNotificationProbe) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = ShortcutStore(fileURL: directory.appendingPathComponent("rules.json"), seedExamples: false)
        let rule = ShortcutRule(name: "Synthetic", trigger: .keyboard(keyCode: 12, modifiers: []),
            action: .notification(title: "Synthetic", body: ""))
        try store.add(rule)
        let provider = OrderedContextProvider()
        provider.bundleIdentifier = "synthetic.first"
        let notifications = ContextNotificationProbe()
        let automation = AutomationCoordinator(shortcutStore: store,
            eventLogStore: EventLogStore(fileURL: directory.appendingPathComponent("events.json")),
            metricsStore: MetricsStore(fileURL: directory.appendingPathComponent("metrics.json")),
            actionRunner: ActionRunner(notificationService: notifications), contextSnapshotService: provider,
            setContinuousPhasesEnabled: { _ in })
        let panel = InertContextualPanel()
        let companion = CompanionCoordinator(store: store, automation: automation, contextProvider: provider,
            allowsExecution: true, panel: panel)
        return (directory, rule.id, companion, provider, panel, notifications)
    }

    private func environment(pid: Int32, bundle: String) -> ContextEnvironmentSnapshot {
        ContextEnvironmentSnapshot(processIdentifier: pid, bundleIdentifier: bundle, applicationName: "Synthetic")
    }
    private func displays() -> [WindowDisplaySnapshot] {
        [WindowDisplaySnapshot(identifier: "synthetic-screen", frame: CGRect(x: 0, y: 0, width: 1000, height: 800), visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 800))]
    }
    private func waitUntil(_ condition: @escaping @MainActor () -> Bool) async throws {
        for _ in 0..<100 { if condition() { return }; try await Task.sleep(for: .milliseconds(5)) }
        XCTFail("Condição não atendida")
    }
}

/// Estado do double sincronizado, sem AX/AppKit reais.
private final class ContextThreadProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Int32] = []
    private var main = true
    var pids: [Int32] { lock.lock(); defer { lock.unlock() }; return values }
    var wasMain: Bool { lock.lock(); defer { lock.unlock() }; return main }
    func record(pid: Int32, main: Bool) { lock.lock(); values.append(pid); self.main = main; lock.unlock() }
}
private final class DelayedContextReader: WindowContextReading, @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [Int32] = []
    private var continuations: [CheckedContinuation<WindowContext?, Never>] = []
    var count: Int { lock.lock(); defer { lock.unlock() }; return requests.count }
    var pids: [Int32] { lock.lock(); defer { lock.unlock() }; return requests }
    func focusedWindowContext(processIdentifier: Int32, budget: AXOperationBudget) async -> WindowContext? {
        await withCheckedContinuation { continuation in
            lock.lock(); requests.append(processIdentifier); continuations.append(continuation); lock.unlock()
        }
    }
    func complete(_ result: WindowContext?) {
        lock.lock(); let continuation = continuations.removeFirst(); lock.unlock()
        continuation.resume(returning: result)
    }
}
@MainActor private final class OrderedContextProvider: ContextSnapshotProviding {
    var bundleIdentifier: String?
    var capturedDates: [Date] = []
    var windowRequests: [Bool] = []
    var pending: [(ContextSnapshotRequest, CheckedContinuation<ContextSnapshot?, Never>)] = []
    func snapshot(modifiers: Set<InputModifier>, at date: Date) -> ContextSnapshot {
        ContextSnapshot(frontmostApplicationBundleIdentifier: bundleIdentifier, modifiers: modifiers, capturedAt: date)
    }
    func makeRequest(modifiers: Set<InputModifier>, at date: Date, includeWindowContext: Bool) -> ContextSnapshotRequest {
        capturedDates.append(date)
        windowRequests.append(includeWindowContext)
        return ContextSnapshotRequest(base: snapshot(modifiers: modifiers, at: date), requiresResolution: includeWindowContext)
    }
    func resolve(_ request: ContextSnapshotRequest) async -> ContextSnapshot? {
        guard request.requiresResolution else { return request.base }
        return await withCheckedContinuation { pending.append((request, $0)) }
    }
    func complete(title: String = "Allowed", at index: Int = 0) {
        let (request, continuation) = pending.remove(at: index)
        var result = request.base
        result.frontmostWindowTitle = title
        continuation.resume(returning: result)
    }
}
private final class ContextNotificationProbe: NotificationDelivering {
    var titles: [String] = []
    func deliver(title: String, body: String) async throws { titles.append(title) }
}

@MainActor private final class InertContextualPanel: ContextualPanelPresenting {
    struct Presentation {
        let select: (UUID) -> Void
        let content: () -> Void
        let selection: () -> Void
    }
    var onRequestActions: (() -> Void)?, onRequestMap: (() -> Void)?, onClose: (() -> Void)?
    var presentations: [Presentation] = []
    var closes = 0
    func handle(_ event: InputEventDescriptor) -> Bool { false }
    func show(appName: String, items: [ContextualActionItem], isMap: Bool, onSelect: @escaping (UUID) -> Void,
              onContent: @escaping () -> Void, onSelection: @escaping () -> Void) {
        presentations.append(Presentation(select: onSelect, content: onContent, selection: onSelection))
    }
    func close(notifyOwner: Bool) { closes += 1; if notifyOwner { onClose?() } }
}
