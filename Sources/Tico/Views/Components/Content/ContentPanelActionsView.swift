import SwiftUI

/// Ações compatíveis ficam em primeiro plano. Menus de manutenção continuam
/// disponíveis mesmo sem entrada; escolher uma receita é uma execução explícita.
struct ContentPanelActionsView: View {
    @ObservedObject var session: ContentPanelSession
    let actions: [ContentActionChoice]
    let canManageRecipes: Bool
    let onCreate: (ContentRecipeIntent) -> Void
    let onEdit: (UUID) -> Void
    let onDelete: (UUID) -> Void
    @State private var pendingDeletion: ContentActionChoice?
    @State private var searchText = ""

    private var compatible: [ContentActionChoice] {
        actions.filter {
            $0.acceptedKinds.contains(session.kind)
                && (searchText.isEmpty || $0.title.localizedStandardContains(searchText))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("O que fazer").font(.headline)
            if actions.count > 8 {
                TextField("Buscar ação", text: $searchText).textFieldStyle(.roundedBorder)
            }
            if compatible.isEmpty {
                Text(!searchText.isEmpty ? "Nenhuma ação com esse nome."
                     : session.kind == .files
                     ? "Envie estes arquivos a um Atalho do macOS."
                     : "Esta ação não recebe esse tipo de conteúdo. Escolha outra entrada.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            ForEach(compatible) { choice in
                HStack(spacing: 8) {
                    Button { session.run(choice) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: choice.recipe == nil ? "bolt" : "arrow.up.forward")
                                .foregroundStyle(TicoBrand.Palette.primary).frame(width: 20)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(choice.title).fontWeight(.medium)
                                    .fixedSize(horizontal: false, vertical: true)
                                if !choice.detail.isEmpty {
                                    Text(choice.detail).font(.caption).foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            if session.runningActionID == choice.id { ProgressView().controlSize(.small) }
                            else { Image(systemName: "arrow.right").foregroundStyle(.secondary) }
                        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .disabled(session.isRunning || session.content == nil)
                    if choice.isEditable {
                        Menu {
                            Button("Editar receita") { onEdit(choice.id) }
                            Button("Excluir receita", role: .destructive) { pendingDeletion = choice }
                        } label: { Image(systemName: "ellipsis") }
                            .menuStyle(.borderlessButton).fixedSize()
                            .disabled(session.isRunning)
                            .accessibilityLabel("Opções de \(choice.title)")
                    }
                }
                .padding(12)
                .background(TicoBrand.Palette.surface, in: .rect(cornerRadius: 10))
            }
            if canManageRecipes {
                Button { onCreate(.shortcut) } label: {
                    Label("Enviar para um Atalho do macOS…", systemImage: "square.stack.3d.up")
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }.buttonStyle(.borderless).disabled(session.isRunning).padding(.top, 4)
            }
        }
        .confirmationDialog("Excluir esta receita?", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }), titleVisibility: .visible) {
                Button("Excluir receita", role: .destructive) {
                    if let pendingDeletion { onDelete(pendingDeletion.id) }
                    pendingDeletion = nil
                }
        } message: { Text("O conteúdo desta sessão e seus atalhos serão preservados.") }
    }
}
