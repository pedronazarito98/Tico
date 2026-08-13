import XCTest
@testable import Tico

final class AdvancedPhasesTests: XCTestCase {
    func testTapComposerCountsDoubleAndTripleTapWithinInterval() {
        var composer = TapCountComposer(maximumInterval: 0.4)
        let base = Date(timeIntervalSince1970: 10)

        let first = composer.process(tapEvent(at: base))
        let second = composer.process(tapEvent(at: base.addingTimeInterval(0.2)))
        let third = composer.process(tapEvent(at: base.addingTimeInterval(0.38)))
        let reset = composer.process(tapEvent(at: base.addingTimeInterval(1)))

        XCTAssertEqual(first.advanced?.tapCount, 1)
        XCTAssertEqual(second.advanced?.tapCount, 2)
        XCTAssertEqual(third.advanced?.tapCount, 3)
        XCTAssertEqual(reset.advanced?.tapCount, 1)
    }

    func testTipTapUsesAnchorsAndSideWithoutEmittingAddFinger() {
        var engine = AdvancedGestureEngine()
        let base = Date(timeIntervalSince1970: 20)
        var events: [GestureEvent] = []

        for frame in [
            makeFrame(
                at: base,
                touches: [
                    touch(1, x: 0.45, y: 0.5),
                    touch(2, x: 0.62, y: 0.5)
                ]
            ),
            makeFrame(
                at: base.addingTimeInterval(0.15),
                touches: [
                    touch(1, x: 0.45, y: 0.5),
                    touch(2, x: 0.62, y: 0.5)
                ]
            ),
            makeFrame(
                at: base.addingTimeInterval(0.20),
                touches: [
                    touch(1, x: 0.45, y: 0.5),
                    touch(2, x: 0.62, y: 0.5),
                    touch(3, x: 0.20, y: 0.5)
                ]
            ),
            makeFrame(
                at: base.addingTimeInterval(0.27),
                touches: [
                    touch(1, x: 0.45, y: 0.5),
                    touch(2, x: 0.62, y: 0.5)
                ]
            )
        ] {
            if let event = engine.process(frame).event {
                events.append(event)
            }
        }

        XCTAssertEqual(events.map(\.kind), [.tipTapLeft])
        XCTAssertEqual(events.first?.advanced?.anchorFingerCount, 2)
    }

    func testAddAndRemoveFingerRequireStableAnchorTransition() {
        var engine = AdvancedGestureEngine()
        let base = Date(timeIntervalSince1970: 30)
        var events: [GestureEvent] = []

        for frame in [
            makeFrame(
                at: base,
                touches: [touch(1, x: 0.4, y: 0.5), touch(2, x: 0.6, y: 0.5)]
            ),
            makeFrame(
                at: base.addingTimeInterval(0.12),
                touches: [
                    touch(1, x: 0.4, y: 0.5),
                    touch(2, x: 0.6, y: 0.5),
                    touch(3, x: 0.8, y: 0.5)
                ]
            ),
            makeFrame(
                at: base.addingTimeInterval(0.30),
                touches: [
                    touch(1, x: 0.4, y: 0.5),
                    touch(2, x: 0.6, y: 0.5),
                    touch(3, x: 0.8, y: 0.5)
                ]
            ),
            makeFrame(
                at: base.addingTimeInterval(0.50),
                touches: [touch(1, x: 0.4, y: 0.5), touch(2, x: 0.6, y: 0.5)]
            )
        ] {
            if let event = engine.process(frame).event {
                events.append(event)
            }
        }

        XCTAssertEqual(events.map(\.kind), [.addFinger, .removeFinger])
        XCTAssertEqual(events[0].advanced?.addedFingerCount, 1)
        XCTAssertEqual(events[1].advanced?.removedFingerCount, 1)
    }

    func testTrackpadSpecMatchesTapCountAnchorsAndHeldModifiers() {
        var spec = TrackpadTriggerSpec(
            gesture: .tipTapRight,
            fingerCount: 3...3,
            anchorFingerCount: 2,
            requiredModifiers: [.command]
        )
        spec.tapCount = 1
        let event = GestureEvent(
            sessionID: UUID(),
            kind: .tipTapRight,
            phase: .ended,
            fingerCount: 3,
            startRegion: .any,
            endRegion: .any,
            confidence: 0.9,
            advanced: AdvancedGestureMetadata(anchorFingerCount: 2),
            occurredAt: Date()
        )

        XCTAssertTrue(
            TriggerMatcher().matches(
                .trackpad(spec: spec),
                event: InputEventDescriptor.trackpad(event).withModifiers([.command])
            )
        )
        XCTAssertFalse(
            TriggerMatcher().matches(
                .trackpad(spec: spec),
                event: InputEventDescriptor.trackpad(event)
            )
        )
    }

    func testSequenceRuntimeResolvesAmbiguousPrefixWithLongerSequence() {
        let base = Date(timeIntervalSince1970: 40)
        let first = TriggerStep.keyboard(keyCode: 12, modifiers: [.command])
        let second = TriggerStep.mouseButton(button: 3, modifiers: [])
        let third = TriggerStep.trackpad(
            spec: TrackpadTriggerSpec(gesture: .swipeRight, fingerCount: 3)
        )
        let short = rule(
            name: "Curta",
            trigger: .sequence(TriggerSequence(steps: [first, second]))
        )
        let long = rule(
            name: "Longa",
            trigger: .sequence(TriggerSequence(steps: [first, second, third]))
        )
        var runtime = TriggerSequenceRuntime()
        let context = ContextSnapshot(capturedAt: base)

        XCTAssertTrue(
            runtime.process(
                event: .keyboard(keyCode: 12, modifiers: [.command], timestamp: base),
                rules: [short, long],
                context: context
            ).matchedRules.isEmpty
        )
        XCTAssertTrue(
            runtime.process(
                event: .mouseButton(3, timestamp: base.addingTimeInterval(0.1)),
                rules: [short, long],
                context: context
            ).matchedRules.isEmpty
        )
        let completion = runtime.process(
            event: .trackpad(
                .swipeRight,
                fingerCount: 3,
                timestamp: base.addingTimeInterval(0.2)
            ),
            rules: [short, long],
            context: context
        )

        XCTAssertEqual(completion.matchedRules.map(\.id), [long.id])
        XCTAssertTrue(
            runtime.flushExpired(
                rules: [short, long],
                at: base.addingTimeInterval(2)
            ).isEmpty
        )
    }

    func testSequencePrefixExecutesAfterTimeout() {
        let base = Date(timeIntervalSince1970: 50)
        let steps: [TriggerStep] = [
            .keyboard(keyCode: 12, modifiers: []),
            .mouseButton(button: 3, modifiers: [])
        ]
        let short = rule(
            name: "Curta",
            trigger: .sequence(
                TriggerSequence(steps: steps, maximumInterval: 0.3)
            )
        )
        let long = rule(
            name: "Longa",
            trigger: .sequence(
                TriggerSequence(
                    steps: steps + [
                        .trackpad(spec: TrackpadTriggerSpec(gesture: .tap, fingerCount: 3))
                    ],
                    maximumInterval: 0.3
                )
            )
        )
        var runtime = TriggerSequenceRuntime()
        let context = ContextSnapshot(capturedAt: base)

        _ = runtime.process(
            event: .keyboard(keyCode: 12, timestamp: base),
            rules: [short, long],
            context: context
        )
        _ = runtime.process(
            event: .mouseButton(3, timestamp: base.addingTimeInterval(0.1)),
            rules: [short, long],
            context: context
        )

        XCTAssertEqual(
            runtime.flushExpired(
                rules: [short, long],
                at: base.addingTimeInterval(0.5)
            ).map(\.id),
            [short.id]
        )
    }

    func testSingleTapWaitsAndIsSuppressedByDoubleTap() {
        let base = Date(timeIntervalSince1970: 55)
        let single = rule(
            name: "Simples",
            trigger: .trackpad(
                spec: TrackpadTriggerSpec(
                    gesture: .tap,
                    fingerCount: 3...3,
                    tapCount: 1,
                    maximumTapInterval: 0.4
                )
            )
        )
        let double = rule(
            name: "Duplo",
            trigger: .trackpad(
                spec: TrackpadTriggerSpec(
                    gesture: .tap,
                    fingerCount: 3...3,
                    tapCount: 2,
                    maximumTapInterval: 0.4
                )
            )
        )
        var runtime = TriggerSequenceRuntime()
        let context = ContextSnapshot(capturedAt: base)
        let first = InputEventDescriptor.trackpad(
            tapEvent(at: base, count: 1)
        )
        let second = InputEventDescriptor.trackpad(
            tapEvent(at: base.addingTimeInterval(0.2), count: 2, interval: 0.2)
        )

        XCTAssertTrue(
            runtime.process(
                event: first,
                rules: [single, double],
                context: context
            ).matchedRules.isEmpty
        )
        XCTAssertEqual(
            runtime.process(
                event: second,
                rules: [single, double],
                context: context
            ).matchedRules.map(\.id),
            [double.id]
        )
        XCTAssertTrue(
            runtime.flushExpired(
                rules: [single, double],
                at: base.addingTimeInterval(1)
            ).isEmpty
        )
    }

    func testApplicationSpecificRuleWinsOverGlobalRule() {
        let trigger = TriggerDefinition.keyboard(keyCode: 1, modifiers: [])
        let global = rule(name: "Global", trigger: trigger)
        let specific = rule(
            name: "Safari",
            trigger: trigger,
            scope: .applications(bundleIdentifiers: ["com.apple.Safari"])
        )
        var runtime = TriggerSequenceRuntime()
        let event = InputEventDescriptor.keyboard(keyCode: 1)
        let context = ContextSnapshot(
            frontmostApplicationBundleIdentifier: "com.apple.Safari"
        )

        XCTAssertEqual(
            runtime.process(
                event: event,
                rules: [global, specific],
                context: context
            ).matchedRules.map(\.id),
            [specific.id]
        )
    }

    func testApplicationSpecificOverlapSuppressesGlobalRule() {
        let global = rule(
            name: "Global",
            trigger: .trackpad(
                spec: TrackpadTriggerSpec(gesture: .swipeUp, fingerCount: 2...4)
            )
        )
        let specific = rule(
            name: "Safari",
            trigger: .trackpad(
                spec: TrackpadTriggerSpec(gesture: .swipeUp, fingerCount: 3...5)
            ),
            scope: .applications(bundleIdentifiers: ["com.apple.Safari"])
        )
        var runtime = TriggerSequenceRuntime()
        let context = ContextSnapshot(
            frontmostApplicationBundleIdentifier: "com.apple.Safari"
        )

        XCTAssertEqual(
            runtime.process(
                event: .trackpad(.swipeUp, fingerCount: 3),
                rules: [global, specific],
                context: context
            ).matchedRules.map(\.id),
            [specific.id]
        )
    }

    func testConflictAnalyzerFindsDuplicateOverlapAndPrefix() {
        let existing = rule(
            name: "Existente",
            trigger: .trackpad(
                spec: TrackpadTriggerSpec(
                    gesture: .tap,
                    fingerCount: 2...4,
                    tapCount: 2
                )
            )
        )
        let duplicate = rule(name: "Duplicada", trigger: existing.trigger)
        let overlap = rule(
            name: "Sobreposta",
            trigger: .trackpad(
                spec: TrackpadTriggerSpec(
                    gesture: .tap,
                    fingerCount: 3...5,
                    tapCount: 2
                )
            )
        )
        let prefix = rule(
            name: "Prefixo",
            trigger: .sequence(
                TriggerSequence(steps: [
                    .keyboard(keyCode: 1, modifiers: []),
                    .mouseButton(button: 3, modifiers: [])
                ])
            )
        )
        let longer = rule(
            name: "Longa",
            trigger: .sequence(
                TriggerSequence(steps: [
                    .keyboard(keyCode: 1, modifiers: []),
                    .mouseButton(button: 3, modifiers: []),
                    .trackpad(spec: TrackpadTriggerSpec(gesture: .tap, fingerCount: 3))
                ])
            )
        )
        let analyzer = RuleConflictAnalyzer()

        XCTAssertEqual(
            analyzer.conflicts(for: duplicate, among: [existing]).first?.severity,
            .replacementRequired
        )
        XCTAssertEqual(
            analyzer.conflicts(for: overlap, among: [existing]).first?.kind,
            .overlapping
        )
        XCTAssertEqual(
            analyzer.conflicts(for: longer, among: [prefix]).first?.kind,
            .sequencePrefix
        )
    }

    func testNewActionsRouteToApplicationAndWindowControllers() async {
        let applications = ApplicationControllerSpy()
        let windows = WindowControllerSpy()
        let runner = ActionRunner(
            applicationController: applications,
            windowController: windows
        )

        let applicationResult = await runner.execute(
            .application(
                target: .bundleIdentifier("com.apple.Safari"),
                operation: .quit
            )
        )
        let windowResult = await runner.execute(
            .window(target: .frontmost, operation: .tileAll)
        )

        XCTAssertTrue(applicationResult.success)
        XCTAssertTrue(windowResult.success)
        XCTAssertEqual(applications.operations, [.quit])
        XCTAssertEqual(windows.operations, [.tileAll])
    }

    func testVersionFivePersistsSequencesScopeAndWindowAction() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("shortcuts.json")
        let store = ShortcutStore(fileURL: url, seedExamples: false)
        let timestamp = Date(timeIntervalSince1970: 100)
        let original = ShortcutRule(
            name: "Organizar Safari",
            trigger: .sequence(
                TriggerSequence(steps: [
                    .keyboard(keyCode: 12, modifiers: [.command]),
                    .trackpad(
                        spec: TrackpadTriggerSpec(
                            gesture: .tipTapRight,
                            fingerCount: 3...3,
                            anchorFingerCount: 2,
                            requiredModifiers: [.command]
                        )
                    )
                ])
            ),
            action: .window(
                target: .bundleIdentifier("com.apple.Safari"),
                operation: .tileAll
            ),
            scope: .applications(bundleIdentifiers: ["com.apple.Safari"]),
            priority: 4,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        try store.add(original)
        let reloaded = ShortcutStore(fileURL: url, seedExamples: false)

        XCTAssertEqual(reloaded.rules, [original])
    }

    func testReplacingDuplicateConflictRemovesOldRule() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ShortcutStore(
            fileURL: directory.appendingPathComponent("shortcuts.json"),
            seedExamples: false
        )
        let trigger = TriggerDefinition.keyboard(keyCode: 12, modifiers: [.command])
        let first = rule(name: "Primeira", trigger: trigger)
        var replacement = rule(name: "Nova", trigger: trigger)
        try store.add(first)
        try store.add(replacement)
        replacement.notes = "Atualizada"

        try store.replaceConflictingRules(with: replacement)

        XCTAssertEqual(store.rules.map(\.id), [replacement.id])
        XCTAssertEqual(store.rules.first?.notes, "Atualizada")
    }

    private func tapEvent(
        at date: Date,
        count: Int = 1,
        interval: TimeInterval? = nil
    ) -> GestureEvent {
        GestureEvent(
            sessionID: UUID(),
            kind: .tap,
            phase: .ended,
            fingerCount: 3,
            startRegion: .topLeft,
            endRegion: .topLeft,
            confidence: 0.9,
            advanced: AdvancedGestureMetadata(
                tapCount: count,
                tapInterval: interval
            ),
            occurredAt: date
        )
    }

    private func rule(
        name: String,
        trigger: TriggerDefinition,
        scope: RuleScope = .global
    ) -> ShortcutRule {
        ShortcutRule(
            name: name,
            trigger: trigger,
            action: .notification(title: name, body: ""),
            scope: scope
        )
    }

    private func makeFrame(
        at date: Date,
        touches: [RawTrackpadTouch]
    ) -> RawTrackpadFrame {
        RawTrackpadFrame(
            touches: touches,
            deviceTimestamp: date.timeIntervalSince1970,
            frameNumber: Int32(date.timeIntervalSince1970 * 100),
            receivedAt: date
        )
    }

    private func touch(
        _ identifier: Int32,
        x: Double,
        y: Double
    ) -> RawTrackpadTouch {
        RawTrackpadTouch(
            identifier: identifier,
            state: 4,
            position: TrackpadPoint(x: x, y: y),
            velocity: TrackpadPoint(x: 0, y: 0),
            pressure: 1
        )
    }
}

private final class ApplicationControllerSpy: ApplicationControlling {
    var operations: [ApplicationOperation] = []

    func perform(
        _ operation: ApplicationOperation,
        target: ApplicationTarget
    ) async throws {
        operations.append(operation)
    }
}

private final class WindowControllerSpy: WindowControlling {
    var operations: [WindowOperation] = []

    func perform(
        _ operation: WindowOperation,
        target: ApplicationTarget
    ) async throws {
        operations.append(operation)
    }
}
