import SwiftUI

/// Revisão explícita da receita, sem apresentar conteúdo recebido pelo painel.
struct ScriptApprovalView: View {
    let approval: PendingScriptApproval
    let onResolve: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Revisar automação", systemImage: "terminal").font(.title2.bold())
            Text("Executar automação de “\(approval.ruleName)”?")
            ScrollView {
                Text(approval.command).font(.system(.body, design: .monospaced))
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
            .padding(12).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            Text("A aprovação vale para este comando. Uma alteração exigirá nova revisão.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Cancelar", role: .cancel) { onResolve(false) }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Executar") { onResolve(true) }.buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("tico.automation.approve")
            }
        }
        .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}
