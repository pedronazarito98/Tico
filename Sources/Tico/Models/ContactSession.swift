import Foundation

enum ContactTransition: String, Codable, Sendable {
    case down
    case move
    case up
    case cancel
}

struct ContactState: Codable, Equatable, Sendable {
    let identifier: Int32
    var transition: ContactTransition
    let startedAt: Date
    var updatedAt: Date
    let startPosition: TrackpadPoint
    var position: TrackpadPoint
    var previousPosition: TrackpadPoint
    var velocity: TrackpadPoint
    var pressure: Double

    var duration: TimeInterval {
        updatedAt.timeIntervalSince(startedAt)
    }
}

struct ContactTransitionRecord: Equatable, Sendable {
    let identifier: Int32
    let transition: ContactTransition
    let occurredAt: Date
    let position: TrackpadPoint
}

struct ContactSessionSnapshot: Equatable, Sendable {
    let id: UUID
    var phase: GesturePhase
    let startedAt: Date
    var updatedAt: Date
    var deviceID: String?
    var contacts: [Int32: ContactState]
    var activeContactIDs: Set<Int32>
    var cohortContactIDs: Set<Int32>
    var cohortStartedAt: Date
    var cohortStartPositions: [Int32: TrackpadPoint]
    var cohortCentroidPath: [TrackpadPoint]
    var maximumFingerCount: Int
    var initialFingerCount: Int
    var transitionHistory: [ContactTransitionRecord]

    var activeContacts: [ContactState] {
        activeContactIDs.compactMap { contacts[$0] }
    }

    var cohortContacts: [ContactState] {
        cohortContactIDs.compactMap { contacts[$0] }
    }
}
