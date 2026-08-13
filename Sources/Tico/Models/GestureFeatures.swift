import Foundation

struct GestureFeatures: Equatable, Sendable {
    let sessionID: UUID
    let phase: GesturePhase
    let occurredAt: Date
    let deviceID: String?
    let fingerCount: Int
    let maximumFingerCount: Int
    let initialFingerCount: Int
    let activeFingerCount: Int
    let duration: TimeInterval
    let sessionDuration: TimeInterval
    let startCentroid: TrackpadPoint
    let centroid: TrackpadPoint
    let centroidPath: [TrackpadPoint]
    let displacement: TrackpadPoint
    let distance: Double
    let startSpan: Double?
    let span: Double?
    let relativeSpanChange: Double
    let startAngle: Double?
    let angle: Double?
    let rotation: Double
    let velocity: Double
    let motionVelocity: Double
    let pressure: Double?
    let startRegion: TrackpadRegion
    let currentRegion: TrackpadRegion
    let contacts: [ContactState]
    let transitions: [ContactTransitionRecord]
}

struct TrackpadLaboratorySnapshot: Equatable, Sendable {
    let sessionID: UUID
    let phase: GesturePhase
    let contacts: [ContactState]
    let features: GestureFeatures
    let acceptedCandidate: GestureCandidate?
    let rejectedCandidates: [GestureCandidate]
    let diagnostic: GestureDiagnostic
}
