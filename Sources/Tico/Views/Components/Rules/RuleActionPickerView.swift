import SwiftUI

/// Catálogo completo usado também para adicionar e substituir uma ação.
/// Compartilha resultados e busca com o criador; escolher só altera o rascunho.
struct RuleActionPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let applications: [ApplicationChoice]
    var initialSearch = ""
    let onSelect: (ShortcutAction) -> Void
    @State private var search = ""
    @State private var category: ActionCatalogEntry.Category?
    @FocusState private var searchIsFocused: Bool

    private var entries: [ActionCatalogEntry] {
        ActionCatalogEntry.entries(applications: applications).filter {
            (category == nil || $0.category == category) && $0.matches(search)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Escolha um resultado").font(.title2.bold())
                Spacer()
                Button("Cancelar") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            TextField("Buscar: Safari, metade esquerda, copiar…", text: $search)
                .textFieldStyle(.roundedBorder).controlSize(.large)
                .focused($searchIsFocused).accessibilityIdentifier("tico.action.search")
            ScrollView(.horizontal) {
                HStack(spacing: 6) {
                    categoryButton("Todas", value: nil)
                    ForEach(ActionCatalogEntry.Category.allCases) { value in
                        categoryButton(value.rawValue, value: value)
                    }
                }
            }.scrollIndicators(.hidden)
            ScrollView {
                ActionCatalogResults(entries: entries, applications: applications) { action, _ in
                    onSelect(action)
                    dismiss()
                }
            }
            Text("A escolha entra no rascunho. Você confere os detalhes antes de salvar.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(20).adaptiveSheetFrame(idealWidth: 680, idealHeight: 590)
        .onAppear { search = initialSearch; searchIsFocused = true }
        .onChange(of: search) { category = nil }
    }

    private func categoryButton(_ title: String, value: ActionCatalogEntry.Category?) -> some View {
        Button { category = value } label: {
            Text(title).font(.callout)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(category == value ? TicoBrand.Palette.primary.opacity(0.12) : .clear,
                            in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(category == value ? [.isSelected] : [])
    }
}
