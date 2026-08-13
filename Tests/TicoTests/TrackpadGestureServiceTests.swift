import Foundation
import XCTest
@testable import Tico

final class TrackpadGestureServiceTests: XCTestCase {
    private let timestamp = Date(timeIntervalSince1970: 123)

    func testClassifiesDominantSwipeAxis() {
        XCTAssertEqual(
            TrackpadGestureService.classifySwipe(deltaX: -1, deltaY: 0.2, timestamp: timestamp),
            .trackpad(.swipeLeft, timestamp: timestamp)
        )
        XCTAssertEqual(
            TrackpadGestureService.classifySwipe(deltaX: 0.1, deltaY: 1, timestamp: timestamp),
            .trackpad(.swipeUp, timestamp: timestamp)
        )
    }

    func testIgnoresTinySwipe() {
        XCTAssertNil(
            TrackpadGestureService.classifySwipe(deltaX: 0.001, deltaY: -0.001, timestamp: timestamp)
        )
    }

    func testClassifiesPinchDirectionAfterThreshold() {
        XCTAssertEqual(
            TrackpadGestureService.classifyMagnification(0.2, timestamp: timestamp),
            .trackpad(.pinchOut, timestamp: timestamp)
        )
        XCTAssertEqual(
            TrackpadGestureService.classifyMagnification(-0.2, timestamp: timestamp),
            .trackpad(.pinchIn, timestamp: timestamp)
        )
        XCTAssertNil(TrackpadGestureService.classifyMagnification(0.01, timestamp: timestamp))
    }

    func testClassifiesRotationDirectionAfterThreshold() {
        XCTAssertEqual(
            TrackpadGestureService.classifyRotation(3, timestamp: timestamp),
            .trackpad(.rotateCounterclockwise, timestamp: timestamp)
        )
        XCTAssertEqual(
            TrackpadGestureService.classifyRotation(-3, timestamp: timestamp),
            .trackpad(.rotateClockwise, timestamp: timestamp)
        )
        XCTAssertNil(TrackpadGestureService.classifyRotation(1, timestamp: timestamp))
    }

    @MainActor
    func testUnavailablePrivateProviderActivatesIdentifiablePublicFallback() {
        let provider = UnavailableTrackpadFrameProvider(
            reason: "Captura privada indisponível neste ambiente."
        )
        let service = TrackpadGestureService(providerFactory: { provider })

        service.start { _ in }

        XCTAssertEqual(provider.startCount, 1)
        XCTAssertEqual(service.captureMode, .systemGestureFallback)
        XCTAssertEqual(
            service.startupError,
            "Captura privada indisponível neste ambiente."
        )
        XCTAssertTrue(service.isRunning)
        service.stop()
    }

    @MainActor
    func testPublicFallbackDoesNotMonitorKeyboardOrMouseEvents() {
        let supportedSystemGestures: NSEvent.EventTypeMask = [.magnify, .rotate, .swipe]

        XCTAssertEqual(
            TrackpadGestureService.fallbackEventMask,
            supportedSystemGestures,
            """
            The public fallback must observe only supported system gestures. \
            Any additional mask could monitor original keyboard, pointer movement, \
            mouse button, drag, or scroll input.
            """
        )
    }

    @MainActor
    func testUnclassifiedTrajectoryIsDeliveredToTriggerRecorderPipeline() async {
        let start = Date(timeIntervalSince1970: 200)
        let centroids = [
            TrackpadPoint(x: 0.25, y: 0.25),
            TrackpadPoint(x: 0.70, y: 0.25),
            TrackpadPoint(x: 0.70, y: 0.70),
            TrackpadPoint(x: 0.25, y: 0.70),
            TrackpadPoint(x: 0.25, y: 0.25)
        ]
        var frames = centroids.enumerated().map { index, centroid in
            RawTrackpadFrame(
                touches: [
                    touch(id: 1, centroid: centroid, offsetX: -0.04),
                    touch(id: 2, centroid: centroid, offsetX: 0),
                    touch(id: 3, centroid: centroid, offsetX: 0.04)
                ],
                deviceTimestamp: Double(index) * 0.1,
                frameNumber: Int32(index + 1),
                receivedAt: start.addingTimeInterval(Double(index) * 0.1),
                deviceID: "replay"
            )
        }
        frames.append(
            RawTrackpadFrame(
                touches: [],
                deviceTimestamp: 0.5,
                frameNumber: 6,
                receivedAt: start.addingTimeInterval(0.5),
                deviceID: "replay"
            )
        )
        let provider = ReplayFrameProvider(
            document: TrackpadReplayDocument(name: "Trajetória livre", frames: frames),
            playbackSpeed: 100
        )
        let service = TrackpadGestureService(providerFactory: { provider })
        let received = expectation(description: "Trajetória entregue")
        var descriptor: InputEventDescriptor?

        service.start { event in
            descriptor = event
            received.fulfill()
        }

        await fulfillment(of: [received], timeout: 1)
        service.stop()

        XCTAssertNil(descriptor?.gesture)
        XCTAssertEqual(descriptor?.fingerCount, 3)
        XCTAssertGreaterThanOrEqual(descriptor?.trackpadPath.count ?? 0, 5)
    }

    private func touch(
        id: Int32,
        centroid: TrackpadPoint,
        offsetX: Double
    ) -> RawTrackpadTouch {
        RawTrackpadTouch(
            identifier: id,
            state: 4,
            position: TrackpadPoint(x: centroid.x + offsetX, y: centroid.y),
            velocity: TrackpadPoint(x: 0, y: 0),
            pressure: 0.5
        )
    }
}

private final class UnavailableTrackpadFrameProvider: TrackpadFrameProvider {
    let capabilities = TrackpadProviderCapabilities.privateMultitouch
    private(set) var isRunning = false
    private(set) var startCount = 0
    private let reason: String

    init(reason: String) {
        self.reason = reason
    }

    func start(onFrame: @escaping @Sendable (RawTrackpadFrame) -> Void) throws {
        startCount += 1
        throw TrackpadFrameProviderError.unavailable(reason)
    }

    func stop() {
        isRunning = false
    }
}
