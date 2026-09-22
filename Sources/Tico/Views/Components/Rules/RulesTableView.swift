import SwiftUI

/// Tabela nativa: seleção por UUID, navegação pelo teclado e menus contextuais do Mac.
/// Recebe projeções e ações; ativar uma linha não executa a automação.
struct RulesTableView: View {
    let rules: [ShortcutRule]
    let applications: [ApplicationChoice]
    @Binding var selection: UUID?
    let onSetEnabled: (UUID, Bool) -> Void
    let onDelete: (UUID) -> Void
    let onPractice: (ShortcutRule) -> Void

    var body: some View {
        Table(rules, selection: $selection) {
            TableColumn("Atalho") { rule in
                Label(rule.name, systemImage: RuleEditorSummary.symbol(rule.trigger))
                    .lineLimit(1)
                    .help(rule.name)
                    .accessibilityIdentifier("tico.rule.row.\(rule.id)")
            }
            .width(min: 130, ideal: 190, max: 240)
            TableColumn("Acionamento") { rule in
                Text(RuleEditorSummary.trigger(rule.trigger))
                    .lineLimit(1)
                    .help(RuleEditorSummary.trigger(rule.trigger))
            }
            .width(min: 100, ideal: 155, max: 220)
            TableColumn("App") { rule in
                Text(rule.scope.displayName(applications: applications))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                    .help(rule.scope.displayName(applications: applications))
            }
            .width(min: 70, ideal: 100, max: 110)
            TableColumn("Ativa") { rule in
                Toggle("Ativar \(rule.name)", isOn: Binding(
                    get: { rule.isEnabled },
                    set: { onSetEnabled(rule.id, $0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
            }
            .width(44)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .contextMenu(forSelectionType: UUID.self) { ids in
            if let id = ids.first, let rule = rules.first(where: { $0.id == id }) {
                Button("Editar atalho") { selection = id }
                Button("Praticar gesto") { onPractice(rule) }
                Button(rule.isEnabled ? "Desativar" : "Ativar") { onSetEnabled(id, !rule.isEnabled) }
                Divider()
                Button("Excluir atalho…", role: .destructive) { onDelete(id) }
            }
        }
        .accessibilityIdentifier("tico.rules.table")
    }
}
