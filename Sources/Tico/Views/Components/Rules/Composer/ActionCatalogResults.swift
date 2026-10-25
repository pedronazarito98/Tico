import SwiftUI

/// Lista semântica: resultados usam botões nativos, foco por teclado e seleção
/// anunciada. A mesma projeção alimenta a busca compacta e a galeria completa.
struct ActionCatalogResults: View {
    let entries: [ActionCatalogEntry]
    let applications: [ApplicationChoice]
    var selectedAction: ShortcutAction?
    let onSelect: (ShortcutAction, String) -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 14) {
            ForEach(ActionCatalogEntry.Category.allCases) { category in
                let choices = entries.filter { $0.category == category }
                if !choices.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(category.rawValue)
                            .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                        ForEach(choices) { entry in choice(entry) }
                    }
                }
            }
            if entries.isEmpty {
                ContentUnavailableView("Nenhuma ação encontrada", systemImage: "magnifyingglass",
                    description: Text("Tente o nome de um app ou um resultado, como copiar ou metade esquerda."))
            }
        }
    }

    private func choice(_ entry: ActionCatalogEntry) -> some View {
        let selected = selectedAction == entry.action
        return Button {
            onSelect(entry.action, entry.title)
        } label: {
            HStack(spacing: 10) {
                ShortcutActionIcon(action: entry.action, applications: applications, size: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.title).font(.callout.weight(selected ? .semibold : .regular))
                    if !entry.detail.isEmpty {
                        Text(entry.detail).font(.caption).foregroundStyle(.secondary)
                    }
                }.multilineTextAlignment(.leading)
                Spacer(minLength: 4)
                if selected {
                    Image(systemName: "checkmark").font(.caption.weight(.semibold))
                        .foregroundStyle(TicoBrand.Palette.primary)
                }
            }
            .padding(8).frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? TicoBrand.Palette.primary.opacity(0.1) : .clear,
                        in: .rect(cornerRadius: 8))
            .contentShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.title)
        .accessibilityValue(entry.detail)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
