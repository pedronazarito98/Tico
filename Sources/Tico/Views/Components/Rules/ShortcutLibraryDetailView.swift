import SwiftUI

/// Leitura da regra selecionada. Captura global, ativação e última execução são
/// valores independentes; praticar e editar continuam ações explícitas.
/// Paralelo com React: as propriedades recebidas dirigem a tela sem copiar o store.
struct ShortcutLibraryDetailView: View {
    let rule: ShortcutRule
    let applications: [ApplicationChoice]
    let wasJustCreated: Bool
    let latestExecution: ActionExecutionResult?
    let onSetEnabled: (Bool) -> Void
    let onEdit: () -> Void
    let onPractice: () -> Void
    var captureIsRunning = true

    private var firstEnabledAction: ShortcutAction? { rule.workflow.enabledSteps.first?.action }

    private var resultSummary: String {
        if let firstEnabledAction {
            return RuleEditorSummary.action(firstEnabledAction, applications: applications)
        }
        if let layout = rule.workflow.sceneLayout { return "Revisar layout de \(layout.windows.count) janelas" }
        return "Nenhuma ação ativa"
    }

    private var availabilityText: String {
        if !rule.isEnabled { return "Atalho pausado" }
        return captureIsRunning ? "Atalho e captura ativos" : "Atalho ativado · captura pausada"
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    if wasJustCreated {
                        Label("Atalho criado", systemImage: "checkmark.circle.fill")
                            .font(.callout).foregroundStyle(.green)
                            .padding(.top, 12)
                            .accessibilityIdentifier("tico.rule.created")
                    }
                    Divider().padding(.vertical, 24)
                    VStack(alignment: .leading, spacing: 18) {
                        Label("Acionamento", systemImage: RuleEditorSummary.symbol(rule.trigger))
                            .font(.headline)
                            .labelStyle(ShortcutDetailLabelStyle())
                        ShortcutLibraryTriggerView(trigger: rule.trigger)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Divider().padding(.top, 24)
                    ShortcutDetailRow(title: "Ação", systemImage: "arrow.up.right") {
                        actions
                    }
                    ShortcutDetailRow(title: "Escopo", systemImage: "square.3.layers.3d") {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(rule.scope.displayName(applications: applications))
                            if rule.conditions.isEmpty {
                                Text("Sem condições adicionais").font(.caption).foregroundStyle(.secondary)
                            } else {
                                ForEach(Array(rule.conditions.enumerated()), id: \.offset) { _, condition in
                                    Text(ShortcutConditionSummary.text(condition))
                                        .font(.caption).foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    ShortcutDetailRow(title: "Status", systemImage: "power") {
                        Text(availabilityText).foregroundStyle(.secondary)
                    }
                    ShortcutDetailRow(title: "Última execução", systemImage: "clock.arrow.circlepath") {
                        if let latestExecution {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(latestExecution.success ? "Concluída" : "Não concluída")
                                Text(latestExecution.executedAt, format: .dateTime.day().month().year().hour().minute())
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Nenhuma execução registrada").foregroundStyle(.secondary)
                                .help("O histórico local é limitado e pode ser limpo.")
                        }
                    }
                    if !rule.notes.isEmpty {
                        ShortcutDetailRow(title: "Anotações", systemImage: "text.alignleft") {
                            Text(rule.notes).foregroundStyle(.secondary).textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(24).frame(maxWidth: 820, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack {
                Button("Testar acionamento", systemImage: "hand.draw", action: onPractice)
                    .buttonStyle(.borderless)
                    .help("Pratica o reconhecimento sem executar as ações.")
                Spacer(minLength: 12)
                Button("Editar atalho", systemImage: "pencil", action: onEdit)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("tico.rule.edit")
            }
            .controlSize(.large).padding(18)
        }
        .background(TicoBrand.Palette.background)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            if let firstEnabledAction {
                ShortcutActionIcon(action: firstEnabledAction, applications: applications, size: 40)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(rule.name).font(.title2.weight(.semibold)).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Text(resultSummary).font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle("Ativado", isOn: Binding(get: { rule.isEnabled }, set: onSetEnabled))
                .toggleStyle(.switch).fixedSize()
                .help("Ativa este atalho. A captura global precisa estar ativa para reconhecer a entrada.")
                .accessibilityIdentifier("tico.rule.enabled")
        }
    }

    /// As etapas continuam em ordem, inclusive as pausadas e os tempos de espera.
    /// A prévia não executa a ação e não omite o layout que será revisado depois.
    private var actions: some View {
        VStack(alignment: .leading, spacing: 12) {
            if rule.workflow.steps.isEmpty && rule.workflow.sceneLayout == nil {
                Text("Nenhuma ação configurada").foregroundStyle(.secondary)
            }
            ForEach(Array(rule.workflow.steps.enumerated()), id: \.element.id) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    ShortcutActionIcon(action: step.action, applications: applications, size: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        if rule.workflow.steps.count > 1 {
                            Text("Ação \(index + 1)").font(.caption).foregroundStyle(.secondary)
                        }
                        Text(RuleEditorSummary.action(step.action, applications: applications))
                            .foregroundStyle(step.isEnabled ? Color.primary : Color.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if !step.isEnabled { Text("Ação pausada").font(.caption).foregroundStyle(.secondary) }
                        if step.delayBefore > 0 {
                            Text("Aguardar \(step.delayBefore.formatted()) s antes")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if let layout = rule.workflow.sceneLayout {
                Label("Revisar o layout de \(layout.windows.count) janelas antes de aplicar.", systemImage: "rectangle.3.group")
                    .font(.callout)
            }
        }
    }
}

/// Agrupa título e valor em uma linha larga e os empilha em uma janela estreita.
private struct ShortcutDetailRow<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 20) {
                Label(title, systemImage: systemImage)
                    .font(.headline).labelStyle(ShortcutDetailLabelStyle())
                    .frame(width: 150, alignment: .leading)
                content.frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: systemImage)
                    .font(.headline).labelStyle(ShortcutDetailLabelStyle())
                content.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.callout).padding(.vertical, 16)
        .accessibilityElement(children: .combine)
        Divider()
    }
}

/// Ícones de seção usam o mesmo destaque discreto em todos os valores do resumo.
private struct ShortcutDetailLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.icon.foregroundStyle(TicoBrand.Palette.primary)
                .frame(width: 28, height: 28)
                .background(TicoBrand.Palette.primary.opacity(0.08), in: .rect(cornerRadius: 7))
                .accessibilityHidden(true)
            configuration.title
        }
    }
}
