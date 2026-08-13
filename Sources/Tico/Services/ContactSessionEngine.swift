import Foundation

struct ContactSessionEngine {
    private var currentSession: ContactSessionSnapshot?

    var hasActiveSession: Bool {
        currentSession != nil
    }

    mutating func process(_ frame: RawTrackpadFrame) -> ContactSessionSnapshot? {
        let activeTouches = frame.touches
            .prefix(TrackpadReplayDocument.maximumTouchesPerFrame)
            .filter(\.isActivelyTouching)
        let activeByID = Dictionary(
            activeTouches.map { ($0.identifier, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        let activeIDs = Set(activeByID.keys)

        guard var session = currentSession else {
            guard !activeTouches.isEmpty else { return nil }
            let contacts = Dictionary(
                uniqueKeysWithValues: activeTouches.map { touch in
                    (
                        touch.identifier,
                        ContactState(
                            identifier: touch.identifier,
                            transition: .down,
                            startedAt: frame.receivedAt,
                            updatedAt: frame.receivedAt,
                            startPosition: touch.position,
                            position: touch.position,
                            previousPosition: touch.position,
                            velocity: touch.velocity,
                            pressure: touch.pressure
                        )
                    )
                }
            )
            let snapshot = ContactSessionSnapshot(
                id: UUID(),
                phase: .began,
                startedAt: frame.receivedAt,
                updatedAt: frame.receivedAt,
                deviceID: frame.deviceID,
                contacts: contacts,
                activeContactIDs: activeIDs,
                cohortContactIDs: activeIDs,
                cohortStartedAt: frame.receivedAt,
                cohortStartPositions: Dictionary(
                    uniqueKeysWithValues: activeTouches.map { ($0.identifier, $0.position) }
                ),
                cohortCentroidPath: [Self.centroid(of: activeTouches)],
                maximumFingerCount: activeTouches.count,
                initialFingerCount: activeTouches.count,
                transitionHistory: activeTouches.map {
                    ContactTransitionRecord(
                        identifier: $0.identifier,
                        transition: .down,
                        occurredAt: frame.receivedAt,
                        position: $0.position
                    )
                }
            )
            currentSession = snapshot
            return snapshot
        }

        let previousActiveIDs = session.activeContactIDs
        session.updatedAt = frame.receivedAt
        if session.deviceID == nil {
            session.deviceID = frame.deviceID
        }

        for identifier in previousActiveIDs.subtracting(activeIDs) {
            guard var contact = session.contacts[identifier] else { continue }
            contact.transition = .up
            contact.updatedAt = frame.receivedAt
            contact.previousPosition = contact.position
            session.contacts[identifier] = contact
            session.transitionHistory.append(
                ContactTransitionRecord(
                    identifier: identifier,
                    transition: .up,
                    occurredAt: frame.receivedAt,
                    position: contact.position
                )
            )
        }

        for touch in activeTouches {
            if var contact = session.contacts[touch.identifier] {
                contact.transition = .move
                contact.updatedAt = frame.receivedAt
                contact.previousPosition = contact.position
                contact.position = touch.position
                contact.velocity = touch.velocity
                contact.pressure = touch.pressure
                session.contacts[touch.identifier] = contact
            } else {
                session.contacts[touch.identifier] = ContactState(
                    identifier: touch.identifier,
                    transition: .down,
                    startedAt: frame.receivedAt,
                    updatedAt: frame.receivedAt,
                    startPosition: touch.position,
                    position: touch.position,
                    previousPosition: touch.position,
                    velocity: touch.velocity,
                    pressure: touch.pressure
                )
                session.transitionHistory.append(
                    ContactTransitionRecord(
                        identifier: touch.identifier,
                        transition: .down,
                        occurredAt: frame.receivedAt,
                        position: touch.position
                    )
                )
            }
        }

        if activeIDs.isEmpty {
            session.phase = .ended
            session.activeContactIDs = []
            currentSession = nil
            return session
        }

        session.phase = .changed
        session.activeContactIDs = activeIDs
        session.maximumFingerCount = max(session.maximumFingerCount, activeIDs.count)

        // A newly added contact starts a fresh recognition cohort so its
        // arrival is not mistaken for a centroid jump. Sequential finger lifts
        // keep the original cohort until the session ends.
        if !activeIDs.subtracting(previousActiveIDs).isEmpty {
            session.cohortContactIDs = activeIDs
            session.cohortStartedAt = frame.receivedAt
            session.cohortStartPositions = Dictionary(
                uniqueKeysWithValues: activeTouches.map { ($0.identifier, $0.position) }
            )
            session.cohortCentroidPath = [Self.centroid(of: activeTouches)]
        } else {
            let point = Self.centroid(of: activeTouches)
            if session.cohortCentroidPath.last?.distance(to: point) ?? .greatestFiniteMagnitude >= 0.002 {
                session.cohortCentroidPath.append(point)
            }
        }

        currentSession = session
        return session
    }

    mutating func cancel(at date: Date = Date()) -> ContactSessionSnapshot? {
        guard var session = currentSession else { return nil }
        session.phase = .cancelled
        session.updatedAt = date
        for identifier in session.activeContactIDs {
            guard var contact = session.contacts[identifier] else { continue }
            contact.transition = .cancel
            contact.updatedAt = date
            session.contacts[identifier] = contact
            session.transitionHistory.append(
                ContactTransitionRecord(
                    identifier: identifier,
                    transition: .cancel,
                    occurredAt: date,
                    position: contact.position
                )
            )
        }
        session.activeContactIDs = []
        currentSession = nil
        return session
    }

    mutating func reset() {
        currentSession = nil
    }

    private static func centroid(of touches: [RawTrackpadTouch]) -> TrackpadPoint {
        let total = touches.reduce((x: 0.0, y: 0.0)) {
            ($0.x + $1.position.x, $0.y + $1.position.y)
        }
        let count = Double(max(touches.count, 1))
        return TrackpadPoint(x: total.x / count, y: total.y / count)
    }
}
