import Foundation
import XCTest
@testable import Tico

final class AdvancedGestureEngineTests: XCTestCase {
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
