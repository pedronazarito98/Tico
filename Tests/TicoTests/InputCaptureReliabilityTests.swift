import AppKit
import XCTest
@testable import Tico

final class InputCaptureReliabilityTests: XCTestCase {
    // CAP-01.A/B: o fluxo entra pela normalização real, incluindo flagsChanged.
    func testCommandSequenceSurvivesReleaseAndUnrelatedFlagsButNotWrongKey() throws {
        let rule = sequenceRule([.keyboard(keyCode: 40, modifiers: [.command]),
                                 .keyboard(keyCode: 8, modifiers: [.command])])
        for release in [false, true] {
            var runtime = TriggerSequenceRuntime()
            let first = try input(.keyDown, key: 40, flags: .maskCommand)
            XCTAssertTrue(runtime.process(input: first, rules: [rule], context: context).matchedRules.isEmpty)
            if release {
                for flags: CGEventFlags in [[], .maskShift, [], .maskCommand] {
                    let change = try input(.flagsChanged, key: 55, flags: flags)
                    XCTAssertTrue(runtime.process(input: change, rules: [rule], context: context).matchedRules.isEmpty)
                    XCTAssertTrue(runtime.hasProgress)
                }
            }
            let second = try input(.keyDown, key: 8, flags: .maskCommand)
            XCTAssertEqual(runtime.process(input: second, rules: [rule], context: context).matchedRules.map(\.id), [rule.id])
            XCTAssertFalse(runtime.hasProgress)
        }
        var runtime = TriggerSequenceRuntime()
        _ = runtime.process(input: try input(.keyDown, key: 40, flags: .maskCommand), rules: [rule], context: context)
        _ = runtime.process(input: try input(.keyDown, key: 1, flags: .maskCommand), rules: [rule], context: context)
        XCTAssertFalse(runtime.hasProgress)
        XCTAssertTrue(runtime.process(input: try input(.keyDown, key: 8, flags: .maskCommand), rules: [rule], context: context).matchedRules.isEmpty)
    }

    // CAP-01.C: regras legadas explícitas permanecem, sem cancelar outras sequências.
    func testExplicitModifierRulesAndStepsRemainEligible() throws {
        let ordinary = sequenceRule([.keyboard(keyCode: 40, modifiers: [.command]), .keyboard(keyCode: 8, modifiers: [.command])])
        let explicit = sequenceRule([.keyboard(keyCode: 55, modifiers: [.command]), .keyboard(keyCode: 8, modifiers: [.command])])
        let modifier = ShortcutRule(name: "Modificador", trigger: .keyboard(keyCode: 55, modifiers: [.command]), action: .notification(title: "", body: ""))
        let rules = [ordinary, explicit, modifier]
        var runtime = TriggerSequenceRuntime()
        _ = runtime.process(input: try input(.keyDown, key: 40, flags: .maskCommand), rules: rules, context: context)
        let changed = try input(.flagsChanged, key: 55, flags: .maskCommand)
        XCTAssertEqual(runtime.process(input: changed, rules: rules, context: context).matchedRules.map(\.id), [modifier.id])
        let completed = runtime.process(input: try input(.keyDown, key: 8, flags: .maskCommand), rules: rules, context: context)
        XCTAssertEqual(Set(completed.matchedRules.map(\.id)), Set([ordinary.id, explicit.id]))
        XCTAssertEqual(changed.modifiers, [.command])
    }

    @MainActor
    func testLocalModifierChangesUpdateStateWithoutRecordingAnActivation() throws {
        let local = LocalInputCaptureService()
        var received: [CapturedInput] = []
        let event = try XCTUnwrap(NSEvent(cgEvent: keyboard(.flagsChanged, key: 55, flags: .maskCommand)))
        local.consume(event, onInput: { received.append($0) }, onCancel: {})
        XCTAssertEqual(local.modifiers, [.command])
        XCTAssertEqual(local.pressedKeys, [55])
        XCTAssertEqual(received.count, 1)
        guard case let .modifierChange(change) = received[0] else { return XCTFail("flagsChanged deve conservar seu tipo") }
        XCTAssertEqual(change.keyCode, 55)
        XCTAssertEqual(change.modifiers, [.command])
        let practice = GesturePracticeSession()
        _ = practice.begin(sequenceRule([.keyboard(keyCode: 40, modifiers: [.command]), .keyboard(keyCode: 8, modifiers: [.command])]))
        practice.receive(try input(.keyDown, key: 40, flags: .maskCommand))
        practice.receive(received[0])
        practice.receive(try input(.keyDown, key: 8, flags: .maskCommand))
        XCTAssertEqual(practice.completedCount, 1)
    }

    @MainActor
    func testReservedPanelAndMapShortcutsKeepCodeAndFlags() async throws {
        let panel = ContextualPanelService()
        var actions = 0
        var maps = 0
        panel.onRequestActions = { actions += 1 }
        panel.onRequestMap = { maps += 1 }
        let shortcut = try input(.keyDown, key: 49, flags: [.maskCommand, .maskAlternate, .maskControl])
        XCTAssertTrue(panel.handle(try XCTUnwrap(shortcut.event)))
        XCTAssertEqual(actions, 1)
        let held = try input(.flagsChanged, key: 58, flags: [.maskCommand, .maskAlternate])
        XCTAssertTrue(panel.handle(try XCTUnwrap(held.event)))
        try await Task.sleep(for: .milliseconds(500))
        XCTAssertEqual(maps, 1)
        panel.close()
    }

    // CAP-02.B/C/D: duas pressões próximas são duas intenções; repeat não é.
    @MainActor
    func testRepeatsAndQuickPressesAgreeBetweenLocalCapturePracticeAndGlobal() throws {
        let rule = ShortcutRule(name: "A", trigger: .keyboard(keyCode: 0, modifiers: []), action: .notification(title: "", body: ""))
        let practice = GesturePracticeSession()
        _ = practice.begin(rule, repetitionLimit: nil)
        let local = LocalInputCaptureService()
        var global: [CapturedInput] = []
        var localActivations: [InputEventDescriptor] = []
        let down = try keyboard(.keyDown, key: 0, flags: [])
        let repeated = try keyboard(.keyDown, key: 0, flags: [])
        repeated.setIntegerValueField(.keyboardEventAutorepeat, value: 1)
        let up = try keyboard(.keyUp, key: 0, flags: [])
        for event in [down] + Array(repeating: repeated, count: 20) + [up, down, up] {
            if let input = GlobalEventTapService.normalizeInput(type: event.type, event: event) { global.append(input) }
            local.consume(try XCTUnwrap(NSEvent(cgEvent: event)), onInput: { input in
                if case let .activation(event) = input { localActivations.append(event) }
                practice.receive(input)
            }, onCancel: {})
        }
        XCTAssertEqual(global.count, 2)
        XCTAssertEqual(global.compactMap(\.event).map(\.keyCode), [0, 0])
        XCTAssertEqual(localActivations.map(\.keyCode), [0, 0])
        XCTAssertEqual(practice.completedCount, 2)

        var runtime = TriggerSequenceRuntime()
        let sequence = sequenceRule([.keyboard(keyCode: 0, modifiers: []), .keyboard(keyCode: 0, modifiers: [])])
        XCTAssertTrue(runtime.process(input: try input(.keyDown, key: 0, flags: []), rules: [sequence], context: context).matchedRules.isEmpty)
        if let repeatInput = GlobalEventTapService.normalizeInput(type: .keyDown, event: repeated) {
            XCTAssertTrue(runtime.process(input: repeatInput, rules: [sequence], context: context).matchedRules.isEmpty)
        }
        XCTAssertTrue(runtime.hasProgress)
        XCTAssertEqual(runtime.process(input: try input(.keyDown, key: 0, flags: []), rules: [sequence], context: context).matchedRules.map(\.id), [sequence.id])

        let mouseRule = ShortcutRule(name: "Mouse", trigger: .mouseButton(button: 3, modifiers: []), action: .notification(title: "", body: ""))
        _ = practice.begin(mouseRule, repetitionLimit: nil)
        practice.receive(InputEventDescriptor.mouseButton(3, timestamp: Date(timeIntervalSince1970: 100)))
        practice.receive(InputEventDescriptor.mouseButton(3, timestamp: Date(timeIntervalSince1970: 100.001)))
        XCTAssertEqual(practice.completedCount, 2)
    }

    // CAP-02.A: observa cancelamento do efeito em voo, não só contagem de chamadas.
    @MainActor
    func testAutorepeatDoesNotCancelOrRestartRunningWorkflow() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let rules = ShortcutStore(fileURL: directory.appendingPathComponent("rules.json"), seedExamples: false)
        let log = EventLogStore(fileURL: directory.appendingPathComponent("events.json"))
        let metrics = MetricsStore(fileURL: directory.appendingPathComponent("metrics.json"))
        let rule = ShortcutRule(name: "Uma pressão", trigger: .keyboard(keyCode: 0, modifiers: []), action: .notification(title: "Uma", body: ""))
        try rules.add(rule)
        let effect = HeldCaptureNotification()
        let coordinator = AutomationCoordinator(shortcutStore: rules, eventLogStore: log, metricsStore: metrics,
            actionRunner: ActionRunner(notificationService: effect), contextSnapshotService: CaptureTestContext(), setContinuousPhasesEnabled: { _ in })
        let down = try keyboard(.keyDown, key: 0, flags: [])
        if let event = GlobalEventTapService.normalizeInput(type: .keyDown, event: down)?.event {
            coordinator.handle(event: event, modifiers: [])
        }
        for _ in 0..<100 where effect.titles.isEmpty { await Task.yield() }
        XCTAssertEqual(effect.titles, ["Uma"])
        down.setIntegerValueField(.keyboardEventAutorepeat, value: 1)
        for _ in 0..<20 {
            if let event = GlobalEventTapService.normalizeInput(type: .keyDown, event: down)?.event {
                coordinator.handle(event: event, modifiers: [])
            }
        }
        effect.release()
        for _ in 0..<100 where coordinator.lastWorkflowReport == nil { await Task.yield() }
        XCTAssertEqual(effect.wasCancelled, [false])
        XCTAssertEqual(effect.titles, ["Uma"])
        XCTAssertEqual(coordinator.lastWorkflowReport?.wasCancelled, false)
        try await coordinator.flushFeedback()
        XCTAssertEqual(log.entries.count, 1)
        XCTAssertEqual(metrics.events.map(\.outcome), [.success])
        coordinator.stop()
        effect.release()
    }

    // CAP-03.A/B/C: produção real dos eventos, com postagem substituída.
    @MainActor
    func testOwnEventsAreMarkedAsPairAndIgnoredBeforeLocalStateChanges() throws {
        var emitted: [CGEvent] = []
        let sender = InputActionService(postEvent: { emitted.append($0) })
        try sender.sendKeyboardShortcut(keyCode: 40, modifiers: [.command])
        XCTAssertEqual(emitted.map(\.type), [.keyDown, .keyUp])
        XCTAssertEqual(emitted.map { $0.getIntegerValueField(.keyboardEventKeycode) }, [40, 40])
        XCTAssertTrue(emitted.allSatisfy { $0.flags == .maskCommand })
        let marks = emitted.map { $0.getIntegerValueField(.eventSourceUserData) }
        XCTAssertNotEqual(marks[0], 0)
        XCTAssertEqual(marks[0], marks[1])
        var secondPair: [CGEvent] = []
        try InputActionService(postEvent: { secondPair.append($0) }).sendKeyboardShortcut(keyCode: 0, modifiers: [])
        XCTAssertTrue(secondPair.allSatisfy { $0.getIntegerValueField(.eventSourceUserData) == marks[0] })
        // Quartz usa flagsChanged para virtualKey de modificador. A origem
        // deve permanecer nos dois eventos, sem forçar seu tipo nativo.
        var modifierPair: [CGEvent] = []
        try InputActionService(postEvent: { modifierPair.append($0) }).sendKeyboardShortcut(keyCode: 55, modifiers: [.command])
        XCTAssertEqual(modifierPair.count, 2)
        XCTAssertTrue(modifierPair.allSatisfy { $0.getIntegerValueField(.eventSourceUserData) == marks[0] })
        XCTAssertTrue(modifierPair.allSatisfy { GlobalEventTapService.normalizeInput(type: $0.type, event: $0) == nil })

        let local = LocalInputCaptureService()
        var received: [CapturedInput] = []
        var cancelled = false
        local.consume(try XCTUnwrap(NSEvent(cgEvent: keyboard(.keyDown, key: 0, flags: []))), onInput: { received.append($0) }, onCancel: {})
        received.removeAll()
        emitted[0].type = .flagsChanged
        try sender.sendKeyboardShortcut(keyCode: 53, modifiers: [.command])
        for event in emitted + secondPair {
            XCTAssertNil(GlobalEventTapService.normalizeInput(type: event.type, event: event))
            XCTAssertFalse(local.consume(try XCTUnwrap(NSEvent(cgEvent: event)), onInput: { received.append($0) }, onCancel: { cancelled = true }))
        }
        XCTAssertTrue(received.isEmpty)
        XCTAssertFalse(cancelled)
        XCTAssertEqual(local.modifiers, [])
        XCTAssertEqual(local.pressedKeys, [0])
        let external = try keyboard(.keyDown, key: 8, flags: .maskShift)
        XCTAssertEqual(GlobalEventTapService.normalizeInput(type: .keyDown, event: external)?.event?.keyCode, 8)
        external.setIntegerValueField(.eventSourceUserData, value: marks[0] ^ 1)
        XCTAssertEqual(GlobalEventTapService.normalizeInput(type: .keyDown, event: external)?.event?.modifiers, [.shift])
        local.consume(try XCTUnwrap(NSEvent(cgEvent: keyboard(.keyUp, key: 0, flags: []))), onInput: { _ in }, onCancel: {})
        XCTAssertTrue(local.consume(try XCTUnwrap(NSEvent(cgEvent: external)), onInput: { received.append($0) }, onCancel: {}))
        XCTAssertEqual(received.compactMap(\.event).map(\.keyCode), [8])
        XCTAssertEqual(local.modifiers, [.shift])
    }

    // CAP-03.D: ciclos só passam pelo emissor, normalizador e runtime em memória.
    func testOwnShortcutCannotRecursivelyTriggerItselfOrAnotherRule() throws {
        for crossRule in [false, true] {
            let a = ShortcutRule(name: "A", trigger: .keyboard(keyCode: 0, modifiers: []), action: .keyboardShortcut(keyCode: crossRule ? 8 : 0, modifiers: []))
            let b = ShortcutRule(name: "B", trigger: .keyboard(keyCode: 8, modifiers: []), action: .keyboardShortcut(keyCode: 0, modifiers: []))
            var pending = [try input(.keyDown, key: 0, flags: [])]
            var executed: [String] = []
            var runtime = TriggerSequenceRuntime()
            let sender = InputActionService(postEvent: { event in
                if let input = GlobalEventTapService.normalizeInput(type: event.type, event: event) { pending.append(input) }
            })
            while !pending.isEmpty && executed.count < 10 {
                let input = pending.removeFirst()
                for rule in runtime.process(input: input, rules: [a, b], context: context).matchedRules {
                    executed.append(rule.name)
                    if case let .keyboardShortcut(keyCode, modifiers) = rule.action {
                        try sender.sendKeyboardShortcut(keyCode: keyCode, modifiers: modifiers)
                    }
                }
            }
            XCTAssertEqual(executed, ["A"])
            XCTAssertTrue(pending.isEmpty)
        }
    }

    // CAP-01.D: exerce o encerramento real da gravação e observa o contexto seguinte.
    @MainActor
    func testEndingLocalRecordingResynchronizesModifiersUsedByFollowingContext() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let suite = "InputCaptureReliabilityTests.\(UUID().uuidString)"
        defer {
            try? FileManager.default.removeItem(at: directory)
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let validation = TrackpadValidationStore(defaults: defaults, storageKey: "validation")
        var flags: Set<InputModifier> = [.command]
        let controller = AppController(
            shortcutStore: ShortcutStore(fileURL: directory.appendingPathComponent("rules.json"), seedExamples: false),
            settings: AppSettingsStore(defaults: defaults),
            eventLogStore: EventLogStore(fileURL: directory.appendingPathComponent("events.json")),
            permissions: PermissionCoordinator(accessibilityCheck: { false }, inputMonitoringCheck: { .denied }, settingsOpener: { _ in }),
            calibrationStore: TrackpadCalibrationStore(defaults: defaults, storageKey: "calibration"),
            validationStore: validation,
            metricsStore: MetricsStore(fileURL: directory.appendingPathComponent("metrics.json")),
            capabilityStore: TrackpadCapabilityStore(defaults: defaults, storageKey: "capabilities"),
            trackpadGestures: TrackpadGestureService(validationStore: validation),
            approvalStore: AutomationApprovalStore(defaults: defaults, storageKey: "approval"),
            contextSnapshotService: CaptureTestContext(), macOSShortcutCatalog: CaptureShortcutCatalog(),
            readModifiers: { flags })
        XCTAssertTrue(controller.beginLocalRecording())
        flags = [.option]
        controller.endRecording()
        let observer = UUID()
        controller.beginRuleContextObservation(id: observer)
        XCTAssertFalse(controller.recordingIsActive)
        XCTAssertEqual(controller.currentContextSnapshot?.modifiers, [.option])
        controller.endRuleContextObservation(id: observer)
    }

    private var context: ContextSnapshot { ContextSnapshot(capturedAt: Date(timeIntervalSince1970: 100)) }

    private func sequenceRule(_ steps: [TriggerStep]) -> ShortcutRule {
        ShortcutRule(name: "Sequência", trigger: .sequence(TriggerSequence(steps: steps)), action: .notification(title: "", body: ""))
    }

    private func keyboard(_ type: CGEventType, key: UInt16, flags: CGEventFlags) throws -> CGEvent {
        let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: type != .keyUp))
        event.type = type
        event.flags = flags
        return event
    }

    private func input(_ type: CGEventType, key: UInt16, flags: CGEventFlags) throws -> CapturedInput {
        try XCTUnwrap(GlobalEventTapService.normalizeInput(type: type, event: keyboard(type, key: key, flags: flags), timestamp: Date(timeIntervalSince1970: 100)))
    }
}

@MainActor
private final class HeldCaptureNotification: NotificationDelivering {
    var titles: [String] = []
    var wasCancelled: [Bool] = []
    private var continuation: CheckedContinuation<Void, Never>?
    func deliver(title: String, body: String) async throws {
        titles.append(title)
        await withCheckedContinuation { continuation = $0 }
        wasCancelled.append(Task.isCancelled)
    }
    func release() { continuation?.resume(); continuation = nil }
}

@MainActor
private final class CaptureTestContext: ContextSnapshotProviding {
    func snapshot(modifiers: Set<InputModifier>, at date: Date) -> ContextSnapshot {
        ContextSnapshot(modifiers: modifiers, capturedAt: date)
    }
}

private struct CaptureShortcutCatalog: MacOSShortcutRunning {
    func list() async throws -> [String] { [] }
    func run(name: String, input: String?, timeout: TimeInterval) async throws -> String {
        XCTFail("A validação de captura não pode executar Atalhos")
        return ""
    }
}
