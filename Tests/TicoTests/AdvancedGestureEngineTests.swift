import Foundation
import XCTest
@testable import Tico

final class AdvancedGestureEngineTests: XCTestCase {
    // CAP-06.A: retornar ao início não torna o mesmo cohort estacionário novamente.
    func testTapAndHoldRejectAnyContactExcursionAfterReturnAndRest() throws {
        for isHold in [false, true] {
            var sessions = ContactSessionEngine()
            let start = Date(timeIntervalSince1970: 500)
            let original = [touch(id: 1, x: 0.25, y: 0.5), touch(id: 2, x: 0.75, y: 0.5)]
            _ = sessions.process(frame(at: start, number: 1, touches: original))
            _ = sessions.process(frame(at: start.addingTimeInterval(0.05), number: 2,
                touches: [touch(id: 1, x: 0.35, y: 0.5), original[1]]))
            _ = sessions.process(frame(at: start.addingTimeInterval(0.1), number: 3, touches: original))
            let final = try XCTUnwrap(sessions.process(frame(
                at: start.addingTimeInterval(isHold ? 0.8 : 0.2), number: 4,
                touches: isHold ? original : [])))
            let features = try XCTUnwrap(GestureFeatureExtractor().extract(from: final))
            XCTAssertEqual(features.distance, 0, accuracy: 0.000001)
            XCTAssertTrue(TapHoldGestureRecognizer(configuration: .init()).candidates(for: features).isEmpty)
        }
    }

    // CAP-06.B: limite calibrado inclusivo, com duração e geometria válidas.
    func testTapAndHoldPreserveInclusiveStationaryLimit() throws {
        for isHold in [false, true] {
            for (excursion, accepted) in [(0.124, true), (0.125, true), (0.126, false)] {
                var sessions = ContactSessionEngine()
                var configuration = GestureRecognizerConfiguration()
                configuration.stationaryDistance = 0.125
                let start = Date(timeIntervalSince1970: 510)
                _ = sessions.process(frame(at: start, number: 1, touches: [
                    touch(id: 1, x: 0.25, y: 0.5), touch(id: 2, x: 0.5, y: 0.5)]))
                let moved = [touch(id: 1, x: 0.25 + excursion, y: 0.5),
                             touch(id: 2, x: 0.5 + excursion, y: 0.5)]
                _ = sessions.process(frame(at: start.addingTimeInterval(0.05), number: 2, touches: moved))
                let final = try XCTUnwrap(sessions.process(frame(
                    at: start.addingTimeInterval(isHold ? 0.8 : 0.2), number: 3,
                    touches: isHold ? moved : [])))
                let features = try XCTUnwrap(GestureFeatureExtractor().extract(from: final))
                let candidates = TapHoldGestureRecognizer(configuration: configuration).candidates(for: features)
                XCTAssertEqual(candidates.map(\.kind), accepted ? [isHold ? .hold : .tap] : [])
            }
        }
    }

    func testSequentialLiftsKeepCohortCentroidAndPathStable() throws {
        for firstRemoved in [Int32(1), Int32(2)] {
            var sessions = ContactSessionEngine()
            let start = Date(timeIntervalSince1970: 520)
            let points = [touch(id: 1, x: 0.2, y: 0.5), touch(id: 2, x: 0.8, y: 0.5)]
            _ = sessions.process(frame(at: start, number: 1, touches: points))
            let remaining = points.filter { $0.identifier != firstRemoved }
            let lifted = try XCTUnwrap(sessions.process(frame(at: start.addingTimeInterval(0.1), number: 2, touches: remaining)))
            let ended = try XCTUnwrap(sessions.process(frame(at: start.addingTimeInterval(0.2), number: 3, touches: [])))
            for session in [lifted, ended] {
                let features = try XCTUnwrap(GestureFeatureExtractor().extract(from: session))
                XCTAssertEqual(features.centroid, TrackpadPoint(x: 0.5, y: 0.5))
                XCTAssertEqual(features.centroidPath, [TrackpadPoint(x: 0.5, y: 0.5)])
                XCTAssertEqual(features.distance, 0)
            }
        }
    }

    func testRemainingContactUsesLastPositionOfLiftedContactAndEntryResetsCohort() throws {
        var sessions = ContactSessionEngine()
        let start = Date(timeIntervalSince1970: 530)
        _ = sessions.process(frame(at: start, number: 1, touches: [
            touch(id: 1, x: 0.2, y: 0.5), touch(id: 2, x: 0.8, y: 0.5)]))
        _ = sessions.process(frame(at: start.addingTimeInterval(0.1), number: 2,
            touches: [touch(id: 2, x: 0.8, y: 0.5)]))
        let moved = try XCTUnwrap(sessions.process(frame(at: start.addingTimeInterval(0.2), number: 3,
            touches: [touch(id: 2, x: 1, y: 0.5)])))
        let features = try XCTUnwrap(GestureFeatureExtractor().extract(from: moved))
        XCTAssertEqual(features.centroid, TrackpadPoint(x: 0.6, y: 0.5))
        XCTAssertEqual(features.centroidPath.last, features.centroid)
        let entered = try XCTUnwrap(sessions.process(frame(at: start.addingTimeInterval(0.3), number: 4,
            touches: [touch(id: 2, x: 1, y: 0.5), touch(id: 3, x: 0.5, y: 0.5)])))
        XCTAssertEqual(entered.cohortContactIDs, [2, 3])
        XCTAssertEqual(entered.cohortCentroidPath, [TrackpadPoint(x: 0.75, y: 0.5)])
        XCTAssertEqual(entered.maximumContactExcursion, 0)
    }

    func testContinuousPresentationDemandPreservesEventsAndTerminalDiagnostics() throws {
        var visible = AdvancedGestureEngine(configuration: GestureRecognizerConfiguration(emitsContinuousPhases: true))
        var hidden = visible
        let start = Date(timeIntervalSince1970: 540)
        var frames: [RawTrackpadFrame] = []
        for index in 0..<6 {
            let offset = Double(index) * 0.1
            let points: [RawTrackpadTouch] = index == 5 ? [] : [
                touch(id: 1, x: 0.2 + offset, y: 0.5),
                touch(id: 2, x: 0.4 + offset, y: 0.5)]
            frames.append(frame(at: start.addingTimeInterval(Double(index) * 0.05),
                number: Int32(index), touches: points))
        }
        var hiddenPhases: [GesturePhase] = []
        for frame in frames {
            let lhs = visible.process(frame, includeLaboratorySnapshot: true)
            let rhs = hidden.process(frame, includeLaboratorySnapshot: false)
            XCTAssertEqual(lhs.event?.kind, rhs.event?.kind)
            XCTAssertEqual(lhs.event?.phase, rhs.event?.phase)
            XCTAssertEqual(lhs.event?.progress, rhs.event?.progress)
            XCTAssertEqual(lhs.event?.path, rhs.event?.path)
            XCTAssertEqual(lhs.event?.confidence, rhs.event?.confidence)
            if let phase = rhs.event?.phase { hiddenPhases.append(phase) }
            if rhs.event?.phase == .changed {
                XCTAssertNil(rhs.laboratorySnapshot)
                XCTAssertNotNil(lhs.laboratorySnapshot)
            }
            if rhs.event?.phase == .ended {
                XCTAssertEqual(rhs.laboratorySnapshot?.phase, .ended)
                XCTAssertEqual(rhs.completedFeatures?.centroidPath, lhs.completedFeatures?.centroidPath)
                XCTAssertEqual(rhs.laboratorySnapshot?.diagnostic, lhs.laboratorySnapshot?.diagnostic)
            }
        }
        XCTAssertEqual(hiddenPhases, [.began, .changed, .changed, .ended])
    }

    func testContactSessionTracksFingerEntryWithoutEndingSession() throws {
        var engine = ContactSessionEngine()
        let start = Date(timeIntervalSince1970: 10)

        let began = try XCTUnwrap(engine.process(frame(
            at: start,
            number: 1,
            touches: [touch(id: 1, x: 0.2, y: 0.4), touch(id: 2, x: 0.3, y: 0.4)]
        )))
        let changed = try XCTUnwrap(engine.process(frame(
            at: start.addingTimeInterval(0.1),
            number: 2,
            touches: [
                touch(id: 1, x: 0.21, y: 0.4),
                touch(id: 2, x: 0.31, y: 0.4),
                touch(id: 3, x: 0.4, y: 0.4)
            ]
        )))

        XCTAssertEqual(changed.id, began.id)
        XCTAssertEqual(changed.phase, .changed)
        XCTAssertEqual(changed.maximumFingerCount, 3)
        XCTAssertEqual(changed.cohortContactIDs, [1, 2, 3])
        XCTAssertEqual(changed.cohortStartedAt, start.addingTimeInterval(0.1))
    }

    func testContactSessionEmitsUpAndCancelTransitions() throws {
        var engine = ContactSessionEngine()
        let start = Date(timeIntervalSince1970: 20)
        _ = engine.process(frame(
            at: start,
            number: 1,
            touches: [touch(id: 1, x: 0.2, y: 0.2), touch(id: 2, x: 0.4, y: 0.2)]
        ))
        let oneRemaining = try XCTUnwrap(engine.process(frame(
            at: start.addingTimeInterval(0.1),
            number: 2,
            touches: [touch(id: 2, x: 0.4, y: 0.2)]
        )))
        XCTAssertEqual(oneRemaining.contacts[1]?.transition, .up)

        let cancelled = try XCTUnwrap(engine.cancel(at: start.addingTimeInterval(0.2)))
        XCTAssertEqual(cancelled.phase, .cancelled)
        XCTAssertEqual(cancelled.contacts[2]?.transition, .cancel)
        XCTAssertFalse(engine.hasActiveSession)
    }

    func testFeatureExtractorComputesSemanticMeasurements() throws {
        var sessions = ContactSessionEngine()
        let extractor = GestureFeatureExtractor()
        let start = Date(timeIntervalSince1970: 30)
        _ = sessions.process(frame(
            at: start,
            number: 1,
            touches: [touch(id: 1, x: 0.1, y: 0.8), touch(id: 2, x: 0.3, y: 0.8)]
        ))
        let session = try XCTUnwrap(sessions.process(frame(
            at: start.addingTimeInterval(0.2),
            number: 2,
            touches: [
                touch(id: 1, x: 0.4, y: 0.8, pressure: 0.6),
                touch(id: 2, x: 0.6, y: 0.8, pressure: 0.8)
            ]
        )))
        let features = try XCTUnwrap(extractor.extract(from: session))

        XCTAssertEqual(features.distance, 0.3, accuracy: 0.0001)
        XCTAssertEqual(features.velocity, 1.5, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(features.pressure), 0.7, accuracy: 0.0001)
        XCTAssertEqual(features.startRegion, .topLeft)
        XCTAssertEqual(features.currentRegion, .topRight)
    }

    func testReplayFixtureRecognizesGestureDeterministically() throws {
        let fixtureURL = try XCTUnwrap(
            Bundle.module.url(
                forResource: "three-finger-swipe-right",
                withExtension: "json",
                subdirectory: "Fixtures"
            )
            ?? Bundle.module.url(forResource: "three-finger-swipe-right", withExtension: "json")
        )
        let provider = try ReplayFrameProvider(data: Data(contentsOf: fixtureURL))
        var engine = AdvancedGestureEngine()
        var events: [GestureEvent] = []

        provider.replaySynchronously { frame in
            if let event = engine.process(frame).event {
                events.append(event)
            }
        }

        XCTAssertEqual(events.map(\.kind), [.swipeRight])
        XCTAssertEqual(events.first?.fingerCount, 3)
        XCTAssertEqual(events.first?.deviceID, "replay-trackpad")
        XCTAssertEqual(events.first?.phase, .ended)
    }

    func testReplayCoversEveryExistingAdvancedGesture() {
        let cases: [(TrackpadGesture, [RawTrackpadFrame])] = [
            (.tap, tapFrames()),
            (.hold, holdFrames()),
            (.swipeLeft, swipeFrames(dx: -0.3, dy: 0)),
            (.swipeRight, swipeFrames(dx: 0.3, dy: 0)),
            (.swipeUp, swipeFrames(dx: 0, dy: 0.3)),
            (.swipeDown, swipeFrames(dx: 0, dy: -0.3)),
            (.pinchIn, pinchFrames(expandedFirst: true)),
            (.pinchOut, pinchFrames(expandedFirst: false)),
            (.rotateClockwise, rotationFrames(clockwise: true)),
            (.rotateCounterclockwise, rotationFrames(clockwise: false))
        ]

        for (expected, frames) in cases {
            let provider = ReplayFrameProvider(
                document: TrackpadReplayDocument(name: expected.rawValue, frames: frames)
            )
            var engine = AdvancedGestureEngine()
            var events: [GestureEvent] = []
            provider.replaySynchronously { frame in
                if let event = engine.process(frame).event {
                    events.append(event)
                }
            }
            XCTAssertEqual(events.map(\.kind), [expected], "Replay failed for \(expected.rawValue)")
        }
    }

    func testCommonSingleFingerMovementNeverEmitsGesture() {
        var engine = AdvancedGestureEngine()
        let start = Date(timeIntervalSince1970: 40)
        let frames = [
            frame(at: start, number: 1, touches: [touch(id: 1, x: 0.1, y: 0.1)]),
            frame(at: start.addingTimeInterval(0.1), number: 2, touches: [touch(id: 1, x: 0.8, y: 0.8)]),
            frame(at: start.addingTimeInterval(0.2), number: 3, touches: [])
        ]

        XCTAssertTrue(frames.allSatisfy { engine.process($0).event == nil })
    }

    func testArbiterUsesSpecificityToBreakEqualConfidence() {
        let candidates = [
            GestureCandidate(
                kind: .swipeRight,
                phase: .ended,
                confidence: 0.8,
                recognizer: .directional,
                evidence: "directional",
                priority: 10
            ),
            GestureCandidate(
                kind: .rotateCounterclockwise,
                phase: .ended,
                confidence: 0.8,
                recognizer: .pinchRotation,
                evidence: "rotation",
                priority: 30
            )
        ]

        let decision = GestureArbiter().decide(between: candidates)

        XCTAssertEqual(decision.accepted?.kind, .rotateCounterclockwise)
        XCTAssertEqual(decision.rejected.map(\.kind), [.swipeRight])
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
            deviceID: "test-device"
        )
    }

    private func touch(
        id: Int32,
        x: Double,
        y: Double,
        pressure: Double = 0.5
    ) -> RawTrackpadTouch {
        RawTrackpadTouch(
            identifier: id,
            state: 4,
            position: TrackpadPoint(x: x, y: y),
            velocity: TrackpadPoint(x: 0, y: 0),
            pressure: pressure
        )
    }

    private func tapFrames() -> [RawTrackpadFrame] {
        let start = Date(timeIntervalSince1970: 50)
        let points = [
            touch(id: 1, x: 0.2, y: 0.2),
            touch(id: 2, x: 0.3, y: 0.2),
            touch(id: 3, x: 0.4, y: 0.2)
        ]
        return [
            frame(at: start, number: 1, touches: points),
            frame(at: start.addingTimeInterval(0.12), number: 2, touches: [])
        ]
    }

    private func holdFrames() -> [RawTrackpadFrame] {
        let start = Date(timeIntervalSince1970: 60)
        let points = [
            touch(id: 1, x: 0.2, y: 0.2),
            touch(id: 2, x: 0.3, y: 0.2),
            touch(id: 3, x: 0.4, y: 0.2)
        ]
        return [
            frame(at: start, number: 1, touches: points),
            frame(at: start.addingTimeInterval(0.7), number: 2, touches: points),
            frame(at: start.addingTimeInterval(0.8), number: 3, touches: [])
        ]
    }

    private func swipeFrames(dx: Double, dy: Double) -> [RawTrackpadFrame] {
        let start = Date(timeIntervalSince1970: 70)
        let initial = [(0.35, 0.45), (0.4, 0.5), (0.45, 0.55)]
        return [
            frame(
                at: start,
                number: 1,
                touches: zip([Int32(1), 2, 3], initial).map {
                    touch(id: $0.0, x: $0.1.0, y: $0.1.1)
                }
            ),
            frame(
                at: start.addingTimeInterval(0.2),
                number: 2,
                touches: zip([Int32(1), 2, 3], initial).map {
                    touch(id: $0.0, x: $0.1.0 + dx, y: $0.1.1 + dy)
                }
            ),
            frame(at: start.addingTimeInterval(0.25), number: 3, touches: [])
        ]
    }

    private func pinchFrames(expandedFirst: Bool) -> [RawTrackpadFrame] {
        let start = Date(timeIntervalSince1970: 80)
        let expanded = [
            touch(id: 1, x: 0.25, y: 0.5),
            touch(id: 2, x: 0.75, y: 0.5)
        ]
        let contracted = [
            touch(id: 1, x: 0.45, y: 0.5),
            touch(id: 2, x: 0.55, y: 0.5)
        ]
        return [
            frame(at: start, number: 1, touches: expandedFirst ? expanded : contracted),
            frame(
                at: start.addingTimeInterval(0.2),
                number: 2,
                touches: expandedFirst ? contracted : expanded
            ),
            frame(at: start.addingTimeInterval(0.25), number: 3, touches: [])
        ]
    }

    private func rotationFrames(clockwise: Bool) -> [RawTrackpadFrame] {
        let start = Date(timeIntervalSince1970: 90)
        let horizontal = [
            touch(id: 1, x: 0.4, y: 0.5),
            touch(id: 2, x: 0.6, y: 0.5)
        ]
        let vertical = clockwise
            ? [touch(id: 1, x: 0.5, y: 0.6), touch(id: 2, x: 0.5, y: 0.4)]
            : [touch(id: 1, x: 0.5, y: 0.4), touch(id: 2, x: 0.5, y: 0.6)]
        return [
            frame(at: start, number: 1, touches: horizontal),
            frame(at: start.addingTimeInterval(0.2), number: 2, touches: vertical),
            frame(at: start.addingTimeInterval(0.25), number: 3, touches: [])
        ]
    }
}
