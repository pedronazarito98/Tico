import SwiftUI
import UniformTypeIdentifiers

/// A sessão pertence ao coordenador. Navegar até uma receita não desmonta nem
/// limpa a entrada; somente fechar, limpar, concluir ou expirar a apagam.
struct ContentActionPanelView: View {
    @ObservedObject var session: ContentPanelSession
    let actions: [ContentActionChoice]
    let canManageRecipes: Bool
    let onCreateRecipe: (ContentRecipeIntent) -> Void
    let onEditRecipe: (UUID) -> Void
    let onDeleteRecipe: (UUID) -> Void
    @State private var showsFileImporter = false
    @State private var isDropTarget = false
    @State private var fileImportGeneration: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fazer com conteúdo").font(.title2.weight(.semibold))
                    Text("Forneça o conteúdo e escolha o resultado.").font(.callout).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Limpar", systemImage: "trash", action: session.clear)
                    .labelStyle(.iconOnly).buttonStyle(.borderless).disabled(session.isRunning)
                    .help("Limpar o conteúdo desta sessão")
            }
            Picker("Tipo de conteúdo", selection: Binding(get: { session.kind }, set: session.selectKind)) {
                ForEach(ContentKind.allCases, id: \.self) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented).disabled(session.isRunning)
            ContentPanelInputView(session: session, onChooseFiles: chooseFiles)
                .disabled(session.isRunning)
                .padding(12)
                .background(TicoBrand.Palette.surface, in: .rect(cornerRadius: 10))
                .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(isDropTarget ? TicoBrand.Palette.primary : .secondary.opacity(0.2)) }
                .dropDestination(for: URL.self) { urls, _ in session.addFiles(urls) }
                    isTargeted: { isDropTarget = $0 }
            if let issue = session.inputIssue {
                Label(issue, systemImage: "info.circle").font(.caption).foregroundStyle(.secondary)
            }
            ContentPanelActionsView(session: session, actions: actions,
                canManageRecipes: canManageRecipes, onCreate: onCreateRecipe,
                onEdit: onEditRecipe, onDelete: onDeleteRecipe)
            if let status = session.status {
                Label(status, systemImage: session.resultSucceeded ? "checkmark.circle" : "info.circle")
                    .font(.callout).foregroundStyle(session.resultSucceeded ? .green : .secondary)
                    .accessibilityIdentifier("tico.content.status")
            }
            Label("Só nesta sessão · expira após 5 minutos sem uso", systemImage: "lock")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .fileImporter(isPresented: $showsFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: true,
                      onCompletion: receiveFiles)
    }

    private func chooseFiles() {
        fileImportGeneration = session.inputGeneration
        showsFileImporter = true
    }

    private func receiveFiles(_ result: Result<[URL], Error>) {
        guard let token = fileImportGeneration else { return }
        fileImportGeneration = nil
        session.receiveFiles(result, inputGeneration: token)
    }
}
