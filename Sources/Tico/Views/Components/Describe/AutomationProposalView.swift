import SwiftUI

/// A mesma revisão serve às escolhas, à gramática e à IA; nenhuma delas salva
/// ou executa a regra. O callback do editor continua pertencendo ao shell.
struct AutomationProposalView: View {
    let draft: ShortcutRule
    let applications: [ApplicationChoice]
    var onReview: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Proposta para conferir", systemImage: "checkmark.circle").font(.headline)
                Spacer()
                if let onReview { Button("Rever frase", action: onReview) }
            }
            VStack(alignment: .leading, spacing: 8) {
                Label(draft.trigger.displayName, systemImage: RuleEditorSummary.symbol(draft.trigger))
                Label(draft.scope.displayName(applications: applications), systemImage: "globe")
                Label(RuleEditorSummary.action(draft.action, applications: applications), systemImage: "arrow.turn.down.right")
                    .textSelection(.enabled)
            }.font(.callout)
            Text("Nada foi salvo ou executado. O editor permite ajustar a proposta e escolher quando ativar.")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.025), in: .rect(cornerRadius: 12))
            .accessibilityIdentifier("tico.describe.proposal")
    }
}
