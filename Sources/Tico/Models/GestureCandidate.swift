import Foundation

enum GestureRecognizerKind: String, Codable, Sendable {
    case tapHold
    case directional
    case pinchRotation
    case advancedFinger
}

struct GestureCandidate: Equatable, Sendable {
    let kind: TrackpadGesture
    let phase: GesturePhase
    let confidence: Double
    let recognizer: GestureRecognizerKind
    let evidence: String
    let priority: Int
    var advanced: AdvancedGestureMetadata? = nil
}

struct GestureArbitrationDecision: Equatable, Sendable {
    let accepted: GestureCandidate?
    let rejected: [GestureCandidate]
}
