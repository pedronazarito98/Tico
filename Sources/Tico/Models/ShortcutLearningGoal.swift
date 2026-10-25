import Foundation

/// Um objetivo guarda apenas identidade, revisão e contadores agregados.
/// Nenhum acionamento, conteúdo da ação ou histórico pessoal é persistido.
struct ShortcutLearningGoal: Codable, Equatable, Sendable {
    var ruleID: UUID
    var ruleRevision: Date
    var gestureSuccesses = 0
    var panelSuccesses = 0
    var lastReminderAt: Date?
    var snoozedUntil: Date?

    static let requiredSuccesses = 5
    var progress: Double { Double(gestureSuccesses) / Double(Self.requiredSuccesses) }
}

/// A conclusão pertence à revisão que foi aprendida. A v1 guardava somente IDs;
/// ao migrá-la preservamos o objetivo ativo, mas descartamos conclusões cuja
/// revisão não pode ser comprovada, sem supor que o gesto atual já foi aprendido.
struct ShortcutLearningDocument: Codable, Equatable {
    static let currentVersion = 2
    var version = Self.currentVersion
    /// Chave legada preservada: controla somente as dicas. A existência de um
    /// objetivo autoriza acompanhar seus usos, mesmo quando os avisos estão silenciados.
    var isEnabled = false
    var goal: ShortcutLearningGoal?
    var masteredRuleRevisions: [UUID: Date] = [:]
    var masteredRuleIDs: Set<UUID> { Set(masteredRuleRevisions.keys) }

    init() {}

    private enum CodingKeys: String, CodingKey {
        case version, isEnabled, goal, masteredRuleIDs, masteredRuleRevisions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let sourceVersion = try container.decode(Int.self, forKey: .version)
        guard sourceVersion == 1 || sourceVersion == Self.currentVersion else {
            throw ShortcutLearningError.invalidDocument
        }
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        goal = try container.decodeIfPresent(ShortcutLearningGoal.self, forKey: .goal)
        if sourceVersion == 1 {
            let legacyIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .masteredRuleIDs) ?? []
            guard legacyIDs.count <= 1_000 else { throw ShortcutLearningError.invalidDocument }
            masteredRuleRevisions = [:]
        } else {
            masteredRuleRevisions = try container.decode([UUID: Date].self, forKey: .masteredRuleRevisions)
        }
        version = Self.currentVersion
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encodeIfPresent(goal, forKey: .goal)
        try container.encode(masteredRuleRevisions, forKey: .masteredRuleRevisions)
    }
}

/// A apresentação é efêmera: nomes e gestos são resolvidos da regra atual.
struct ShortcutLearningPrompt: Identifiable, Equatable {
    let id: UUID
    let ruleID: UUID
    let title: String
    let triggerDescription: String
    let successes: Int
}

enum ShortcutLearningError: LocalizedError {
    case invalidDocument
    case unavailable
    case disabledRule
    case persistence

    var errorDescription: String? {
        switch self {
        case .invalidDocument: return "O arquivo de aprendizado não é válido. Seus dados anteriores foram preservados."
        case .unavailable: return "O aprendizado está indisponível porque seus dados não puderam ser carregados."
        case .disabledRule: return "Ative o atalho antes de começar a aprendê-lo."
        case .persistence: return "Não foi possível salvar o aprendizado. O último estado válido foi preservado."
        }
    }
}
