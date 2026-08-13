import Foundation

struct GestureRecognizerConfiguration: Sendable {
    var tapMaximumDuration: TimeInterval = 0.32
    var holdMinimumDuration: TimeInterval = 0.65
    var stationaryDistance: Double = 0.045
    var swipeMinimumDistance: Double = 0.12
    var pinchMinimumChange: Double = 0.18
    var rotationMinimumRadians: Double = .pi / 9
    var calibrations = GestureCalibrationSet()
    var emitsContinuousPhases = false

    func calibration(for gesture: TrackpadGesture) -> GestureCalibration {
        calibrations.calibration(for: gesture)
    }

    func scaledMinimum(_ value: Double, for gesture: TrackpadGesture) -> Double {
        value / calibration(for: gesture).sensitivity
    }
}

protocol GestureCandidateRecognizing {
    func candidates(for features: GestureFeatures) -> [GestureCandidate]
}

struct TapHoldGestureRecognizer: GestureCandidateRecognizing {
    let configuration: GestureRecognizerConfiguration

    func candidates(for features: GestureFeatures) -> [GestureCandidate] {
        guard features.maximumFingerCount >= 2 else { return [] }
        let tapCalibration = configuration.calibration(for: .tap)
        let tapMaximumDuration = configuration.tapMaximumDuration * tapCalibration.sensitivity
        let tapStationaryDistance = configuration.stationaryDistance * tapCalibration.sensitivity
        let pinchFloor = min(
            configuration.scaledMinimum(configuration.pinchMinimumChange, for: .pinchIn),
            configuration.scaledMinimum(configuration.pinchMinimumChange, for: .pinchOut)
        )
        let rotationFloor = min(
            configuration.scaledMinimum(configuration.rotationMinimumRadians, for: .rotateClockwise),
            configuration.scaledMinimum(
                configuration.rotationMinimumRadians,
                for: .rotateCounterclockwise
            )
        )

        if features.phase == .ended,
           features.duration <= tapMaximumDuration,
           features.distance <= tapStationaryDistance,
           abs(features.relativeSpanChange) < pinchFloor,
           abs(features.rotation) < rotationFloor {
            let durationFit = 1 - features.duration / tapMaximumDuration
            let distanceFit = 1 - features.distance / tapStationaryDistance
            return [
                GestureCandidate(
                    kind: .tap,
                    phase: .ended,
                    confidence: min(max(0.55 + 0.2 * durationFit + 0.2 * distanceFit, 0), 0.99),
                    recognizer: .tapHold,
                    evidence: "duração e deslocamento compatíveis com toque",
                    priority: 40
                )
            ]
        }

        let holdCalibration = configuration.calibration(for: .hold)
        if features.phase == .changed,
           features.duration >= configuration.holdMinimumDuration / holdCalibration.sensitivity,
           features.distance <= configuration.stationaryDistance * holdCalibration.sensitivity,
           abs(features.relativeSpanChange) < pinchFloor {
            return [
                GestureCandidate(
                    kind: .hold,
                    phase: .began,
                    confidence: 0.92,
                    recognizer: .tapHold,
                    evidence: "contatos estacionários além do limiar de segurar",
                    priority: 40
                )
            ]
        }

        return []
    }
}

struct DirectionalGestureRecognizer: GestureCandidateRecognizing {
    let configuration: GestureRecognizerConfiguration

    func candidates(for features: GestureFeatures) -> [GestureCandidate] {
        guard (
            features.phase == .ended
                || (features.phase == .changed && configuration.emitsContinuousPhases)
        ),
              features.maximumFingerCount >= 2 else { return [] }
        let gesture: TrackpadGesture
        if abs(features.displacement.x) > abs(features.displacement.y) {
            gesture = features.displacement.x > 0 ? .swipeRight : .swipeLeft
        } else {
            gesture = features.displacement.y > 0 ? .swipeUp : .swipeDown
        }
        let minimumDistance = configuration.scaledMinimum(
            configuration.swipeMinimumDistance,
            for: gesture
        )
        let score = features.distance / minimumDistance
        guard score >= 1 else { return [] }
        return [
            GestureCandidate(
                kind: gesture,
                phase: features.phase == .changed ? .began : .ended,
                confidence: score / (score + 1),
                recognizer: .directional,
                evidence: "deslocamento \(Self.format(features.distance))",
                priority: 10
            )
        ]
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}

struct PinchRotationRecognizer: GestureCandidateRecognizing {
    let configuration: GestureRecognizerConfiguration

    func candidates(for features: GestureFeatures) -> [GestureCandidate] {
        guard (
            features.phase == .ended
                || (features.phase == .changed && configuration.emitsContinuousPhases)
        ),
              features.maximumFingerCount >= 2 else { return [] }
        var result: [GestureCandidate] = []
        let pinchGesture: TrackpadGesture = features.relativeSpanChange > 0 ? .pinchOut : .pinchIn
        let pinchScore = abs(features.relativeSpanChange) / configuration.scaledMinimum(
            configuration.pinchMinimumChange,
            for: pinchGesture
        )
        if pinchScore >= 1 {
            result.append(
                GestureCandidate(
                    kind: pinchGesture,
                    phase: features.phase == .changed ? .began : .ended,
                    confidence: pinchScore / (pinchScore + 1),
                    recognizer: .pinchRotation,
                    evidence: "variação relativa de abertura \(Self.format(features.relativeSpanChange))",
                    priority: 20
                )
            )
        }

        let rotationGesture: TrackpadGesture = features.rotation > 0
            ? .rotateCounterclockwise
            : .rotateClockwise
        let rotationScore = abs(features.rotation) / configuration.scaledMinimum(
            configuration.rotationMinimumRadians,
            for: rotationGesture
        )
        if rotationScore >= 1 {
            result.append(
                GestureCandidate(
                    kind: rotationGesture,
                    phase: features.phase == .changed ? .began : .ended,
                    confidence: rotationScore / (rotationScore + 1),
                    recognizer: .pinchRotation,
                    evidence: "rotação acumulada \(Self.format(features.rotation)) rad",
                    priority: 30
                )
            )
        }
        return result
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}
