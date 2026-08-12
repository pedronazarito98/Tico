import SwiftUI

struct RuleSidebarItem: Identifiable, Hashable {
    let id: ShortcutRule.ID
    let name: String
    let detail: String
    let isEnabled: Bool
    let hasConflict: Bool
}

struct RuleSidebarSection: View {
    @Binding var selection: AirShortcutSection?
    @Binding var selectedRuleID: ShortcutRule.ID?
    let items: [RuleSidebarItem]
    let onSetRuleEnabled: (ShortcutRule.ID, Bool) throws -> Void
    let onDeleteRule: (ShortcutRule.ID) throws -> Void

    @State private var isExpanded = false
    @State private var searchText = ""
    @State private var presentedError: String?
    @State private var itemPendingDeletion: RuleSidebarItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggleRulesSection) {
                HStack(spacing: 8) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 10)

                    Label(
                        AirShortcutSection.rules.title,
                        systemImage: AirShortcutSection.rules.systemImage
                    )

                    Spacer(minLength: 4)

                    Text("\(items.count)")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(
                            selection == .rules
                                ? TicoBrand.Palette.primary
                                : TicoBrand.Palette.secondaryText
                        )
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(
                    selection == .rules
                        ? TicoBrand.Palette.primary
                        : TicoBrand.Palette.text
                )
                .background {
                    if selection == .rules {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(TicoBrand.Palette.primary.opacity(0.10))
                    }
                }
                .overlay(alignment: .leading) {
                    if selection == .rules {
                        Capsule()
                            .fill(TicoBrand.Palette.primary)
                            .frame(width: 2, height: 20)
                            .offset(x: -3)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 3) {
                    ruleSearch
                    ruleList
                }
                .padding(.leading, 28)
                .padding(.top, 4)
                .padding(.bottom, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            isExpanded = selection == .rules
        }
        .onChange(of: selection) { _, newSelection in
            isExpanded = newSelection == .rules
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

    @ViewBuilder
    private var ruleSearch: some View {
        if shouldShowSearch {
            TextField("Buscar regras", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .padding(.vertical, 2)
                .accessibilityLabel("Buscar regras")
        }
    }

    @ViewBuilder
    private var ruleList: some View {
        if filteredItems.isEmpty {
            Text(items.isEmpty ? "Nenhuma regra criada" : "Nenhuma regra encontrada")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 4)
        } else {
            ForEach(filteredItems) { item in
                ruleRow(item)
            }
        }
    }

    private var filteredItems: [RuleSidebarItem] {
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearchText.isEmpty else { return items }
        return items.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedSearchText)
                || $0.detail.localizedCaseInsensitiveContains(trimmedSearchText)
        }
    }

    private var shouldShowSearch: Bool {
        items.count > 5 || !searchText.isEmpty
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
        Button {
            selection = .rules
            selectedRuleID = item.id
        } label: {
            HStack(alignment: .center, spacing: 8) {
                Circle()
                    .fill(statusColor(for: item))
                    .frame(width: 6, height: 6)
                    .help(statusDescription(for: item))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .fontWeight(isSelected(item) ? .semibold : .regular)
                        .foregroundStyle(
                            isSelected(item)
                                ? TicoBrand.Palette.primary
                                : (item.isEnabled
                                    ? TicoBrand.Palette.text
                                    : TicoBrand.Palette.secondaryText)
                        )
                        .lineLimit(1)
                        .help(item.name)

                    Text(item.detail)
                        .font(.caption)
                        .foregroundStyle(
                            isSelected(item)
                                ? TicoBrand.Palette.text.opacity(0.72)
                                : TicoBrand.Palette.secondaryText
                        )
                        .lineLimit(1)
                        .help(item.detail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected(item) {
                    Image(systemName: "chevron.forward")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(TicoBrand.Palette.primary)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, 4)
            .padding(.leading, isSelected(item) ? 4 : 0)
            .overlay(alignment: .leading) {
                if isSelected(item) {
                    Capsule()
                        .fill(TicoBrand.Palette.primary)
                        .frame(width: 2, height: 24)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(item.isEnabled ? "Desativar" : "Ativar") {
                setEnabled(!item.isEnabled, for: item.id)
            }
            Divider()
            Button("Excluir", role: .destructive) {
                itemPendingDeletion = item
            }
        }
        .accessibilityLabel(item.name)
        .accessibilityValue("\(item.detail), \(statusDescription(for: item))")
    }

    private func isSelected(_ item: RuleSidebarItem) -> Bool {
        selection == .rules && selectedRuleID == item.id
    }

    private func toggleRulesSection() {
        if selection != .rules {
            selection = .rules
            isExpanded = true
        } else {
            isExpanded.toggle()
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
