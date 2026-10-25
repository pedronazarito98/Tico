import SwiftUI

/// Observa a sessão diretamente: mudanças da tarefa não são republicadas pelo
/// coordenador. Os controles permanecem acessíveis fora da área de rolagem.
/// Paralelo com React: um filho assina o estado usado pelo próprio rodapé.
struct ContentPanelFooterView: View {
    @ObservedObject var session: ContentPanelSession
    let canManageRecipes: Bool
    let onCreateRecipe: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack {
            if session.isRunning {
                Button(session.isCancelling ? "Cancelando…" : "Cancelar execução",
                       role: .cancel, action: session.cancel)
                    .disabled(session.isCancelling)
                    .accessibilityIdentifier("tico.content.cancel-execution")
            } else if canManageRecipes {
                Button("Nova receita", systemImage: "plus", action: onCreateRecipe)
                    .buttonStyle(.borderless)
            }
            Spacer(minLength: 8)
            Button("Fechar", action: onClose).keyboardShortcut(.cancelAction)
        }.padding(16)
    }
}
