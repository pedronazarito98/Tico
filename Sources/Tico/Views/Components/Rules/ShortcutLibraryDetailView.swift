import SwiftUI

/// Detalhe de leitura da biblioteca; editar abre o mesmo rascunho mantido pela janela.
struct ShortcutLibraryDetailView: View {
    let rule: ShortcutRule
    let applications: [ApplicationChoice]
    let wasJustCreated: Bool
    let onSetEnabled: (Bool) -> Void
    let onEdit: () -> Void
    let onPractice: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(rule.name).font(.title2.bold()).textSelection(.enabled)
                        Spacer()
                        Toggle("Ativo", isOn: Binding(get: { rule.isEnabled }, set: onSetEnabled))
                            .toggleStyle(.switch).fixedSize().accessibilityIdentifier("tico.rule.enabled")
                    }
                    if wasJustCreated {
                        Label("Atalho criado", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green).padding(10).frame(maxWidth: .infinity, alignment: .leading)
                            .background(.green.opacity(0.1), in: .rect(cornerRadius: 8))
                            .accessibilityIdentifier("tico.rule.created")
                    }
                    ShortcutResultPreview(workflow: rule.workflow, applications: applications)
                    HStack(spacing: 24) {
                        VStack(spacing: 9) {
                            ShortcutGesturePreview(trigger: rule.trigger, height: 92).frame(width: 150)
                            Text(RuleEditorSummary.trigger(rule.trigger)).font(.callout).multilineTextAlignment(.center)
                        }.frame(maxWidth: .infinity)
                        Image(systemName: "arrow.right").font(.title2).foregroundStyle(.secondary)
                        VStack(spacing: 9) {
                            ShortcutActionIcon(action: rule.action, applications: applications, size: 46)
                            Text(RuleEditorSummary.action(rule.action, applications: applications))
                                .font(.callout).multilineTextAlignment(.center).lineLimit(3)
                        }.frame(maxWidth: .infinity)
                    }.padding(18).background(TicoBrand.Palette.surface.opacity(0.6), in: .rect(cornerRadius: 10))
                    HStack(spacing: 8) {
                        ForEach(Array(rule.scope.bundleIdentifiers.sorted().prefix(3)), id: \.self) { id in
                            ApplicationIconView(application: applications.first { $0.id == id }, size: 26)
                        }
                        if rule.scope.bundleIdentifiers.isEmpty { Image(systemName: "globe") }
                        Text(rule.scope.displayName(applications: applications)).font(.callout)
                        Spacer()
                    }.padding(12).background(TicoBrand.Palette.surface.opacity(0.6), in: .rect(cornerRadius: 8))
                    if rule.workflow.enabledSteps.count > 1 {
                        Label("\(rule.workflow.enabledSteps.count) ações em sequência", systemImage: "list.number")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    if !rule.conditions.isEmpty {
                        Label("\(rule.conditions.count) condições adicionais", systemImage: "line.3.horizontal.decrease")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    if !rule.notes.isEmpty { Text(rule.notes).font(.callout).foregroundStyle(.secondary) }
                }.padding(20)
            }
            Divider()
            HStack {
                Spacer()
                Button("Experimentar", systemImage: "play.fill", action: onPractice).buttonStyle(.glass)
                Button("Editar atalho", systemImage: "pencil", action: onEdit).buttonStyle(.glassProminent)
                    .accessibilityIdentifier("tico.rule.edit")
            }.controlSize(.large).padding(16)
        }
        .background(TicoBrand.Palette.background.opacity(0.65))
    }
}
