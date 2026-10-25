import SwiftUI

struct ContextualActionItem: Identifiable {
    let id: UUID
    let name: String
    let trigger: String
}

struct ContextualActionsView: View {
    let appName: String
    let items: [ContextualActionItem]
    let isMap: Bool
    let onSelect: (UUID) -> Void
    let onClose: () -> Void
    var onContent: () -> Void = {}
    var onSelection: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: isMap ? "hand.draw" : "bolt.circle")
                Text(isMap ? "Seus atalhos" : "O que vamos fazer?").font(.headline)
                Spacer()
                Button(action: onClose) { Image(systemName: "xmark") }
                    .buttonStyle(.plain).accessibilityLabel("Fechar painel")
            }
            Text(appName).foregroundStyle(.secondary)
            if items.isEmpty {
                Text("Nenhum atalho disponível aqui. Explore receitas no Tico.")
                    .foregroundStyle(.secondary).padding(.vertical)
            }
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(items) { item in
                        if isMap {
                            row(item)
                        } else {
                            Button { onSelect(item.id) } label: { row(item) }
                                .buttonStyle(.plain)
                                .accessibilityHint("Executa esta ação no aplicativo indicado")
                        }
                    }
                }
            }.frame(maxHeight: isMap ? 320 : 250)
            if !isMap {
                Divider()
                HStack {
                    Button("Fazer com conteúdo…", action: onContent)
                    Spacer()
                    Menu("Mais") { Button("Usar texto selecionado", action: onSelection) }
                        .menuStyle(.borderlessButton).fixedSize()
                }.controlSize(.small)
            }
            Text(isMap ? "Solte ⌘⌥ para fechar · nenhuma ação é executada" : "Clique para executar · Esc para fechar")
                .font(.caption).foregroundStyle(.secondary)
        }.padding(20).frame(width: 370)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            .tint(TicoBrand.Palette.primary)
    }

    private func row(_ item: ContextualActionItem) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(item.name).font(.body.weight(.medium))
            Text(item.trigger).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
    }
}
