import Foundation
import XCTest
@testable import Tico

final class CustomGesturePathTests: XCTestCase {
    func testTrainingNormalizesTranslationAndScale() throws {
        let template = try CustomGesturePath.train(
            name: "L",
            from: [
                event(path: lPath()),
                event(path: lPath().map { TrackpadPoint(x: $0.x * 0.7 + 0.1, y: $0.y * 0.7 + 0.2) }),
                event(path: lPath().map { TrackpadPoint(x: $0.x * 0.5 + 0.3, y: $0.y * 0.5 + 0.1) })
            ]
        )

        XCTAssertEqual(template.samplePaths.count, 3)
        XCTAssertEqual(template.representativePath.count, CustomGestureTemplate.defaultPointCount)
        XCTAssertTrue(
            CustomGesturePath.matches(
                lPath().map { TrackpadPoint(x: $0.x * 0.6 + 0.2, y: $0.y * 0.6 + 0.25) },
                template: template
            )
        )
    }

    func testMatcherRejectsDifferentTrajectoryAndFingerCount() throws {
        let template = try CustomGesturePath.train(
            name: "L",
            from: [event(path: lPath()), event(path: lPath()), event(path: lPath())]
        )
        let trigger = TriggerDefinition.customTrackpad(template: template)
        let matcher = TriggerMatcher()

        XCTAssertTrue(matcher.matches(trigger, event: event(path: lPath())))
        XCTAssertFalse(matcher.matches(trigger, event: event(path: lPath(), fingerCount: 4)))
        XCTAssertFalse(matcher.matches(trigger, event: event(path: Array(lPath().reversed()))))
    }

    func testTrainingRequiresThreeConsistentSamples() {
        XCTAssertThrowsError(
            try CustomGesturePath.train(
                name: "Poucas",
                from: [event(path: lPath()), event(path: lPath())]
            )
        ) { error in
            XCTAssertEqual(
                error as? CustomGestureTrainingError,
                .insufficientSamples(required: CustomGestureTemplate.minimumSampleCount)
            )
        }

        XCTAssertThrowsError(
            try CustomGesturePath.train(
                name: "Dedos diferentes",
                from: [
                    event(path: lPath()),
                    event(path: lPath()),
                    event(path: lPath(), fingerCount: 4)
                ]
            )
        ) { error in
            XCTAssertEqual(error as? CustomGestureTrainingError, .inconsistentFingerCount)
        }
    }

    private func event(
        path: [TrackpadPoint],
        fingerCount: Int = 3
    ) -> InputEventDescriptor {
        InputEventDescriptor(
            kind: .trackpadGesture,
            fingerCount: fingerCount,
            trackpadRegion: .bottomLeft,
            trackpadPath: path
        )
    }

    private func lPath() -> [TrackpadPoint] {
        [
            TrackpadPoint(x: 0.1, y: 0.8),
            TrackpadPoint(x: 0.1, y: 0.5),
            TrackpadPoint(x: 0.1, y: 0.2),
            TrackpadPoint(x: 0.4, y: 0.2),
            TrackpadPoint(x: 0.8, y: 0.2)
        ]
    }
}
