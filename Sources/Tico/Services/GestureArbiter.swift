import Foundation

struct GestureArbiter {
    var minimumConfidence: Double = 0.5

    func decide(between candidates: [GestureCandidate]) -> GestureArbitrationDecision {
        let eligible = candidates.filter { $0.confidence >= minimumConfidence }
        let ordered = eligible.sorted {
            if $0.confidence != $1.confidence {
                return $0.confidence > $1.confidence
            }
            return $0.priority > $1.priority
        }
        return GestureArbitrationDecision(
            accepted: ordered.first,
            rejected: Array(ordered.dropFirst()) + candidates.filter { $0.confidence < minimumConfidence }
        )
    }
}
