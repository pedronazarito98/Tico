import SwiftUI

struct RuleSidebarItem: Identifiable, Hashable {
    let id: ShortcutRule.ID
    let name: String
    let detail: String
    let isEnabled: Bool
    let hasConflict: Bool
}

struct RuleSidebarSection: View {
    let items: [RuleSidebarItem]
    let onSetRuleEnabled: (ShortcutRule.ID, Bool) throws -> Void
    let onDeleteRule: (ShortcutRule.ID) throws -> Void
    let onSelect: (ShortcutRule.ID) -> Void

    @State private var presentedError: String?
    @State private var itemPendingDeletion: RuleSidebarItem?

    var body: some View {
        Section("Regras") {
            ForEach(items) { item in
                Button {
                    onSelect(item.id)
                } label: {
                    ruleRow(item)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .tag(SidebarDestination.rule(item.id))
                .accessibilityLabel(item.name)
                .accessibilityValue("\(item.detail), \(statusDescription(for: item))")
                .contextMenu {
                    Button(item.isEnabled ? "Desativar" : "Ativar") {
                        setEnabled(!item.isEnabled, for: item.id)
                    }
                    Divider()
                    Button("Excluir", role: .destructive) {
                        itemPendingDeletion = item
                    }
                }
            }
        }
        .alert("Não foi possível atualizar a regra", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) { presentedError = nil }
        } message: {
            Text(presentedError ?? "Erro desconhecido")
        }
        .confirmationDialog(
            "Excluir \(itemPendingDeletion?.name ?? "esta regra")?",
            isPresented: deletionIsPresented
        ) {
            Button("Excluir regra", role: .destructive, action: deletePendingRule)
            Button("Cancelar", role: .cancel) { itemPendingDeletion = nil }
        } message: {
            Text("Esta ação não pode ser desfeita.")
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { presentedError != nil },
            set: { if !$0 { presentedError = nil } }
        )
    }

    private var deletionIsPresented: Binding<Bool> {
        Binding(
            get: { itemPendingDeletion != nil },
            set: { if !$0 { itemPendingDeletion = nil } }
        )
    }

    private func ruleRow(_ item: RuleSidebarItem) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Circle()
                .fill(statusColor(for: item))
                .frame(width: 6, height: 6)
                .help(statusDescription(for: item))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .foregroundStyle(item.isEnabled ? .primary : .secondary)
                    .lineLimit(1)
                    .help(item.name)

                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(item.detail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func statusColor(for item: RuleSidebarItem) -> Color {
        if item.hasConflict {
            return .orange
        }
        return item.isEnabled ? Color.secondary : Color.secondary.opacity(0.35)
    }

    private func statusDescription(for item: RuleSidebarItem) -> String {
        if item.hasConflict {
            return "Possui conflito"
        }
        return item.isEnabled ? "Ativa" : "Inativa"
    }

    private func setEnabled(_ isEnabled: Bool, for id: ShortcutRule.ID) {
        do {
            try onSetRuleEnabled(id, isEnabled)
        } catch {
            presentedError = error.localizedDescription
        }
    }

    private func deletePendingRule() {
        guard let itemPendingDeletion else { return }
        do {
            try onDeleteRule(itemPendingDeletion.id)
            self.itemPendingDeletion = nil
        } catch {
            presentedError = error.localizedDescription
        }
    }
}
