import Foundation
import XCTest
@testable import Tico

final class SecurityRegressionTests: XCTestCase {
    private var temporaryDirectories: [URL] = []
    private var defaultsSuites: [String] = []

    override func tearDownWithError() throws {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        for suite in defaultsSuites {
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        temporaryDirectories.removeAll()
        defaultsSuites.removeAll()
    }

    func testMalformedRuleDocumentsAreRejectedAtomically() throws {
        let directory = makeTemporaryDirectory()
        let destinationURL = directory.appendingPathComponent("destination.json")
        let sourceURL = directory.appendingPathComponent("source.json")
        let mutatedURL = directory.appendingPathComponent("mutated.json")
        let retained = makeRule(name: "Retained")
        let sourceRule = ShortcutRule(
            name: "Trackpad URL",
            trigger: .trackpad(
                spec: TrackpadTriggerSpec(
                    gesture: .swipeRight,
                    fingerCount: 3...3,
                    pressureRange: 0.2...0.8
                )
            ),
            action: .openURL(url: URL(string: "https://example.com")!)
        )
        let destination = ShortcutStore(fileURL: destinationURL, seedExamples: false)
        try destination.add(retained)
        let source = ShortcutStore(fileURL: sourceURL, seedExamples: false)
        try source.add(sourceRule)
        try source.exportRules(to: sourceURL)

        let mutations: [(inout [String: Any]) -> Void] = [
            { document in
                Self.mutateFirstRule(in: &document) { rule in
                    rule["priority"] = Int.max
                }
            },
            { document in
                Self.mutateFirstWorkflow(in: &document) { workflow in
                    workflow["timeout"] = -1e300
                }
            },
            { document in
                Self.mutateFirstStep(in: &document) { step in
                    step["delayBefore"] = 1e300
                }
            },
            { document in
                Self.mutateFirstStep(in: &document) { step in
                    step["timeout"] = 1e300
                }
            },
            { document in
                Self.mutateFirstStep(in: &document) { step in
                    var action = step["action"] as? [String: Any] ?? [:]
                    action["url"] = "file:///private/tmp/untrusted"
                    step["action"] = action
                }
            },
            { document in
                Self.mutateFirstRule(in: &document) { rule in
                    var trigger = rule["trigger"] as? [String: Any] ?? [:]
                    var spec = trigger["spec"] as? [String: Any] ?? [:]
                    spec["pressureRange"] = [1.0, -1.0]
                    trigger["spec"] = spec
                    rule["trigger"] = trigger
                }
            }
        ]

        for mutation in mutations {
            var document = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(contentsOf: sourceURL))
                    as? [String: Any]
            )
            mutation(&document)
            try JSONSerialization.data(withJSONObject: document).write(
                to: mutatedURL,
                options: .atomic
            )

            XCTAssertThrowsError(
                try destination.importRules(from: mutatedURL, strategy: .replace)
            )
            XCTAssertEqual(destination.rules, [retained])
            XCTAssertEqual(
                ShortcutStore(fileURL: destinationURL, seedExamples: false).rules,
                [retained]
            )
        }
    }

    func testOversizedRuleDocumentIsRejectedBeforeDecode() throws {
        let directory = makeTemporaryDirectory()
        let storeURL = directory.appendingPathComponent("store.json")
        let importURL = directory.appendingPathComponent("oversized.json")
        let store = ShortcutStore(fileURL: storeURL, seedExamples: false)
        let retained = makeRule(name: "Retained")
        try store.add(retained)
        try Data(
            repeating: 0x20,
            count: DocumentSecurityPolicy.maximumDocumentBytes + 1
        ).write(to: importURL)

        XCTAssertThrowsError(try store.importRules(from: importURL))
        XCTAssertEqual(store.rules, [retained])
    }

    func testReplayRejectsOversizedContactsAndExtremeTimestamps() throws {
        let touches = (0...TrackpadReplayDocument.maximumTouchesPerFrame).map {
            makeTouch(identifier: Int32($0))
        }
        let oversizedContacts = TrackpadReplayDocument(
            name: "oversized",
            frames: [makeFrame(touches: touches, date: Date(timeIntervalSince1970: 100))]
        )
        XCTAssertThrowsError(try ReplayFrameProvider(data: rawReplayData(oversizedContacts)))

        let start = Date(timeIntervalSince1970: 100)
        let extremeDuration = TrackpadReplayDocument(
            name: "extreme",
            frames: [
                makeFrame(touches: [], date: start, number: 1),
                makeFrame(
                    touches: [],
                    date: start.addingTimeInterval(
                        TrackpadReplayDocument.maximumDuration + 1
                    ),
                    number: 2
                )
            ]
        )
        XCTAssertThrowsError(try ReplayFrameProvider(data: rawReplayData(extremeDuration)))
    }

    func testReplayAcceptsBoundedLegitimateDocument() throws {
        let start = Date(timeIntervalSince1970: 100)
        let document = TrackpadReplayDocument(
            name: "bounded",
            frames: [
                makeFrame(touches: [makeTouch(identifier: 1)], date: start, number: 1),
                makeFrame(
                    touches: [makeTouch(identifier: 1)],
                    date: start.addingTimeInterval(0.1),
                    number: 2
                )
            ],
            createdAt: Date(timeIntervalSince1970: 200)
        )

        let provider = try ReplayFrameProvider(data: ReplayFrameProvider.encode(document))
        XCTAssertEqual(provider.document, document)
    }

    func testURLLauncherRejectsNonWebSchemesBeforeCallingWorkspace() throws {
        var opened: [URL] = []
        let launcher = URLLauncher(
            canOpen: { _ in true },
            opener: {
                opened.append($0)
                return true
            }
        )

        XCTAssertThrowsError(try launcher.open(URL(fileURLWithPath: "/private/tmp/test")))
        XCTAssertTrue(opened.isEmpty)
        let webURL = URL(string: "https://example.com")!
        XCTAssertNoThrow(try launcher.open(webURL))
        XCTAssertEqual(opened, [webURL])
    }

    func testMetricsCSVNeutralizesSpreadsheetFormulaPrefixes() throws {
        let directory = makeTemporaryDirectory()
        let store = MetricsStore(
            fileURL: directory.appendingPathComponent("metrics.json")
        )
        let exportURL = directory.appendingPathComponent("metrics.csv")
        store.record(GestureMetricEvent(
            ruleName: "=HYPERLINK(\"https://example.com\")",
            deviceID: "+cmd",
            outcome: .success
        ))

        try store.exportCSV(to: exportURL)
        let csv = try String(contentsOf: exportURL, encoding: .utf8)
        XCTAssertTrue(csv.contains("\"'=HYPERLINK"))
        XCTAssertTrue(csv.contains("\"'+cmd\""))
    }

    func testEffectivePrioritySaturatesInsteadOfOverflowing() {
        let profile = ShortcutProfile(name: "Unsafe")
        var rule = makeRule(name: "Unsafe")
        rule.priority = .max
        rule.profileID = profile.id
        var unsafeProfile = profile
        unsafeProfile.priority = 1

        XCTAssertEqual(rule.effectivePriority(profiles: [unsafeProfile]), .max)
    }

    @MainActor
    func testDeniedInputMonitoringPreventsTrackpadProviderStart() throws {
        let directory = makeTemporaryDirectory()
        let defaults = makeDefaults()
        let provider = CountingTrackpadFrameProvider()
        let validation = TrackpadValidationStore(
            defaults: defaults,
            storageKey: "validation"
        )
        let trackpad = TrackpadGestureService(
            providerFactory: { provider },
            validationStore: validation
        )
        let permissions = PermissionCoordinator(
            accessibilityCheck: { false },
            accessibilityRequest: { false },
            inputMonitoringCheck: { .denied },
            inputMonitoringRequest: { false },
            settingsOpener: { _ in },
            applicationURL: { directory },
            fileRevealer: { _ in }
        )
        let controller = AppController(
            shortcutStore: ShortcutStore(
                fileURL: directory.appendingPathComponent("rules.json"),
                seedExamples: false
            ),
            settings: AppSettingsStore(defaults: defaults),
            eventLogStore: EventLogStore(
                fileURL: directory.appendingPathComponent("events.json")
            ),
            permissions: permissions,
            calibrationStore: TrackpadCalibrationStore(
                defaults: defaults,
                storageKey: "calibration"
            ),
            validationStore: validation,
            metricsStore: MetricsStore(
                fileURL: directory.appendingPathComponent("metrics.json")
            ),
            capabilityStore: TrackpadCapabilityStore(
                defaults: defaults,
                storageKey: "capabilities"
            ),
            trackpadGestures: trackpad
        )

        XCTAssertFalse(controller.startTrackpadObservation())
        XCTAssertEqual(provider.startCount, 0)
        XCTAssertFalse(trackpad.isRunning)
    }

    private func rawReplayData(_ document: TrackpadReplayDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return try encoder.encode(document)
    }

    private func makeRule(name: String) -> ShortcutRule {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        return ShortcutRule(
            name: name,
            trigger: .keyboard(keyCode: 49, modifiers: [.command]),
            action: .openURL(url: URL(string: "https://example.com")!),
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }

    private func makeFrame(
        touches: [RawTrackpadTouch],
        date: Date,
        number: Int32 = 1
    ) -> RawTrackpadFrame {
        RawTrackpadFrame(
            touches: touches,
            deviceTimestamp: date.timeIntervalSince1970,
            frameNumber: number,
            receivedAt: date,
            deviceID: "test-device"
        )
    }

    private func makeTouch(identifier: Int32) -> RawTrackpadTouch {
        RawTrackpadTouch(
            identifier: identifier,
            state: 4,
            position: TrackpadPoint(x: 0.5, y: 0.5),
            velocity: TrackpadPoint(x: 0, y: 0),
            pressure: 0.5
        )
    }

    private func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TicoSecurity-\(UUID().uuidString)", isDirectory: true)
        temporaryDirectories.append(directory)
        return directory
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "TicoSecurity.\(UUID().uuidString)"
        defaultsSuites.append(suite)
        return UserDefaults(suiteName: suite)!
    }

    private static func mutateFirstRule(
        in document: inout [String: Any],
        mutation: (inout [String: Any]) -> Void
    ) {
        var rules = document["rules"] as? [[String: Any]] ?? []
        guard !rules.isEmpty else { return }
        mutation(&rules[0])
        document["rules"] = rules
    }

    private static func mutateFirstWorkflow(
        in document: inout [String: Any],
        mutation: (inout [String: Any]) -> Void
    ) {
        mutateFirstRule(in: &document) { rule in
            var workflow = rule["workflow"] as? [String: Any] ?? [:]
            mutation(&workflow)
            rule["workflow"] = workflow
        }
    }

    private static func mutateFirstStep(
        in document: inout [String: Any],
        mutation: (inout [String: Any]) -> Void
    ) {
        mutateFirstWorkflow(in: &document) { workflow in
            var steps = workflow["steps"] as? [[String: Any]] ?? []
            guard !steps.isEmpty else { return }
            mutation(&steps[0])
            workflow["steps"] = steps
        }
    }
}

private final class CountingTrackpadFrameProvider: TrackpadFrameProvider, @unchecked Sendable {
    let capabilities = TrackpadProviderCapabilities.privateMultitouch
    private(set) var isRunning = false
    private(set) var startCount = 0

    func start(onFrame: @escaping @Sendable (RawTrackpadFrame) -> Void) throws {
        startCount += 1
        isRunning = true
    }

    func stop() {
        isRunning = false
    }
}
