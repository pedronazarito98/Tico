import Foundation
import AppKit
import XCTest
@testable import Tico

final class TrackpadLaboratoryPhaseOneTests: XCTestCase {
    private var suites: [String] = []

    override func tearDown() {
        for suite in suites {
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        suites.removeAll()
        super.tearDown()
    }

    func testCalibrationPresetsPersistPerGesture() throws {
        let defaults = makeDefaults()
        let store = TrackpadCalibrationStore(defaults: defaults, storageKey: "calibration")

        store.applyPreset(.responsive, to: .swipeRight)
        var customTap = store.calibration(for: .tap)
        customTap.sensitivity = 1.7
        customTap.confidenceThreshold = 0.35
        store.update(customTap, for: .tap)

        let reloaded = TrackpadCalibrationStore(defaults: defaults, storageKey: "calibration")
        XCTAssertEqual(reloaded.calibration(for: .swipeRight).preset, .responsive)
        XCTAssertEqual(reloaded.calibration(for: .swipeRight).sensitivity, 1.35)
        XCTAssertEqual(reloaded.calibration(for: .tap).preset, .custom)
        XCTAssertEqual(reloaded.calibration(for: .tap).sensitivity, 1.7)
        XCTAssertEqual(reloaded.calibration(for: .tap).confidenceThreshold, 0.35)
    }

    func testResponsivePresetAcceptsShorterSwipeThanConservativePreset() {
        let frames = shortSwipeFrames()
        var responsive = AdvancedGestureEngine(
            configuration: GestureRecognizerConfiguration(
                calibrations: GestureCalibrationSet(values: [
                    .swipeRight: GestureCalibrationPreset.responsive.calibration(for: .swipeRight)
                ])
            )
        )
        var conservative = AdvancedGestureEngine(
            configuration: GestureRecognizerConfiguration(
                calibrations: GestureCalibrationSet(values: [
                    .swipeRight: GestureCalibrationPreset.conservative.calibration(for: .swipeRight)
                ])
            )
        )

        let responsiveEvents = frames.compactMap { responsive.process($0).event }
        let conservativeEvents = frames.compactMap { conservative.process($0).event }

        XCTAssertEqual(responsiveEvents.map(\.kind), [.swipeRight])
        XCTAssertTrue(conservativeEvents.isEmpty)
    }

    func testVelocityCalibrationRejectsCandidateWithExplanation() throws {
        var calibration = GestureCalibrationPreset.responsive.calibration(for: .swipeRight)
        calibration.minimumVelocity = 2
        let configuration = GestureRecognizerConfiguration(
            calibrations: GestureCalibrationSet(values: [.swipeRight: calibration])
        )
        var engine = AdvancedGestureEngine(configuration: configuration)
        var finalSnapshot: TrackpadLaboratorySnapshot?

        for frame in shortSwipeFrames() {
            finalSnapshot = engine.process(frame).laboratorySnapshot
        }

        let diagnostic = try XCTUnwrap(finalSnapshot?.diagnostic)
        XCTAssertEqual(diagnostic.outcome, .rejected)
        XCTAssertTrue(diagnostic.reasons.joined().contains("velocidade"))
        XCTAssertTrue(diagnostic.reasons.joined().contains("abaixo do mínimo"))
    }

    func testAdvancedRegionsContainExpectedPoints() {
        XCTAssertTrue(TrackpadRegion.topEdge.contains(TrackpadPoint(x: 0.5, y: 0.9)))
        XCTAssertFalse(TrackpadRegion.topEdge.contains(TrackpadPoint(x: 0.5, y: 0.7)))
        XCTAssertTrue(TrackpadRegion.cornerBottomRight.contains(TrackpadPoint(x: 0.9, y: 0.1)))
        XCTAssertTrue(TrackpadRegion.gridCenter.contains(TrackpadPoint(x: 0.5, y: 0.5)))
        XCTAssertFalse(TrackpadRegion.gridCenter.contains(TrackpadPoint(x: 0.8, y: 0.5)))
        XCTAssertTrue(TrackpadRegion.topLeft.contains(TrackpadPoint(x: 0.2, y: 0.7)))
    }

    func testMatcherUsesStartAndEndPositionsForAdvancedRegions() {
        let event = GestureEvent(
            sessionID: UUID(),
            kind: .swipeRight,
            phase: .ended,
            fingerCount: 3,
            startRegion: .topLeft,
            endRegion: .topRight,
            startPosition: TrackpadPoint(x: 0.05, y: 0.95),
            endPosition: TrackpadPoint(x: 0.95, y: 0.5),
            velocity: 1,
            confidence: 0.9,
            occurredAt: Date()
        )
        let spec = TrackpadTriggerSpec(
            gesture: .swipeRight,
            fingerCount: 3...3,
            startRegion: .cornerTopLeft,
            endRegion: .rightEdge
        )

        XCTAssertTrue(
            TriggerMatcher().matches(.trackpad(spec: spec), event: .trackpad(event))
        )
    }

    func testSessionRecorderAnonymizesDeviceAndRoundTripsJSON() throws {
        let recorder = TrackpadSessionRecorder()
        recorder.start(name: "Teste real")
        recorder.append(
            RawTrackpadFrame(
                touches: [touch(id: 1, x: 0.2, y: 0.3)],
                deviceTimestamp: 1,
                frameNumber: 1,
                receivedAt: Date(timeIntervalSince1970: 100),
                deviceID: "private-hardware-id"
            )
        )

        let document = try XCTUnwrap(recorder.stop())
        XCTAssertEqual(document.frames.first?.deviceID, "recorded-device")
        let decoded = try ReplayFrameProvider(data: ReplayFrameProvider.encode(document)).document
        XCTAssertEqual(decoded.version, document.version)
        XCTAssertEqual(decoded.name, document.name)
        XCTAssertEqual(decoded.frames, document.frames)
        XCTAssertEqual(
            try XCTUnwrap(decoded.createdAt).timeIntervalSince1970,
            try XCTUnwrap(document.createdAt).timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func testValidationStorePersistsCountsAndFalsePositives() throws {
        let defaults = makeDefaults()
        let store = TrackpadValidationStore(defaults: defaults, storageKey: "validation")
        let event = GestureEvent(
            sessionID: UUID(),
            kind: .tap,
            phase: .ended,
            fingerCount: 3,
            startRegion: .topLeft,
            endRegion: .topLeft,
            confidence: 0.9,
            occurredAt: Date()
        )
        let snapshot = try acceptedSnapshot(event: event)

        store.record(snapshot, acceptedEvent: event)
        store.markLastRecognitionAsFalsePositive()
        store.setCheck(.internalTrackpad, completed: true)

        let reloaded = TrackpadValidationStore(defaults: defaults, storageKey: "validation")
        XCTAssertEqual(reloaded.report.recognizedByGesture[.tap], 1)
        XCTAssertEqual(reloaded.report.falsePositivesByGesture[.tap], 1)
        XCTAssertEqual(reloaded.report.falsePositiveRate, 1)
        XCTAssertTrue(reloaded.report.completedChecks.contains(.internalTrackpad))
    }

    @MainActor
    func testServiceRecordsAndReplaysWithoutExecutingRulesFromReplay() async throws {
        let provider = ManualTrackpadFrameProvider()
        let defaults = makeDefaults()
        let validation = TrackpadValidationStore(defaults: defaults, storageKey: "service-validation")
        let service = TrackpadGestureService(
            providerFactory: { provider },
            calibrationSet: GestureCalibrationSet(values: [
                .swipeRight: GestureCalibrationPreset.responsive.calibration(for: .swipeRight)
            ]),
            validationStore: validation
        )
        var actionLog: [InputEventDescriptor] = []
        service.start { actionLog.append($0) }
        service.startSessionRecording(name: "Integração")

        for frame in shortSwipeFrames() {
            provider.emit(frame)
        }
        try await waitUntil { actionLog.count == 1 }

        let document = try XCTUnwrap(service.stopSessionRecording())
        XCTAssertEqual(document.frames.count, 3)
        XCTAssertEqual(actionLog.map(\.gesture), [.swipeRight])

        for speed in [0.5, 1.0, 2.0] {
            let actionLogBeforeReplay = actionLog
            service.replay(document, speed: speed)
            try await waitUntil { !service.isReplaying && service.replayProgress == 1 }

            XCTAssertEqual(service.replayProgress, 1, accuracy: 0.001)
            XCTAssertEqual(service.laboratorySnapshot?.phase, .ended)
            XCTAssertEqual(service.laboratorySnapshot?.diagnostic.outcome, .accepted)
            XCTAssertEqual(service.latestGestureEvent?.kind, .swipeRight)
            XCTAssertEqual(
                actionLog,
                actionLogBeforeReplay,
                "Replay at \(speed)× must not execute the live rule/action handler"
            )
        }
        service.stop()
    }

    @MainActor
    func testSleepWakeRestartsProviderAndRecordsValidation() async throws {
        let provider = ManualTrackpadFrameProvider()
        let defaults = makeDefaults()
        let validation = TrackpadValidationStore(defaults: defaults, storageKey: "sleep-validation")
        let service = TrackpadGestureService(
            providerFactory: { provider },
            validationStore: validation
        )
        service.start { _ in }

        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        try await waitUntil { service.captureMode == .stopped }

        NSWorkspace.shared.notificationCenter.post(
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        try await waitUntil { service.captureMode == .advancedGlobal }

        XCTAssertGreaterThanOrEqual(provider.startCount, 2)
        XCTAssertTrue(validation.report.completedChecks.contains(.sleepWake))
        service.stop()
    }

    private func acceptedSnapshot(event: GestureEvent) throws -> TrackpadLaboratorySnapshot {
        var engine = AdvancedGestureEngine()
        let start = Date(timeIntervalSince1970: 200)
        _ = engine.process(frame(
            at: start,
            number: 1,
            touches: [
                touch(id: 1, x: 0.2, y: 0.8),
                touch(id: 2, x: 0.25, y: 0.8),
                touch(id: 3, x: 0.3, y: 0.8)
            ]
        ))
        return try XCTUnwrap(
            engine.process(frame(
                at: start.addingTimeInterval(0.1),
                number: 2,
                touches: []
            )).laboratorySnapshot
        )
    }

    private func shortSwipeFrames() -> [RawTrackpadFrame] {
        let start = Date(timeIntervalSince1970: 300)
        let initial = [
            touch(id: 1, x: 0.3, y: 0.45),
            touch(id: 2, x: 0.35, y: 0.5),
            touch(id: 3, x: 0.4, y: 0.55)
        ]
        let moved = [
            touch(id: 1, x: 0.4, y: 0.45),
            touch(id: 2, x: 0.45, y: 0.5),
            touch(id: 3, x: 0.5, y: 0.55)
        ]
        return [
            frame(at: start, number: 1, touches: initial),
            frame(at: start.addingTimeInterval(0.2), number: 2, touches: moved),
            frame(at: start.addingTimeInterval(0.25), number: 3, touches: [])
        ]
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
            receivedAt: date
        )
    }

    private func touch(id: Int32, x: Double, y: Double) -> RawTrackpadTouch {
        RawTrackpadTouch(
            identifier: id,
            state: 4,
            position: TrackpadPoint(x: x, y: y),
            velocity: TrackpadPoint(x: 0, y: 0),
            pressure: 0.5
        )
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "TrackpadLaboratoryPhaseOneTests-\(UUID().uuidString)"
        suites.append(suite)
        UserDefaults.standard.removePersistentDomain(forName: suite)
        return UserDefaults(suiteName: suite)!
    }

    @MainActor
    private func waitUntil(
        timeout: TimeInterval = 1,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() >= deadline {
                XCTFail("Timed out waiting for asynchronous condition")
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}

private final class ManualTrackpadFrameProvider: TrackpadFrameProvider, @unchecked Sendable {
    let capabilities = TrackpadProviderCapabilities.replay
    private(set) var isRunning = false
    private(set) var startCount = 0
    private var handler: (@Sendable (RawTrackpadFrame) -> Void)?

    func start(onFrame: @escaping @Sendable (RawTrackpadFrame) -> Void) throws {
        handler = onFrame
        isRunning = true
        startCount += 1
    }

    func stop() {
        handler = nil
        isRunning = false
    }

    func emit(_ frame: RawTrackpadFrame) {
        handler?(frame)
    }
}
