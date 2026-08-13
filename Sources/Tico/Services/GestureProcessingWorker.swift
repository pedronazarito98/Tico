import Foundation

/// All mutable engine configuration and processing state is accessed only from
/// `queue`; public methods enqueue work and never expose the engine itself.
final class GestureProcessingWorker: @unchecked Sendable {
    private let queue = DispatchQueue(
        label: "com.pedronazarito.Tico.gesture-processing",
        qos: .userInteractive
    )
    private var engine = AdvancedGestureEngine()
    private var calibrationSet = GestureCalibrationSet()
    private var emitsContinuousPhases = false

    func process(
        _ frame: RawTrackpadFrame,
        completion: @escaping @Sendable (GestureProcessingOutput) -> Void
    ) {
        queue.async { [self] in
            completion(engine.process(frame))
        }
    }

    func process(_ frame: RawTrackpadFrame) async -> GestureProcessingOutput {
        await withCheckedContinuation { continuation in
            process(frame) { output in
                continuation.resume(returning: output)
            }
        }
    }

    func cancel(
        at date: Date = Date(),
        completion: (@Sendable (GestureProcessingOutput) -> Void)? = nil
    ) {
        queue.async { [self] in
            let output = engine.cancel(at: date)
            completion?(output)
        }
    }

    func reset() {
        queue.async { [self] in
            engine.reset()
        }
    }

    func updateCalibration(_ calibrationSet: GestureCalibrationSet) {
        queue.async { [self] in
            self.calibrationSet = calibrationSet
            engine = AdvancedGestureEngine(
                configuration: GestureRecognizerConfiguration(
                    calibrations: calibrationSet,
                    emitsContinuousPhases: emitsContinuousPhases
                )
            )
        }
    }

    func setContinuousPhasesEnabled(_ isEnabled: Bool) {
        queue.async { [self] in
            guard emitsContinuousPhases != isEnabled else { return }
            emitsContinuousPhases = isEnabled
            engine = AdvancedGestureEngine(
                configuration: GestureRecognizerConfiguration(
                    calibrations: calibrationSet,
                    emitsContinuousPhases: isEnabled
                )
            )
        }
    }
}
