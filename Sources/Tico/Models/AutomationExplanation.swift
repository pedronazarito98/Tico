import Foundation

/// Explicação efêmera de uma decisão; guarda apenas nomes de regras, nunca entrada bruta.
struct AutomationExplanation: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let detail: String
    let ruleIDs: [UUID]

    static func evaluate(
        event: InputEventDescriptor,
        context: ContextSnapshot,
        rules: [ShortcutRule],
        matchedRules: [ShortcutRule],
        isWaiting: Bool
    ) -> Self {
        if !matchedRules.isEmpty {
            return Self(
                title: "Atalho reconhecido",
                detail: matchedRules.map(\.name).joined(separator: ", ")
                    + ". As condições e prioridades foram avaliadas antes da execução.",
                ruleIDs: matchedRules.map(\.id)
            )
        }
        if isWaiting {
            return Self(title: "Reconhecimento parcial",
                        detail: "Na última entrada, uma sequência ou um toque múltiplo ainda não estava concluído.", ruleIDs: [])
        }
        let candidates = rules.filter { TriggerMatcher().matches($0.trigger, event: event) }
        guard let candidate = candidates.first(where: \.isEnabled) ?? candidates.first else {
            return Self(title: "Sem atalho para este movimento",
                        detail: "Crie um atalho ou escolha uma receita em Explorar.", ruleIDs: [])
        }
        let reason: String
        if !candidate.isEnabled {
            reason = "O atalho está desativado. Abra a regra para revisar e ativar."
        } else if !candidate.scope.matches(context) {
            reason = "Reconheci o gatilho, mas este atalho pertence a outro aplicativo."
        } else {
            reason = "Uma condição de janela, monitor, horário ou modificador não corresponde ao contexto atual."
        }
        return Self(title: candidate.name, detail: reason, ruleIDs: [candidate.id])
    }
}
