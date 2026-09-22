import SwiftUI

/// Busca local por intenção; selecionar uma linha altera somente o rascunho.
struct ShortcutActionCatalogView: View {
    let applications: [ApplicationChoice]
    let selectedAction: ShortcutAction?
    let onSelect: (ShortcutAction, String) -> Void
    let onMoreActions: () -> Void
    @State private var search = ""

    private var words: [String] {
        search.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .split(separator: " ").map(String.init)
            .filter { !["a", "o", "para", "da", "do", "de"].contains($0) }
    }

    private func matches(_ text: String) -> Bool {
        let normalized = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        return words.allSatisfy { normalized.contains($0) }
    }

    private var visibleApplications: [ApplicationChoice] {
        applications.filter { matches("abrir app aplicativo " + $0.name) }
            .sorted { lhs, rhs in
                let favorites = ["com.apple.Safari", "com.apple.finder", "com.spotify.client"]
                let l = favorites.firstIndex(of: lhs.id) ?? 99
                let r = favorites.firstIndex(of: rhs.id) ?? 99
                return l == r ? lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending : l < r
            }
    }

    private var visibleWindows: [WindowOperation] {
        let operations: [WindowOperation] = search.isEmpty
            ? [.leftHalf, .center] : WindowOperation.allCases
        return operations.filter { matches("mover organizar janela " + $0.displayName + " " + title($0)) }
    }

    private var displayedApplications: [ApplicationChoice] {
        guard search.isEmpty else { return Array(visibleApplications.prefix(30)) }
        let favorites = visibleApplications.filter { ["com.apple.Safari", "com.apple.finder", "com.spotify.client"].contains($0.id) }
        return favorites.isEmpty ? Array(visibleApplications.prefix(3)) : favorites
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("O que você quer fazer?").font(.headline)
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Buscar apps ou ações", text: $search)
                    .textFieldStyle(.plain).accessibilityIdentifier("tico.composer.search")
                if !search.isEmpty {
                    Button("Limpar busca", systemImage: "xmark.circle.fill") { search = "" }
                        .labelStyle(.iconOnly).buttonStyle(.plain)
                }
            }
            .padding(9).background(TicoBrand.Palette.surface, in: .rect(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(TicoBrand.Palette.primary.opacity(0.4)) }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    if !visibleApplications.isEmpty {
                        Text("Aplicativos").font(.subheadline).foregroundStyle(.secondary)
                        ForEach(displayedApplications) { app in
                            actionRow(.openApplication(bundleIdentifier: app.id), title: "Abrir \(app.name)")
                        }
                    }
                    if !visibleWindows.isEmpty {
                        Divider().padding(.vertical, 5)
                        Text("Janelas").font(.subheadline).foregroundStyle(.secondary)
                        ForEach(visibleWindows, id: \.self) { operation in
                            actionRow(.window(target: .frontmost, operation: operation), title: title(operation))
                        }
                    }
                    ForEach(KeyboardActionPreset.allCases.filter { !search.isEmpty && matches($0.title) }) { preset in
                        actionRow(preset.action, title: preset.title)
                    }
                    if visibleApplications.isEmpty && visibleWindows.isEmpty && !search.isEmpty {
                        Text("Busque um aplicativo, uma posição de janela ou veja todas as ações.")
                            .font(.callout).foregroundStyle(.secondary).padding(.vertical, 8)
                    }
                    Button("Todas as ações…", systemImage: "square.grid.2x2", action: onMoreActions)
                        .buttonStyle(.borderless).padding(.top, 6)
                }
            }
        }
    }

    private func actionRow(_ action: ShortcutAction, title: String) -> some View {
        let selected = selectedAction == action
        return Button { onSelect(action, title) } label: {
            HStack(spacing: 10) {
                ShortcutActionIcon(action: action, applications: applications, size: 24)
                Text(title).font(.callout).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(4).frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? TicoBrand.Palette.primary.opacity(0.13) : .clear, in: .rect(cornerRadius: 9))
            .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(selected ? TicoBrand.Palette.primary.opacity(0.7) : .clear) }
            .contentShape(.rect(cornerRadius: 9))
        }
        .buttonStyle(.plain).accessibilityLabel(title)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    private func title(_ operation: WindowOperation) -> String {
        switch operation {
        case .leftHalf: "Mover para a esquerda"
        case .rightHalf: "Mover para a direita"
        case .center: "Centralizar janela"
        default: operation.displayName
        }
    }
}
