import SwiftUI

/// Rascunho local da receita, sem cópia do conteúdo pessoal. Cancelar apenas
/// abandona a configuração; o owner do painel conserva sua sessão e expiração.
struct ContentRecipeEditorView: View {
    let macOSShortcuts: [String]
    let onSave: (ContentRecipe) throws -> Void
    let onCancel: () -> Void
    @State private var draft: ContentRecipe
    @State private var error: String?

    init(recipe: ContentRecipe, macOSShortcuts: [String],
         onSave: @escaping (ContentRecipe) throws -> Void, onCancel: @escaping () -> Void) {
        _draft = State(initialValue: recipe)
        self.macOSShortcuts = macOSShortcuts
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button("Voltar", systemImage: "chevron.left", action: onCancel).buttonStyle(.borderless)
                Spacer()
                Text("Sua receita").font(.headline)
            }.padding(16)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ContentDestinationEditorView(destination: $draft.configuration.destination, macOSShortcuts: macOSShortcuts)
                    DisclosureGroup("Personalizar o nome") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Nome da receita").font(.callout)
                            TextField(draft.configuration.destination.recipeTitle, text: $draft.name)
                                .textFieldStyle(.roundedBorder)
                        }.padding(.top, 8)
                    }
                    Label("A receita guarda o destino. A entrada continua nesta sessão e expira após 5 minutos sem uso.", systemImage: "lock")
                        .font(.caption).foregroundStyle(.secondary)
                    if let error {
                        Text(error).font(.callout).foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }.padding(20)
            }
            Divider()
            HStack {
                Button("Cancelar", action: onCancel).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Salvar receita", action: save)
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(draft.validationMessage != nil)
                    .accessibilityIdentifier("tico.content.recipe.save")
            }.padding(16)
        }
    }

    private func save() {
        do { try onSave(draft) }
        catch { self.error = error.localizedDescription }
    }
}
