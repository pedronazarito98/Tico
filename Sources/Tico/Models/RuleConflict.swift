import Foundation

enum RuleConflictKind: String, Codable, Hashable, Sendable {
    case identical
    case overlapping
    case sequencePrefix
    case globalShadowsApplication
    case continuousCompetesWithDiscrete
}

enum RuleConflictSeverity: String, Codable, Hashable, Sendable {
    case warning
    case replacementRequired
}

struct RuleConflict: Identifiable, Hashable, Sendable {
    var existingRuleID: UUID
    var existingRuleName: String
    var kind: RuleConflictKind
    var severity: RuleConflictSeverity
    var message: String

    var id: String {
        "\(existingRuleID.uuidString)-\(kind.rawValue)"
    }
}
