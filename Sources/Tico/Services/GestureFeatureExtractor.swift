import Foundation

struct GestureFeatureExtractor {
    func extract(from session: ContactSessionSnapshot) -> GestureFeatures? {
        let contacts = session.cohortContacts.sorted { $0.identifier < $1.identifier }
        guard !contacts.isEmpty else { return nil }

        let startPoints = contacts.compactMap { session.cohortStartPositions[$0.identifier] }
        guard startPoints.count == contacts.count else { return nil }
        let currentPoints = contacts.map(\.position)
        let startCentroid = Self.centroid(of: startPoints)
        let centroid = Self.centroid(of: currentPoints)
        let displacement = TrackpadPoint(
            x: centroid.x - startCentroid.x,
            y: centroid.y - startCentroid.y
        )
        let duration = max(0, session.updatedAt.timeIntervalSince(session.cohortStartedAt))
        let distance = hypot(displacement.x, displacement.y)
        let averageContactTravel = zip(startPoints, currentPoints)
            .reduce(0) { $0 + $1.0.distance(to: $1.1) } / Double(contacts.count)
        let startSpan = Self.span(of: startPoints, around: startCentroid)
        let span = Self.span(of: currentPoints, around: centroid)
        let relativeSpanChange: Double
        if let startSpan, let span, startSpan > 0 {
            relativeSpanChange = (span - startSpan) / startSpan
        } else {
            relativeSpanChange = 0
        }
        let startAngle = Self.angle(of: startPoints)
        let angle = Self.angle(of: currentPoints)

        return GestureFeatures(
            sessionID: session.id,
            phase: session.phase,
            occurredAt: session.updatedAt,
            deviceID: session.deviceID,
            fingerCount: contacts.count,
            maximumFingerCount: session.maximumFingerCount,
            initialFingerCount: session.initialFingerCount,
            activeFingerCount: session.activeContactIDs.count,
            duration: duration,
            sessionDuration: max(0, session.updatedAt.timeIntervalSince(session.startedAt)),
            startCentroid: startCentroid,
            centroid: centroid,
            centroidPath: session.cohortCentroidPath,
            displacement: displacement,
            distance: distance,
            startSpan: startSpan,
            span: span,
            relativeSpanChange: relativeSpanChange,
            startAngle: startAngle,
            angle: angle,
            rotation: Self.rotation(from: startAngle, to: angle),
            velocity: duration > 0 ? distance / duration : 0,
            motionVelocity: duration > 0 ? averageContactTravel / duration : 0,
            pressure: contacts.isEmpty
                ? nil
                : contacts.reduce(0) { $0 + $1.pressure } / Double(contacts.count),
            startRegion: Self.region(for: startCentroid),
            currentRegion: Self.region(for: centroid),
            contacts: contacts,
            transitions: session.transitionHistory
        )
    }

    private static func centroid(of points: [TrackpadPoint]) -> TrackpadPoint {
        let total = points.reduce((x: 0.0, y: 0.0)) {
            ($0.x + $1.x, $0.y + $1.y)
        }
        return TrackpadPoint(
            x: total.x / Double(points.count),
            y: total.y / Double(points.count)
        )
    }

    private static func span(
        of points: [TrackpadPoint],
        around centroid: TrackpadPoint
    ) -> Double? {
        guard points.count >= 2 else { return nil }
        return points.reduce(0) { $0 + $1.distance(to: centroid) } / Double(points.count)
    }

    private static func angle(of points: [TrackpadPoint]) -> Double? {
        guard points.count >= 2 else { return nil }
        let first = points[0]
        let second = points[1]
        return atan2(second.y - first.y, second.x - first.x)
    }

    private static func rotation(from start: Double?, to end: Double?) -> Double {
        guard let start, let end else { return 0 }
        var delta = end - start
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        return delta
    }

    private static func region(for point: TrackpadPoint) -> TrackpadRegion {
        if point.y >= 0.5 {
            return point.x < 0.5 ? .topLeft : .topRight
        }
        return point.x < 0.5 ? .bottomLeft : .bottomRight
    }
}
