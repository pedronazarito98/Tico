import Foundation

struct AdvancedFingerGestureRecognizer: GestureCandidateRecognizing {
    let configuration: GestureRecognizerConfiguration

    func candidates(for features: GestureFeatures) -> [GestureCandidate] {
        guard features.maximumFingerCount >= 2 else { return [] }

        if let transient = latestCompletedTransientContact(in: features),
           features.activeFingerCount >= 1,
           features.sessionDuration >= 0.12 {
            let anchors = features.contacts.filter {
                $0.identifier != transient.identifier && $0.transition != .up
            }
            let anchorX = anchors.isEmpty
                ? features.centroid.x
                : anchors.reduce(0) { $0 + $1.position.x } / Double(anchors.count)
            let kind: TrackpadGesture = transient.position.x < anchorX ? .tipTapLeft : .tipTapRight
            return [
                GestureCandidate(
                    kind: kind,
                    phase: .ended,
                    confidence: 0.94,
                    recognizer: .advancedFinger,
                    evidence: "um dedo tocou e saiu enquanto \(anchors.count) permaneceram apoiados",
                    priority: 90,
                    advanced: AdvancedGestureMetadata(
                        anchorFingerCount: anchors.count,
                        removedFingerCount: 1,
                        entryOrder: normalizedOrder(for: features, transition: .down),
                        exitOrder: normalizedOrder(for: features, transition: .up)
                    )
                )
            ]
        }

        if features.phase == .changed,
           features.sessionDuration >= 0.12,
           hasDelayedDownTransition(in: features),
           addedContactHasSettled(in: features),
           features.activeFingerCount > features.initialFingerCount {
            let addedCount = features.activeFingerCount - features.initialFingerCount
            return [
                GestureCandidate(
                    kind: .addFinger,
                    phase: .ended,
                    confidence: 0.9,
                    recognizer: .advancedFinger,
                    evidence: "novo contato adicionado após a formação dos dedos âncora",
                    priority: 80,
                    advanced: AdvancedGestureMetadata(
                        anchorFingerCount: features.initialFingerCount,
                        addedFingerCount: addedCount,
                        entryOrder: normalizedOrder(for: features, transition: .down)
                    )
                )
            ]
        }

        let upTransitions = recentTransitions(in: features, kind: .up)
        if features.phase == .changed,
           !upTransitions.isEmpty,
           features.activeFingerCount >= 1 {
            return [
                GestureCandidate(
                    kind: .removeFinger,
                    phase: .ended,
                    confidence: 0.88,
                    recognizer: .advancedFinger,
                    evidence: "contato removido enquanto outros dedos permaneceram apoiados",
                    priority: 70,
                    advanced: AdvancedGestureMetadata(
                        anchorFingerCount: features.activeFingerCount,
                        removedFingerCount: upTransitions.count,
                        exitOrder: normalizedOrder(for: features, transition: .up)
                    )
                )
            ]
        }

        if features.phase == .ended {
            let entryOrder = normalizedOrder(for: features, transition: .down)
            let exitOrder = normalizedOrder(for: features, transition: .up)
            let entryRecords = features.transitions.filter { $0.transition == .down }
            let exitRecords = features.transitions.filter { $0.transition == .up }
            if entryOrder.count >= 2,
               exitOrder.count >= 2,
               transitionSpan(entryRecords) >= 0.035,
               transitionSpan(exitRecords) >= 0.035 {
                return [
                    GestureCandidate(
                        kind: .fingerChord,
                        phase: .ended,
                        confidence: 0.76,
                        recognizer: .advancedFinger,
                        evidence: "ordens de entrada e saída preservadas",
                        priority: 15,
                        advanced: AdvancedGestureMetadata(
                            entryOrder: entryOrder,
                            exitOrder: exitOrder
                        )
                    )
                ]
            }
        }

        return []
    }

    private func latestCompletedTransientContact(
        in features: GestureFeatures
    ) -> ContactState? {
        guard let latestUp = features.transitions.last(where: { $0.transition == .up }),
              let contact = features.contacts.first(where: { $0.identifier == latestUp.identifier }),
              contact.duration <= configuration.tapMaximumDuration,
              contact.startPosition.distance(to: contact.position) <= configuration.stationaryDistance else {
            return nil
        }
        return contact
    }

    private func recentTransitions(
        in features: GestureFeatures,
        kind: ContactTransition
    ) -> [ContactTransitionRecord] {
        let newest = features.transitions.last?.occurredAt ?? features.occurredAt
        return features.transitions.filter {
            $0.transition == kind && newest.timeIntervalSince($0.occurredAt) <= 0.03
        }
    }

    private func hasDelayedDownTransition(in features: GestureFeatures) -> Bool {
        guard let sessionStart = features.transitions.first?.occurredAt else {
            return false
        }
        return features.transitions.contains {
            $0.transition == .down
                && $0.occurredAt.timeIntervalSince(sessionStart) >= 0.08
        }
    }

    private func addedContactHasSettled(in features: GestureFeatures) -> Bool {
        guard let sessionStart = features.transitions.first?.occurredAt else {
            return false
        }
        return features.contacts.contains {
            $0.startedAt.timeIntervalSince(sessionStart) >= 0.08
                && $0.transition != .up
                && $0.duration >= 0.16
        }
    }

    private func normalizedOrder(
        for features: GestureFeatures,
        transition: ContactTransition
    ) -> [Int] {
        let records = features.transitions.filter { $0.transition == transition }
        let orderedIdentifiers = records.map(\.identifier)
        let contactsByPosition = features.contacts
            .sorted { $0.startPosition.x < $1.startPosition.x }
            .map(\.identifier)
        return orderedIdentifiers.compactMap { identifier in
            contactsByPosition.firstIndex(of: identifier).map { $0 + 1 }
        }
    }

    private func transitionSpan(_ records: [ContactTransitionRecord]) -> TimeInterval {
        guard let first = records.first?.occurredAt,
              let last = records.last?.occurredAt else {
            return 0
        }
        return last.timeIntervalSince(first)
    }
}

struct TapCountComposer {
    var maximumInterval: TimeInterval = 1

    private var lastTap: GestureEvent?
    private var count = 0

    init(maximumInterval: TimeInterval = 1) {
        self.maximumInterval = maximumInterval
    }

    mutating func process(_ event: GestureEvent) -> GestureEvent {
        guard event.kind == .tap, event.phase == .ended else {
            reset()
            return event
        }
        let interval = lastTap.map { event.occurredAt.timeIntervalSince($0.occurredAt) }
        if let lastTap,
           let interval,
           interval <= maximumInterval,
           lastTap.fingerCount == event.fingerCount,
           lastTap.startRegion == event.startRegion {
            count = min(count + 1, 3)
        } else {
            count = 1
        }
        self.lastTap = event
        return GestureEvent(
            id: event.id,
            sessionID: event.sessionID,
            kind: event.kind,
            phase: event.phase,
            fingerCount: event.fingerCount,
            deviceID: event.deviceID,
            startRegion: event.startRegion,
            endRegion: event.endRegion,
            startPosition: event.startPosition,
            endPosition: event.endPosition,
            path: event.path,
            progress: event.progress,
            velocity: event.velocity,
            pressure: event.pressure,
            confidence: event.confidence,
            advanced: AdvancedGestureMetadata(
                tapCount: count,
                tapInterval: count > 1 ? interval : nil
            ),
            occurredAt: event.occurredAt
        )
    }

    mutating func reset() {
        lastTap = nil
        count = 0
    }
}
