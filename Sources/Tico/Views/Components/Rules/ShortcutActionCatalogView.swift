import SwiftUI

/// Busca por resultado com acesso permanente ao catálogo completo.
/// O texto pertence ao criador para continuar igual quando a galeria é aberta.
struct ShortcutActionCatalogView: View {
    let applications: [ApplicationChoice]
    let selectedAction: ShortcutAction?
    @Binding var search: String
    let onSelect: (ShortcutAction, String) -> Void
    let onMoreActions: () -> Void

    private var entries: [ActionCatalogEntry] {
        ActionCatalogEntry.entries(applications: applications).filter {
            search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? $0.isSuggested : $0.matches(search)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Buscar apps ou ações", text: $search)
                    .textFieldStyle(.plain).accessibilityIdentifier("tico.composer.search")
                if !search.isEmpty {
                    Button("Limpar busca", systemImage: "xmark.circle.fill") { search = "" }
                        .labelStyle(.iconOnly).buttonStyle(.plain)
                }
            }
            .padding(10).background(TicoBrand.Palette.surface, in: .rect(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(.primary.opacity(0.12)) }
            Button("Todas as ações", systemImage: "list.bullet", action: onMoreActions)
                .buttonStyle(.borderless)
                .accessibilityIdentifier("tico.composer.all-actions")
            ScrollView {
                ActionCatalogResults(entries: entries, applications: applications,
                                     selectedAction: selectedAction, onSelect: onSelect)
            }
        }
    }
}
