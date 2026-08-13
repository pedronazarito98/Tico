import Foundation
import XCTest
@testable import Tico

final class AdvancedTrackpadRecognizerTests: XCTestCase {
    private let origin = Date(timeIntervalSince1970: 1_000)

    func testRecognizesThreeFingerTapAndStartingRegion() throws {
        var recognizer = AdvancedTrackpadRecognizer()

        XCTAssertNil(recognizer.process(frame(at: 0, points: [
            (1, 0.15, 0.80), (2, 0.20, 0.82), (3, 0.25, 0.78)
        ])))
        let event = try XCTUnwrap(recognizer.process(frame(at: 0.12, points: [])))

        XCTAssertEqual(event.gesture, .tap)
        XCTAssertEqual(event.fingerCount, 3)
        XCTAssertEqual(event.trackpadRegion, .topLeft)
    }

    func testRecognizesFourFingerSwipe() throws {
        var recognizer = AdvancedTrackpadRecognizer()
        XCTAssertNil(recognizer.process(frame(at: 0, points: fourPoints(centerX: 0.25))))
        XCTAssertNil(recognizer.process(frame(at: 0.20, points: fourPoints(centerX: 0.65))))
        let event = try XCTUnwrap(recognizer.process(frame(at: 0.25, points: [])))

        XCTAssertEqual(event.gesture, .swipeRight)
        XCTAssertEqual(event.fingerCount, 4)
    }

    func testRecognizesPinchOut() throws {
        var recognizer = AdvancedTrackpadRecognizer()
        XCTAssertNil(recognizer.process(frame(at: 0, points: [
            (1, 0.45, 0.50), (2, 0.55, 0.50)
        ])))
        XCTAssertNil(recognizer.process(frame(at: 0.25, points: [
            (1, 0.25, 0.50), (2, 0.75, 0.50)
        ])))
        let event = try XCTUnwrap(recognizer.process(frame(at: 0.30, points: [])))

        XCTAssertEqual(event.gesture, .pinchOut)
        XCTAssertEqual(event.fingerCount, 2)
    }

    func testRecognizesCounterclockwiseRotation() throws {
        var recognizer = AdvancedTrackpadRecognizer()
        XCTAssertNil(recognizer.process(frame(at: 0, points: [
            (1, 0.40, 0.50), (2, 0.60, 0.50)
        ])))
        XCTAssertNil(recognizer.process(frame(at: 0.25, points: [
            (1, 0.50, 0.40), (2, 0.50, 0.60)
        ])))
        let event = try XCTUnwrap(recognizer.process(frame(at: 0.30, points: [])))

        XCTAssertEqual(event.gesture, .rotateCounterclockwise)
        XCTAssertEqual(event.fingerCount, 2)
    }

    func testHoldEmitsOnceBeforeFingersAreReleased() throws {
        var recognizer = AdvancedTrackpadRecognizer()
        let points: [(Int32, Double, Double)] = [
            (1, 0.20, 0.20),
            (2, 0.25, 0.20),
            (3, 0.30, 0.20)
        ]
        XCTAssertNil(recognizer.process(frame(at: 0, points: points)))
        let event = try XCTUnwrap(recognizer.process(frame(at: 0.70, points: points)))

        XCTAssertEqual(event.gesture, .hold)
        XCTAssertEqual(event.fingerCount, 3)
        XCTAssertNil(recognizer.process(frame(at: 0.80, points: points)))
        XCTAssertNil(recognizer.process(frame(at: 0.90, points: [])))
    }

    func testIgnoresSingleFingerPointerMovement() {
        var recognizer = AdvancedTrackpadRecognizer()
        XCTAssertNil(recognizer.process(frame(at: 0, points: [(1, 0.10, 0.10)])))
        XCTAssertNil(recognizer.process(frame(at: 0.20, points: [(1, 0.80, 0.10)])))
        XCTAssertNil(recognizer.process(frame(at: 0.25, points: [])))
    }

    private func fourPoints(centerX: Double) -> [(Int32, Double, Double)] {
        [
            (1, centerX - 0.06, 0.46),
            (2, centerX - 0.02, 0.54),
            (3, centerX + 0.02, 0.46),
            (4, centerX + 0.06, 0.54)
        ]
    }

    private func frame(
        at offset: TimeInterval,
        points: [(Int32, Double, Double)]
    ) -> RawTrackpadFrame {
        RawTrackpadFrame(
            touches: points.map { identifier, x, y in
                RawTrackpadTouch(
                    identifier: identifier,
                    state: 4,
                    position: TrackpadPoint(x: x, y: y),
                    velocity: TrackpadPoint(x: 0, y: 0),
                    pressure: 1
                )
            },
            deviceTimestamp: offset,
            frameNumber: Int32(offset * 100),
            receivedAt: origin.addingTimeInterval(offset)
        )
    }
}
