import Foundation
import XCTest
@testable import Tico

final class TicoIdentityTests: XCTestCase {
    private var temporaryDirectories: [URL] = []
    private var defaultsSuites: [String] = []

    override func tearDown() {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        for suite in defaultsSuites {
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        super.tearDown()
    }

    func testDefaultStorePathsUseTicoApplicationSupportDirectory() {
        let expectedDirectory = TicoBrand.applicationSupportDirectoryName

        XCTAssertEqual(
            ShortcutStore.defaultFileURL().deletingLastPathComponent().lastPathComponent,
            expectedDirectory
        )
        XCTAssertEqual(
            EventLogStore.defaultFileURL().deletingLastPathComponent().lastPathComponent,
            expectedDirectory
        )
        XCTAssertEqual(
            MetricsStore.defaultFileURL().deletingLastPathComponent().lastPathComponent,
            expectedDirectory
        )
    }

    func testTicoStoresCompleteInstallationInTicoDirectory() throws {
        let root = makeTemporaryDirectory()
        let ticoDirectory = root.appendingPathComponent(
            TicoBrand.applicationSupportDirectoryName,
            isDirectory: true
        )
        let shortcutsURL = ticoDirectory.appendingPathComponent("shortcuts.json")
        let logURL = ticoDirectory.appendingPathComponent("execution-log.json")
        let metricsURL = ticoDirectory.appendingPathComponent("metrics.json")

        let shortcutStore = ShortcutStore(fileURL: shortcutsURL, seedExamples: false)
        let profile = ShortcutProfile(
            name: "Perfil Tico",
            applicationBundleIdentifiers: ["com.apple.Preview"],
            priority: 4
        )
        let workflow = ActionWorkflow(
            name: "Workflow Tico",
            steps: [
                WorkflowStep(action: .setClipboard(text: "compatível")),
                WorkflowStep(action: .notification(title: "Tico", body: "Concluído"))
            ]
        )
        let template = makeGestureTemplate()
        let preset = GesturePreset(
            name: "Preset Tico",
            trigger: .customTrackpad(template: template),
            workflow: workflow,
            profileID: profile.id,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let rule = ShortcutRule(
            name: "Regra Tico completa",
            trigger: .customTrackpad(template: template),
            action: .setClipboard(text: "compatível"),
            workflow: workflow,
            profileID: profile.id,
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        try shortcutStore.addProfile(profile)
        try shortcutStore.saveReusableWorkflow(workflow)
        try shortcutStore.saveCustomGestureTemplate(template)
        try shortcutStore.savePreset(preset)
        try shortcutStore.add(rule)

        let logStore = EventLogStore(fileURL: logURL)
        try logStore.record(rule: rule, result: .succeeded("Executada"))

        let metricsStore = MetricsStore(fileURL: metricsURL)
        metricsStore.record(GestureMetricEvent(
            ruleID: rule.id,
            ruleName: rule.name,
            gesture: .swipeRight,
            outcome: .success,
            confidence: 0.91,
            latency: 0.012
        ))

        let ticoShortcutStore = ShortcutStore(fileURL: shortcutsURL, seedExamples: false)
        let ticoLogStore = EventLogStore(fileURL: logURL)
        let ticoMetricsStore = MetricsStore(fileURL: metricsURL)

        XCTAssertEqual(ticoShortcutStore.rules, [rule])
        XCTAssertEqual(ticoShortcutStore.profiles, [profile])
        XCTAssertEqual(ticoShortcutStore.reusableWorkflows, [workflow])
        XCTAssertEqual(ticoShortcutStore.customGestureTemplates, [template])
        XCTAssertEqual(ticoShortcutStore.presets, [preset])
        XCTAssertEqual(ticoLogStore.entries.map(\.ruleID), [rule.id])
        XCTAssertEqual(ticoMetricsStore.events.map(\.ruleID), [rule.id])
        XCTAssertTrue(FileManager.default.fileExists(atPath: shortcutsURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: ticoDirectory.path))
    }

    func testTicoReadsAndWritesTicoUserDefaultsKeys() {
        let defaults = makeDefaults()
        let prefix = TicoBrand.userDefaultsPrefix + "settings."
        defaults.set(true, forKey: prefix + "launchAtLogin")
        defaults.set(false, forKey: prefix + "showMenuBarExtra")
        defaults.set(true, forKey: prefix + "startEventCaptureOnLaunch")

        let settings = AppSettingsStore(defaults: defaults)

        XCTAssertTrue(settings.launchAtLogin)
        XCTAssertFalse(settings.showMenuBarExtra)
        XCTAssertTrue(settings.startEventCaptureOnLaunch)

        settings.showMenuBarExtra = true

        XCTAssertEqual(defaults.object(forKey: prefix + "showMenuBarExtra") as? Bool, true)
        XCTAssertEqual(
            defaults.integer(forKey: prefix + "version"),
            AppSettingsStore.currentSettingsVersion
        )
    }

    @MainActor
    func testAuxiliaryStoresUseTicoUserDefaultsKeys() {
        let defaults = makeDefaults()

        let calibration = GestureCalibration(
            preset: .custom,
            sensitivity: 1.4,
            minimumVelocity: 0.08,
            confidenceThreshold: 0.63
        )
        TrackpadCalibrationStore(defaults: defaults).update(calibration, for: .swipeRight)
        TrackpadValidationStore(defaults: defaults).recordPublicFallbackGesture(.pinchOut)
        AutomationApprovalStore(defaults: defaults).approve("tell application \"Finder\"")

        let capabilityStore = TrackpadCapabilityStore(defaults: defaults)
        for _ in 0..<10 {
            capabilityStore.observe(deviceID: "tico-trackpad", pressure: 0.42)
        }

        let reloadedCalibration = TrackpadCalibrationStore(defaults: defaults)
        let reloadedValidation = TrackpadValidationStore(defaults: defaults)
        let reloadedApprovals = AutomationApprovalStore(defaults: defaults)
        let reloadedCapabilities = TrackpadCapabilityStore(defaults: defaults)

        XCTAssertEqual(reloadedCalibration.calibration(for: .swipeRight), calibration)
        XCTAssertEqual(reloadedValidation.report.recognizedByGesture[.pinchOut], 1)
        XCTAssertTrue(reloadedApprovals.isApproved("tell application \"Finder\""))
        XCTAssertEqual(reloadedCapabilities.devices["tico-trackpad"]?.pressureSampleCount, 10)
        XCTAssertNotNil(defaults.data(
            forKey: TicoBrand.userDefaultsPrefix + "trackpad-calibration"
        ))
    }

    private func makeGestureTemplate() -> CustomGestureTemplate {
        let points = [
            TrackpadPoint(x: 0, y: 0),
            TrackpadPoint(x: 0.5, y: 1),
            TrackpadPoint(x: 1, y: 0)
        ]
        let normalized = CustomGesturePath.normalized(
            points,
            pointCount: CustomGestureTemplate.defaultPointCount
        )!
        return CustomGestureTemplate(
            name: "Gesto Tico",
            fingerCount: 3...3,
            samplePaths: [normalized, normalized, normalized],
            createdAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }

    private func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TicoIdentity-\(UUID().uuidString)", isDirectory: true)
        temporaryDirectories.append(directory)
        return directory
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "TicoIdentity.\(UUID().uuidString)"
        defaultsSuites.append(suite)
        UserDefaults.standard.removePersistentDomain(forName: suite)
        return UserDefaults(suiteName: suite)!
    }
}
