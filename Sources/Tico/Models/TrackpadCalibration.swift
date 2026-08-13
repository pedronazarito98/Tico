import Foundation

enum GestureCalibrationPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case conservative
    case balanced
    case responsive
    case custom

    var id: Self { self }
}

struct GestureCalibration: Codable, Equatable, Hashable, Sendable {
    var preset: GestureCalibrationPreset
    var sensitivity: Double
    var minimumVelocity: Double?
    var maximumVelocity: Double?
    var confidenceThreshold: Double

    init(
        preset: GestureCalibrationPreset = .balanced,
        sensitivity: Double = 1,
        minimumVelocity: Double? = nil,
        maximumVelocity: Double? = nil,
        confidenceThreshold: Double = 0.5
    ) {
        self.preset = preset
        self.sensitivity = min(max(sensitivity, 0.25), 2)
        self.minimumVelocity = minimumVelocity.map { max(0, $0) }
        self.maximumVelocity = maximumVelocity.map { max(0, $0) }
        self.confidenceThreshold = min(max(confidenceThreshold, 0.1), 0.95)
        normalizeVelocityRange()
    }

    mutating func normalizeVelocityRange() {
        if let minimumVelocity, let maximumVelocity, minimumVelocity > maximumVelocity {
            self.maximumVelocity = minimumVelocity
        }
    }
}

struct GestureCalibrationSet: Codable, Equatable, Sendable {
    var values: [TrackpadGesture: GestureCalibration]

    init(values: [TrackpadGesture: GestureCalibration] = [:]) {
        self.values = values
    }

    func calibration(for gesture: TrackpadGesture) -> GestureCalibration {
        values[gesture] ?? GestureCalibrationPreset.balanced.calibration(for: gesture)
    }
}

extension GestureCalibrationPreset {
    func calibration(for gesture: TrackpadGesture) -> GestureCalibration {
        let usesMotionVelocity: Bool
        switch gesture {
        case .swipeLeft, .swipeRight, .swipeUp, .swipeDown,
             .pinchIn, .pinchOut, .rotateClockwise, .rotateCounterclockwise:
            usesMotionVelocity = true
        case .tap, .hold, .tipTapLeft, .tipTapRight, .addFinger, .removeFinger,
             .fingerChord:
            usesMotionVelocity = false
        }

        switch self {
        case .conservative:
            return GestureCalibration(
                preset: self,
                sensitivity: 0.75,
                minimumVelocity: usesMotionVelocity ? 0.12 : nil,
                maximumVelocity: nil,
                confidenceThreshold: 0.64
            )
        case .balanced:
            return GestureCalibration(
                preset: self,
                sensitivity: 1,
                minimumVelocity: usesMotionVelocity ? 0.06 : nil,
                maximumVelocity: nil,
                confidenceThreshold: 0.5
            )
        case .responsive:
            return GestureCalibration(
                preset: self,
                sensitivity: 1.35,
                minimumVelocity: usesMotionVelocity ? 0.02 : nil,
                maximumVelocity: nil,
                confidenceThreshold: 0.4
            )
        case .custom:
            return GestureCalibration(preset: .custom)
        }
    }
}
