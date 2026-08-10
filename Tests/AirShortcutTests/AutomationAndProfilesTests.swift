import Foundation
import XCTest
@testable import AirShortcut

final class AutomationAndProfilesTests: XCTestCase {
    @MainActor
    func testAutomationCoordinatorExecutesMatchedRuleOnceAndPersistsFeedback() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AirShortcut-automation-coordinator-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let shortcutStore = ShortcutStore(
            fileURL: directory.appendingPathComponent("rules.json"),
            seedExamples: false
        )
        let eventLogStore = EventLogStore(
            fileURL: directory.appendingPathComponent("events.json")
        )
        let metricsStore = MetricsStore(
            fileURL: directory.appendingPathComponent("metrics.json")
        )
        let notification = NotificationSpy()
        let rule = ShortcutRule(
            name: "Coordenada",
            trigger: .keyboard(keyCode: 12, modifiers: [.command]),
            action: .notification(title: "Tico", body: "Executada")
        )
        try shortcutStore.add(rule)

        let coordinator = AutomationCoordinator(
            shortcutStore: shortcutStore,
            eventLogStore: eventLogStore,
            metricsStore: metricsStore,
            actionRunner: ActionRunner(notificationService: notification),
            contextSnapshotService: FixedContextSnapshotService(),
            setContinuousPhasesEnabled: { _ in }
        )
        coordinator.handle(
            event: .keyboard(
                keyCode: 12,
                modifiers: [.command],
                timestamp: Date(timeIntervalSince1970: 100)
            ),
            modifiers: [.command]
        )

        for _ in 0..<50 where eventLogStore.entries.isEmpty {
            await Task.yield()
        }

        XCTAssertEqual(notification.titles, ["Tico"])
        XCTAssertEqual(eventLogStore.entries.count, 1)
        XCTAssertEqual(metricsStore.events.count, 1)
        coordinator.stop()
    }

    func testWorkflowStopsOrContinuesAccordingToFailurePolicy() async {
        let launcher = SelectiveURLLauncher()
        let actionRunner = ActionRunner(urlLauncher: launcher)
        let executor = WorkflowExecutor(actionRunner: actionRunner)
        let steps = [
            WorkflowStep(action: .openURL(url: URL(string: "https://example.com/fail")!)),
            WorkflowStep(action: .openURL(url: URL(string: "https://example.com/success")!))
        ]

        let stopped = await executor.execute(
            ActionWorkflow(steps: steps, failurePolicy: .stop)
        )
        XCTAssertEqual(stopped.stepExecutions.count, 1)
        XCTAssertFalse(stopped.success)

        launcher.urls.removeAll()
        let continued = await executor.execute(
            ActionWorkflow(steps: steps, failurePolicy: .continueRemaining)
        )
        XCTAssertEqual(continued.stepExecutions.count, 2)
        XCTAssertFalse(continued.success)
        XCTAssertEqual(launcher.urls.count, 2)
    }

    func testWorkflowCancellationStopsDuringDelay() async {
        let executor = WorkflowExecutor()
        let workflow = ActionWorkflow(steps: [
            WorkflowStep(
                action: .notification(title: "Não executar", body: ""),
                delayBefore: 30
            )
        ])
        let task = Task { await executor.execute(workflow) }
        task.cancel()

        let report = await task.value

        XCTAssertTrue(report.wasCancelled)
        XCTAssertTrue(report.stepExecutions.isEmpty)
    }

    func testNewAutomationActionsRouteToDedicatedServices() async {
        let appleScript = AppleScriptSpy()
        let shortcuts = MacOSShortcutSpy()
        let input = InputActionSpy()
        let runner = ActionRunner(
            appleScriptRunner: appleScript,
            macOSShortcutRunner: shortcuts,
            inputActionService: input
        )

        let appleResult = await runner.execute(
            .appleScript(source: "return \"ok\""),
            scriptApproval: { $0 == "return \"ok\"" }
        )
        let shortcutResult = await runner.execute(
            .macOSShortcut(name: "Foco", input: "texto")
        )
        let keyboardResult = await runner.execute(
            .keyboardShortcut(keyCode: 49, modifiers: [.command])
        )
        let clipboardResult = await runner.execute(.setClipboard(text: "copiado"))

        XCTAssertTrue(appleResult.success)
        XCTAssertTrue(shortcutResult.success)
        XCTAssertTrue(keyboardResult.success)
        XCTAssertTrue(clipboardResult.success)
        XCTAssertEqual(appleScript.sources, ["return \"ok\""])
        XCTAssertEqual(shortcuts.invocations, [.init(name: "Foco", input: "texto")])
        XCTAssertEqual(input.shortcuts, [.init(keyCode: 49, modifiers: [.command])])
        XCTAssertEqual(input.clipboardValues, ["copiado"])
    }

    func testVersionSixPersistsProfilesWorkflowsTemplatesAndPresets() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AirShortcut-v6-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("shortcuts.json")
        let store = ShortcutStore(fileURL: url, seedExamples: false)
        let profile = ShortcutProfile(
            name: "Design",
            applicationBundleIdentifiers: ["com.apple.Preview"],
            conditions: [.windowTitle(RuleTextMatcher(value: "PDF"))],
            priority: 3
        )
        try store.addProfile(profile)
        let workflow = ActionWorkflow(
            name: "Preparar",
            steps: [
                WorkflowStep(action: .setClipboard(text: "ok")),
                WorkflowStep(action: .macOSShortcut(name: "Foco", input: nil))
            ]
        )
        try store.saveReusableWorkflow(workflow)
        let template = makeTemplate(name: "L")
        try store.saveCustomGestureTemplate(template)
        let preset = GesturePreset(
            name: "Meu preset",
            trigger: .customTrackpad(template: template),
            workflow: workflow,
            profileID: profile.id,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        try store.savePreset(preset)
        let rule = ShortcutRule(
            name: "Regra v6",
            trigger: .customTrackpad(template: template),
            action: .setClipboard(text: "legacy"),
            workflow: workflow,
            profileID: profile.id,
            conditions: [.modifiers([.command])],
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        try store.add(rule)

        let reloaded = ShortcutStore(fileURL: url, seedExamples: false)

        XCTAssertEqual(reloaded.rules, [rule])
        XCTAssertEqual(reloaded.profiles, [profile])
        XCTAssertEqual(reloaded.reusableWorkflows, [workflow])
        XCTAssertEqual(reloaded.customGestureTemplates, [template])
        XCTAssertEqual(reloaded.presets, [preset])
    }

    func testVersionFiveSingleActionMigratesToWorkflowAndCreatesBackup() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AirShortcut-v5-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("shortcuts.json")
        let rule = ShortcutRule(
            name: "Legada",
            trigger: .keyboard(keyCode: 1, modifiers: [.command]),
            action: .notification(title: "Oi", body: "")
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        var ruleJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoder.encode(rule)) as? [String: Any]
        )
        ruleJSON.removeValue(forKey: "workflow")
        ruleJSON.removeValue(forKey: "profileID")
        ruleJSON.removeValue(forKey: "conditions")
        let document: [String: Any] = ["version": 5, "rules": [ruleJSON]]
        try JSONSerialization.data(withJSONObject: document).write(to: url)

        let store = ShortcutStore(fileURL: url, seedExamples: false)

        XCTAssertEqual(store.rules.first?.workflow.steps.count, 1)
        XCTAssertEqual(store.rules.first?.action, rule.action)
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("shortcuts.v5.backup.json").path
        ))
    }

    func testProfileAndConditionsFilterAndPrioritizeRules() {
        let profile = ShortcutProfile(
            name: "Preview PDFs",
            applicationBundleIdentifiers: ["com.apple.Preview"],
            conditions: [.windowTitle(RuleTextMatcher(value: "PDF"))],
            priority: 4
        )
        let trigger = TriggerDefinition.keyboard(keyCode: 49, modifiers: [.command])
        let global = ShortcutRule(
            name: "Global",
            trigger: trigger,
            action: .notification(title: "Global", body: "")
        )
        let contextual = ShortcutRule(
            name: "Contextual",
            trigger: trigger,
            action: .notification(title: "Contextual", body: ""),
            profileID: profile.id,
            conditions: [.modifiers([.command])]
        )
        let context = ContextSnapshot(
            frontmostApplicationBundleIdentifier: "com.apple.Preview",
            frontmostWindowTitle: "Relatório PDF",
            modifiers: [.command]
        )

        let matches = TriggerMatcher().matchingRules(
            in: [global, contextual],
            for: .keyboard(keyCode: 49, modifiers: [.command]),
            context: context,
            profiles: [profile]
        )

        XCTAssertEqual(matches.map(\.name), ["Contextual", "Global"])
        var wrongTitle = context
        wrongTitle.frontmostWindowTitle = "Imagem"
        XCTAssertFalse(contextual.matches(wrongTitle, profiles: [profile]))
    }

    func testPressureRangeAndDeviceFallbackAreMatched() {
        let spec = TrackpadTriggerSpec(
            gesture: .swipeRight,
            fingerCount: 3...3,
            pressureRange: 0.3...0.7,
            deviceScope: .device(id: "magic"),
            allowsDeviceFallback: true
        )
        let matching = gestureDescriptor(pressure: 0.5, deviceID: "magic")
        let fallback = gestureDescriptor(pressure: 0.5, deviceID: nil)
        let tooLight = gestureDescriptor(pressure: 0.1, deviceID: "magic")

        XCTAssertTrue(TriggerMatcher().matches(.trackpad(spec: spec), event: matching))
        XCTAssertTrue(TriggerMatcher().matches(.trackpad(spec: spec), event: fallback))
        XCTAssertFalse(TriggerMatcher().matches(.trackpad(spec: spec), event: tooLight))
    }

    func testContinuousPhasesAreOptInAndEndDeterministically() {
        var engine = AdvancedGestureEngine(
            configuration: GestureRecognizerConfiguration(emitsContinuousPhases: true)
        )
        let start = Date(timeIntervalSince1970: 100)
        let initial = touches(offset: 0)
        let outputs = [
            engine.process(frame(at: start, number: 1, touches: initial)).event,
            engine.process(frame(
                at: start.addingTimeInterval(0.15),
                number: 2,
                touches: touches(offset: 0.2)
            )).event,
            engine.process(frame(
                at: start.addingTimeInterval(0.25),
                number: 3,
                touches: touches(offset: 0.32)
            )).event,
            engine.process(frame(
                at: start.addingTimeInterval(0.3),
                number: 4,
                touches: []
            )).event
        ].compactMap { $0 }

        XCTAssertEqual(outputs.map(\.phase), [.began, .changed, .ended])
        XCTAssertEqual(Set(outputs.map(\.sessionID)).count, 1)
        XCTAssertTrue(outputs.allSatisfy { $0.kind == .swipeRight })
        XCTAssertGreaterThan(outputs[1].progress ?? 0, outputs[0].progress ?? 0)
    }

    func testCustomGestureRecognizerRejectsAmbiguousTemplates() throws {
        let first = makeTemplate(name: "Primeiro")
        var duplicate = first
        duplicate.id = UUID()
        duplicate.name = "Duplicado"
        let candidate = try XCTUnwrap(first.samplePaths.first)

        XCTAssertNil(CustomGesturePath.recognize(
            candidate,
            fingerCount: 3,
            templates: [first, duplicate]
        ))
        let recognition = try XCTUnwrap(CustomGesturePath.recognize(
            candidate,
            fingerCount: 3,
            templates: [first]
        ))
        XCTAssertEqual(recognition.templateID, first.id)
        XCTAssertGreaterThan(recognition.confidence, 0.9)
    }

    func testMetricsAreBoundedAndExportable() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AirShortcut-metrics-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MetricsStore(
            fileURL: directory.appendingPathComponent("metrics.json"),
            maximumEventCount: 10
        )
        for index in 0..<12 {
            store.record(GestureMetricEvent(
                ruleName: "Regra \(index)",
                outcome: index.isMultiple(of: 2) ? .success : .failure,
                confidence: 0.8,
                latency: 0.01
            ))
        }
        let csvURL = directory.appendingPathComponent("metrics.csv")
        try store.exportCSV(to: csvURL)

        XCTAssertEqual(store.events.count, 10)
        XCTAssertEqual(store.summary.successes, 5)
        XCTAssertTrue(
            String(decoding: try Data(contentsOf: csvURL), as: UTF8.self)
                .contains("latency_ms")
        )
    }

    private func makeTemplate(name: String) -> CustomGestureTemplate {
        let base = [
            TrackpadPoint(x: 0, y: 0),
            TrackpadPoint(x: 0, y: 1),
            TrackpadPoint(x: 1, y: 1)
        ]
        let normalized = CustomGesturePath.normalized(
            base,
            pointCount: CustomGestureTemplate.defaultPointCount
        )!
        return CustomGestureTemplate(
            name: name,
            fingerCount: 3...3,
            samplePaths: [normalized, normalized, normalized],
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }

    private func gestureDescriptor(
        pressure: Double,
        deviceID: String?
    ) -> InputEventDescriptor {
        .trackpad(GestureEvent(
            sessionID: UUID(),
            kind: .swipeRight,
            phase: .ended,
            fingerCount: 3,
            deviceID: deviceID,
            startRegion: .any,
            endRegion: .any,
            pressure: pressure,
            confidence: 0.9,
            occurredAt: Date()
        ))
    }

    private func touches(offset: Double) -> [RawTrackpadTouch] {
        [0.3, 0.4, 0.5].enumerated().map { index, x in
            RawTrackpadTouch(
                identifier: Int32(index + 1),
                state: 4,
                position: TrackpadPoint(x: x + offset, y: 0.5),
                velocity: TrackpadPoint(x: 0, y: 0),
                pressure: 0.5
            )
        }
    }

    private func frame(
        at date: Date,
        number: Int32,
        touches: [RawTrackpadTouch]
    ) -> RawTrackpadFrame {
        RawTrackpadFrame(
            touches: touches,
            deviceTimestamp: date.timeIntervalSince1970,
            frameNumber: number,
            receivedAt: date,
            deviceID: "magic"
        )
    }
}

private enum AutomationTestError: LocalizedError {
    case expected
    var errorDescription: String? { "Falha esperada" }
}

private final class SelectiveURLLauncher: URLLaunching {
    var urls: [URL] = []

    func open(_ url: URL) throws {
        urls.append(url)
        if url.path.contains("fail") {
            throw AutomationTestError.expected
        }
    }
}

private final class AppleScriptSpy: AppleScriptRunning {
    var sources: [String] = []

    func run(
        source: String,
        approved: Bool,
        timeout: TimeInterval
    ) async throws -> String {
        sources.append(source)
        return "ok"
    }
}

private struct ShortcutInvocation: Equatable {
    var name: String
    var input: String?
}

private final class MacOSShortcutSpy: MacOSShortcutRunning {
    var invocations: [ShortcutInvocation] = []

    func run(name: String, input: String?, timeout: TimeInterval) async throws -> String {
        invocations.append(.init(name: name, input: input))
        return "ok"
    }

    func list() async throws -> [String] {
        ["Foco"]
    }
}

private struct KeyboardInvocation: Equatable {
    var keyCode: UInt16
    var modifiers: Set<InputModifier>
}

private final class InputActionSpy: InputActionPerforming {
    var shortcuts: [KeyboardInvocation] = []
    var clipboardValues: [String] = []

    func sendKeyboardShortcut(keyCode: UInt16, modifiers: Set<InputModifier>) throws {
        shortcuts.append(.init(keyCode: keyCode, modifiers: modifiers))
    }

    func setClipboard(_ text: String) throws {
        clipboardValues.append(text)
    }
}

@MainActor
private final class FixedContextSnapshotService: ContextSnapshotProviding {
    func snapshot(modifiers: Set<InputModifier>, at date: Date) -> ContextSnapshot {
        ContextSnapshot(modifiers: modifiers, capturedAt: date)
    }
}

private final class NotificationSpy: NotificationDelivering {
    var titles: [String] = []

    func deliver(title: String, body: String) async throws {
        titles.append(title)
    }
}
