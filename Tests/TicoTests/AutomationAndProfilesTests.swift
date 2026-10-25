import Foundation
import XCTest
@testable import Tico

final class AutomationAndProfilesTests: XCTestCase {
    @MainActor
    func testAutomationCoordinatorExecutesMatchedRuleOnceAndPersistsFeedback() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Tico-automation-coordinator-\(UUID().uuidString)", isDirectory: true)
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

    @MainActor
    func testCancellingWorkflowResolvesPendingScriptApprovalWithoutExecutingIt() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Tico-automation-cancel-(UUID().uuidString)", isDirectory: true)
        let suiteName = "AutomationAndProfilesTests-(UUID().uuidString)"
        defer {
            try? FileManager.default.removeItem(at: directory)
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }

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
        let scriptRunner = ShellScriptSpy()
        let rule = ShortcutRule(
            name: "Script cancelável",
            trigger: .keyboard(keyCode: 12, modifiers: [.command]),
            action: .shellScript(command: "echo não deve executar")
        )
        try shortcutStore.add(rule)

        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let coordinator = AutomationCoordinator(
            shortcutStore: shortcutStore,
            eventLogStore: eventLogStore,
            metricsStore: metricsStore,
            actionRunner: ActionRunner(shellScriptRunner: scriptRunner),
            approvalStore: AutomationApprovalStore(
                defaults: defaults,
                storageKey: "approved"
            ),
            contextSnapshotService: FixedContextSnapshotService(),
            setContinuousPhasesEnabled: { _ in }
        )

        coordinator.handle(
            event: .keyboard(
                keyCode: 12,
                modifiers: [.command],
                timestamp: Date(timeIntervalSince1970: 101)
            ),
            modifiers: [.command]
        )

        for _ in 0..<100 where coordinator.pendingScriptApproval == nil {
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTAssertEqual(coordinator.pendingScriptApproval?.ruleName, rule.name)

        coordinator.cancelWorkflow(ruleID: rule.id)

        for _ in 0..<100 where coordinator.pendingScriptApproval != nil {
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTAssertNil(coordinator.pendingScriptApproval)
        XCTAssertTrue(scriptRunner.commands.isEmpty)
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

    func testLegacyContextMigratesWithoutLosingWorkflowsTemplatesOrPresets() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Tico-v6-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("shortcuts.json")
        let store = ShortcutStore(fileURL: url, seedExamples: false)
        let profileID = UUID()
        let inherited: [RuleCondition] = [.windowTitle(RuleTextMatcher(value: "PDF"))]
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
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        try store.savePreset(preset)
        let rule = ShortcutRule(
            name: "Regra v6",
            trigger: .customTrackpad(template: template),
            action: .setClipboard(text: "legacy"),
            workflow: workflow,
            conditions: [.modifiers([.command])],
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        try store.add(rule)

        // O payload é construído no diretório temporário deste teste existente;
        // nenhuma instalação ou configuração real é usada na migração.
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let profile: [String: Any] = [
            "id": profileID.uuidString, "name": "Design", "isEnabled": true,
            "applicationBundleIdentifiers": ["com.apple.Preview"], "priority": 3,
            "conditions": try JSONSerialization.jsonObject(with: encoder.encode(inherited))
        ]
        legacy["version"] = 7
        legacy["profiles"] = [profile]
        for key in ["rules", "presets"] {
            var values = try XCTUnwrap(legacy[key] as? [[String: Any]])
            values[0]["profileID"] = profileID.uuidString
            legacy[key] = values
        }
        let original = try JSONSerialization.data(withJSONObject: legacy)
        try original.write(to: url)
        let reloaded = ShortcutStore(fileURL: url, seedExamples: false)
        var expected = rule
        expected.isEnabled = false
        expected.conditions += inherited + [.application(bundleIdentifiers: ["com.apple.Preview"])]
        expected.priority = 3
        expected.notes = "Migração: condições herdadas incorporadas ao atalho. Revise antes de ativar."
        var expectedPreset = preset
        expectedPreset.conditions = inherited + [.application(bundleIdentifiers: ["com.apple.Preview"])]
        expectedPreset.priority = 3

        XCTAssertNil(reloaded.lastError)
        XCTAssertEqual(reloaded.rules, [expected])
        XCTAssertEqual(reloaded.rules.first?.conditions, expected.conditions)
        XCTAssertEqual(reloaded.reusableWorkflows, [workflow])
        XCTAssertEqual(reloaded.customGestureTemplates, [template])
        XCTAssertEqual(reloaded.presets, [expectedPreset])
        XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent("shortcuts.v7.backup.json")), original)
        XCTAssertEqual(ShortcutStore(fileURL: url, seedExamples: false).rules, [expected])
        let migrated = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual(migrated["version"] as? Int, ShortcutStore.currentDocumentVersion)
        XCTAssertNil(migrated["profiles"])
        XCTAssertNil((migrated["rules"] as? [[String: Any]])?.first?["profileID"])

        legacy["profiles"] = []
        let orphan = try ShortcutDocumentCodec.decode(JSONSerialization.data(withJSONObject: legacy))
        var orphanRule = try XCTUnwrap(orphan.rules.first)
        XCTAssertFalse(orphanRule.isEnabled)
        orphanRule.isEnabled = true
        XCTAssertFalse(orphanRule.matches(ContextSnapshot(frontmostApplicationBundleIdentifier: "com.apple.Preview",
            frontmostWindowTitle: "PDF", modifiers: [.command])))
        XCTAssertTrue(orphan.presets.first?.conditions.contains(.application(bundleIdentifiers: [])) == true)

        var disabled = profile
        disabled["isEnabled"] = false
        legacy["profiles"] = [disabled]
        XCTAssertFalse(try XCTUnwrap(ShortcutDocumentCodec.decode(JSONSerialization.data(withJSONObject: legacy)).rules.first).isEnabled)
        legacy["profiles"] = [profile, profile]
        XCTAssertThrowsError(try ShortcutDocumentCodec.decode(JSONSerialization.data(withJSONObject: legacy)))
        var invalid = profile
        invalid["priority"] = Int.max
        legacy["profiles"] = [invalid]
        XCTAssertThrowsError(try ShortcutDocumentCodec.decode(JSONSerialization.data(withJSONObject: legacy)))
    }

    func testVersionFiveSingleActionMigratesToWorkflowAndCreatesBackup() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Tico-v5-\(UUID().uuidString)", isDirectory: true)
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

    func testIndependentConditionsFilterAndPrioritizeRules() {
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
            conditions: [.modifiers([.command]), .application(bundleIdentifiers: ["com.apple.Preview"]),
                         .windowTitle(RuleTextMatcher(value: "PDF"))],
            priority: 4
        )
        let context = ContextSnapshot(
            frontmostApplicationBundleIdentifier: "com.apple.Preview",
            frontmostWindowTitle: "Relatório PDF",
            modifiers: [.command]
        )

        let matches = TriggerMatcher().matchingRules(
            in: [global, contextual],
            for: .keyboard(keyCode: 49, modifiers: [.command]),
            context: context
        )

        XCTAssertEqual(matches.map(\.name), ["Contextual", "Global"])
        var wrongTitle = context
        wrongTitle.frontmostWindowTitle = "Imagem"
        XCTAssertFalse(contextual.matches(wrongTitle))
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
            .appendingPathComponent("Tico-metrics-\(UUID().uuidString)", isDirectory: true)
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

        // Valida o recorte apresentado e exportado usando somente os registros
        // sintéticos deste teste. Fronteiras são dias locais, não blocos de 24h.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: -10_800))
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let today = calendar.startOfDay(for: now)
        let boundary = try XCTUnwrap(calendar.date(byAdding: .day, value: -6, to: today))
        let id = UUID()
        let records = [
            GestureMetricEvent(occurredAt: now.addingTimeInterval(-1), ruleID: id, ruleName: "Nome atual", outcome: .success),
            GestureMetricEvent(occurredAt: today.addingTimeInterval(-1), ruleID: id, ruleName: "Nome anterior", outcome: .success),
            GestureMetricEvent(occurredAt: boundary, ruleName: "Outra", outcome: .failure),
            GestureMetricEvent(occurredAt: now.addingTimeInterval(-2), ruleID: id, ruleName: "Nome atual", outcome: .cancelled),
            GestureMetricEvent(occurredAt: now.addingTimeInterval(-3), outcome: .rejected),
            GestureMetricEvent(occurredAt: boundary.addingTimeInterval(-1), outcome: .failure),
            GestureMetricEvent(occurredAt: now.addingTimeInterval(60), outcome: .success)
        ]
        let week = ActivitySummary(events: records, period: .week, now: now, calendar: calendar)
        XCTAssertEqual(week.events.count, 5)
        XCTAssertEqual(week.executionCount, 4)
        XCTAssertEqual(week.successes, 2)
        XCTAssertEqual(week.failures, 1)
        XCTAssertEqual(week.cancellations, 1)
        XCTAssertEqual(week.rejections, 1)
        XCTAssertEqual(week.usage.first?.name, "Nome atual")
        XCTAssertEqual(week.usage.first?.count, 3)
        XCTAssertEqual(week.history(outcome: .success, subject: week.usage.first?.id).count, 2)
        XCTAssertEqual(ActivitySummary(events: records, period: .today, now: now, calendar: calendar).events.count, 3)
        XCTAssertEqual(ActivitySummary(events: records, period: .all, now: now, calendar: calendar).events.count, 6)
        XCTAssertEqual(ActivitySummary(events: records, period: .week, search: "Nome atual", now: now, calendar: calendar).events.count, 2)
        let failures = week.history(outcome: .failure, subject: nil)
        try store.exportCSV(to: csvURL, events: failures)
        let filteredCSV = try String(contentsOf: csvURL, encoding: .utf8)
        XCTAssertEqual(filteredCSV.split(separator: "\n").count, 2)
        XCTAssertTrue(filteredCSV.contains("Outra"))
        XCTAssertFalse(filteredCSV.contains("Nome atual"))
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

private final class ShellScriptSpy: ShellScriptRunning {
    var commands: [String] = []

    func run(
        command: String,
        approved: Bool,
        timeout: TimeInterval
    ) async throws -> ShellScriptExecutionResult {
        commands.append(command)
        return ShellScriptExecutionResult(
            terminationStatus: 0,
            standardOutput: "",
            standardError: "",
            timedOut: false,
            duration: 0,
            outputWasTruncated: false
        )
    }
}
