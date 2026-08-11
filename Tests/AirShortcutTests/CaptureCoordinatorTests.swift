import Foundation
import XCTest
@testable import AirShortcut

@MainActor
final class CaptureCoordinatorTests: XCTestCase {
    func testStartIsIdempotentAndDoesNotInstallTwoGlobalTaps() {
        let eventTap = FakeGlobalEventTap()
        let coordinator = makeCoordinator(eventTap: eventTap)

        XCTAssertEqual(coordinator.startCapture(), .started)
        XCTAssertEqual(coordinator.startCapture(), .started)

        XCTAssertEqual(eventTap.startCount, 1)
        XCTAssertTrue(coordinator.isRunning)

        coordinator.stopCapture()
        coordinator.stopCapture()

        XCTAssertFalse(coordinator.isRunning)
    }

    func testDelayedCallbackFromPreviousGenerationCannotStopNewCapture() async {
        let eventTap = FakeGlobalEventTap()
        let coordinator = makeCoordinator(eventTap: eventTap)

        XCTAssertEqual(coordinator.startCapture(), .started)
        coordinator.stopCapture()
        if case .started = coordinator.startCapture() {
            XCTFail("A restart cannot report success while the previous tap is still stopping")
        }
        eventTap.emitState(false, forStartAt: 0)
        await Task.yield()
        XCTAssertEqual(coordinator.startCapture(), .started)

        eventTap.emitState(false, forStartAt: 0)
        await Task.yield()

        XCTAssertTrue(coordinator.isRunning)
        XCTAssertEqual(eventTap.startCount, 2)
    }

    func testEventsFromStoppedOrPreviousCaptureAreIgnored() async {
        let eventTap = FakeGlobalEventTap()
        let coordinator = makeCoordinator(eventTap: eventTap)
        var received: [InputEventDescriptor] = []
        coordinator.setEventHandler { received.append($0) }
        let event = InputEventDescriptor.keyboard(
            keyCode: 12,
            modifiers: [],
            timestamp: Date(timeIntervalSince1970: 42)
        )

        XCTAssertEqual(coordinator.startCapture(), .started)
        coordinator.stopCapture()
        eventTap.emitEvent(event, forStartAt: 0)
        await Task.yield()
        XCTAssertTrue(received.isEmpty)

        eventTap.emitState(false, forStartAt: 0)
        await Task.yield()
        XCTAssertEqual(coordinator.startCapture(), .started)
        eventTap.emitEvent(event, forStartAt: 0)
        eventTap.emitEvent(event, forStartAt: 1)
        await Task.yield()

        XCTAssertEqual(received, [event])
    }

    private func makeCoordinator(eventTap: FakeGlobalEventTap) -> CaptureCoordinator {
        let permissions = PermissionCoordinator(
            accessibilityCheck: { true },
            inputMonitoringCheck: { .granted },
            settingsOpener: { _ in }
        )
        let trackpadGestures = TrackpadGestureService(
            providerFactory: { IdleTrackpadFrameProvider() }
        )
        return CaptureCoordinator(
            globalEventTap: eventTap,
            trackpadGestures: trackpadGestures,
            permissions: permissions,
            hardwareDetector: TrackpadHardwareDetector(),
            detectHardware: { [] }
        )
    }
}

@MainActor
private final class FakeGlobalEventTap: GlobalEventTapping {
    private var eventHandlers: [(InputEventDescriptor) -> Void] = []
    private var stateHandlers: [(Bool) -> Void] = []
    private let stopLeavesRunning: Bool

    private(set) var isRunning = false
    private(set) var startCount = 0

    init(stopLeavesRunning: Bool = true) {
        self.stopLeavesRunning = stopLeavesRunning
    }

    func start(
        onEvent: @escaping (InputEventDescriptor) -> Void,
        onStateChange: ((Bool) -> Void)?
    ) throws {
        eventHandlers.append(onEvent)
        stateHandlers.append(onStateChange ?? { _ in })
        startCount += 1
        isRunning = true
        onStateChange?(true)
    }

    func stop() {
        if !stopLeavesRunning {
            isRunning = false
        }
    }

    func emitState(_ state: Bool, forStartAt index: Int) {
        guard stateHandlers.indices.contains(index) else { return }
        isRunning = state
        stateHandlers[index](state)
    }

    func emitEvent(_ event: InputEventDescriptor, forStartAt index: Int) {
        guard eventHandlers.indices.contains(index) else { return }
        eventHandlers[index](event)
    }
}

private final class IdleTrackpadFrameProvider: TrackpadFrameProvider {
    let capabilities = TrackpadProviderCapabilities.privateMultitouch
    private(set) var isRunning = false

    func start(onFrame: @escaping @Sendable (RawTrackpadFrame) -> Void) throws {
        isRunning = true
    }

    func stop() {
        isRunning = false
    }
}
