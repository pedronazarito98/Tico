import SwiftUI

/// Resumo de leitura; detalhes ficam sob demanda e a edição abre o mesmo rascunho.
/// A regra controla sua ativação, enquanto a captura global chega como valor separado.
/// Paralelo com React: duas propriedades independentes não viram um estado duplicado.
struct ShortcutLibraryDetailView: View {
    let rule: ShortcutRule
    let applications: [ApplicationChoice]
    let wasJustCreated: Bool
    let onSetEnabled: (Bool) -> Void
    let onEdit: () -> Void
    let onPractice: () -> Void
    var captureIsRunning = true
    @State private var showsDetails = false
    @State private var showsGesture = false

    private var resultSummary: String {
        if let first = rule.workflow.enabledSteps.first {
            return RuleEditorSummary.action(first.action, applications: applications)
        }
        if let layout = rule.workflow.sceneLayout { return "Organizar \(layout.windows.count) janelas" }
        return "Nenhuma ação ativa"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .top, spacing: 16) {
                        Text(rule.name).font(.title2.weight(.semibold)).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Toggle("Ativado", isOn: Binding(get: { rule.isEnabled }, set: onSetEnabled))
                            .toggleStyle(.switch).fixedSize()
                            .help("Ativa este atalho. A captura global precisa estar ativa para reconhecer a entrada.")
                            .accessibilityIdentifier("tico.rule.enabled")
                    }
                    if wasJustCreated {
                        Label("Atalho criado", systemImage: "checkmark.circle.fill")
                            .font(.callout).foregroundStyle(.green)
                            .accessibilityIdentifier("tico.rule.created")
                    }
                    availability
                    causalSummary
                    HStack(spacing: 8) {
                        Image(systemName: "globe").foregroundStyle(.secondary)
                        Text(rule.scope.displayName(applications: applications)).font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                        if !rule.conditions.isEmpty {
                            Text("· \(rule.conditions.count) condições")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Divider()
                    DisclosureGroup("Detalhes do atalho", isExpanded: $showsDetails) {
                        details.padding(.top, 14)
                    }
                    .font(.callout)
                }
                .padding(24).frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack {
                Button("Testar acionamento", systemImage: "hand.draw", action: onPractice)
                    .buttonStyle(.borderless)
                    .help("Pratica o reconhecimento sem executar as ações.")
                Spacer()
                Button("Editar atalho", systemImage: "pencil", action: onEdit)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("tico.rule.edit")
            }
            .controlSize(.large).padding(18)
        }
        .background(TicoBrand.Palette.background)
    }

    @ViewBuilder private var availability: some View {
        if !rule.isEnabled {
            Label("Pausado. Ative quando quiser usar este atalho.", systemImage: "pause.circle")
                .font(.callout).foregroundStyle(.secondary)
        } else if !captureIsRunning {
            Label("Atalho ativado. Retome a captura para usá-lo.", systemImage: "pause.circle")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private var causalSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: RuleEditorSummary.symbol(rule.trigger))
                    .font(.title3).foregroundStyle(TicoBrand.Palette.primary).frame(width: 28)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Quando eu usar").font(.caption).foregroundStyle(.secondary)
                    Text(RuleEditorSummary.trigger(rule.trigger))
                        .font(.callout.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "arrow.turn.down.right")
                    .foregroundStyle(.secondary).frame(width: 28)
                VStack(alignment: .leading, spacing: 6) {
                    Text(resultSummary).font(.headline).fixedSize(horizontal: false, vertical: true)
                    if rule.workflow.enabledSteps.count > 1 {
                        Text("e mais \(rule.workflow.enabledSteps.count - 1) \(rule.workflow.enabledSteps.count == 2 ? "ação" : "ações") em sequência")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    if let layout = rule.workflow.sceneLayout, !rule.workflow.enabledSteps.isEmpty {
                        Text("Depois, revisar o layout de \(layout.windows.count) janelas.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(TicoBrand.Palette.surface, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !rule.workflow.steps.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ações").font(.callout.weight(.semibold))
                    ForEach(Array(rule.workflow.steps.enumerated()), id: \.element.id) { index, step in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1).").font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(RuleEditorSummary.action(step.action, applications: applications))
                                    .font(.callout).foregroundStyle(step.isEnabled ? Color.primary : Color.secondary)
                                if !step.isEnabled { Text("Ação pausada").font(.caption).foregroundStyle(.secondary) }
                                if step.delayBefore > 0 {
                                    Text("Aguardar \(step.delayBefore.formatted()) s antes")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            if let layout = rule.workflow.sceneLayout {
                Label("Layout de \(layout.windows.count) janelas, com revisão antes de aplicar.", systemImage: "rectangle.3.group")
                    .font(.callout)
            }
            if !rule.conditions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Somente quando").font(.callout.weight(.semibold))
                    ForEach(Array(rule.conditions.enumerated()), id: \.offset) { _, condition in
                        Text(ShortcutConditionSummary.text(condition)).font(.callout).foregroundStyle(.secondary)
                    }
                }
            }

            if !rule.notes.isEmpty { Text(rule.notes).font(.callout).foregroundStyle(.secondary) }
            DisclosureGroup("Ver acionamento", isExpanded: $showsGesture) {
                // A prévia existe só quando solicitada; listas e detalhes fechados
                // não mantêm animações de gestos funcionando em segundo plano.
                if showsGesture && showsDetails {
                    ShortcutGesturePreview(trigger: rule.trigger, height: 120)
                        .frame(maxWidth: 330).padding(.top, 12)
                }
            }
        }
    }
}
