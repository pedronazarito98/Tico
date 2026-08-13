import Foundation

/// Compatibility adapter for callers that still consume discrete
/// `InputEventDescriptor` values. New recognition happens in
/// `AdvancedGestureEngine` and produces semantic `GestureEvent` values first.
struct AdvancedTrackpadRecognizer {
    struct Configuration: Sendable {
        var tapMaximumDuration: TimeInterval = 0.32
        var holdMinimumDuration: TimeInterval = 0.65
        var stationaryDistance: Double = 0.045
        var swipeMinimumDistance: Double = 0.12
        var pinchMinimumChange: Double = 0.18
        var rotationMinimumRadians: Double = .pi / 9
    }

    private var engine: AdvancedGestureEngine

    init(configuration: Configuration = Configuration()) {
        engine = AdvancedGestureEngine(
            configuration: GestureRecognizerConfiguration(
                tapMaximumDuration: configuration.tapMaximumDuration,
                holdMinimumDuration: configuration.holdMinimumDuration,
                stationaryDistance: configuration.stationaryDistance,
                swipeMinimumDistance: configuration.swipeMinimumDistance,
                pinchMinimumChange: configuration.pinchMinimumChange,
                rotationMinimumRadians: configuration.rotationMinimumRadians
            )
        )
    }

    mutating func process(_ frame: RawTrackpadFrame) -> InputEventDescriptor? {
        guard let event = engine.process(frame).event,
              event.phase == .began || event.phase == .ended else {
            return nil
        }
        return .trackpad(event)
    }

    mutating func reset() {
        engine.reset()
    }
}
