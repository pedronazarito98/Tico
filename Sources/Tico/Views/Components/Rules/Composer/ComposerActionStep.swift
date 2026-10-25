import SwiftUI

/// Escolha e configuração compartilham o mesmo rascunho, no mesmo contexto.
/// Paralelo com React: os parâmetros são filhos controlados do formulário; abrir
/// a sequência só expõe mais campos, sem copiar nem substituir o estado.
struct ComposerActionStep: View {
    @ObservedObject var session: RuleEditingSession
    let applications: [ApplicationChoice]
    let macOSShortcuts: [String]
    let reusableWorkflows: [ActionWorkflow]
    @Binding var search: String
    let onChoose: (ShortcutAction, String) -> Void
    let onMoreActions: () -> Void
    let onSaveReusableWorkflow: (ActionWorkflow) throws -> Void
    var availableWidth: CGFloat = 900
    @State private var showsSequence = false

    private var validationIssue: String? {
        session.draft.workflow.steps.count == 1 && session.draft.workflow.sceneLayout == nil
            ? WorkflowEditorValidation.issue(in: session.draft.action)
            : WorkflowEditorValidation.issue(in: session.draft.workflow)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("O que você quer fazer?").font(.title2.weight(.semibold))
                Text("Escolha o resultado e ajuste só o que precisar.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            // A mesma árvore muda de eixo; texto parcial e foco dos parâmetros
            // sobrevivem ao redimensionamento, assim como filhos React com key estável.
            (availableWidth < 720 ? AnyLayout(VStackLayout(alignment: .leading, spacing: 18))
                                  : AnyLayout(HStackLayout(alignment: .top, spacing: 20))) {
                ShortcutActionCatalogView(applications: applications,
                    selectedAction: session.hasChosenAction ? session.draft.workflow.steps.first?.action : nil,
                    search: $search, onSelect: onChoose, onMoreActions: onMoreActions)
                    .frame(width: availableWidth < 720 ? nil : 260, height: availableWidth < 720 ? 220 : 430)
                Rectangle().fill(.separator)
                    .frame(width: availableWidth < 720 ? nil : 1, height: availableWidth < 720 ? 1 : 430)
                VStack(alignment: .leading, spacing: 18) {
                    if session.hasChosenAction {
                        configuredAction
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            Image(systemName: "cursorarrow.click")
                                .font(.system(size: 30, weight: .light))
                                .foregroundStyle(TicoBrand.Palette.primary)
                            Text("Comece com uma ação").font(.headline)
                            Text("Os detalhes aparecem aqui. Você pode adicionar outras ações depois.")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 34)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .id("composer-action-parameters")
            }
        }
        .onAppear { showsSequence = session.draft.workflow.steps.count > 1 || session.draft.workflow.sceneLayout != nil }
        .onChange(of: session.draft.workflow.steps.count) {
            if session.draft.workflow.steps.count > 1 { showsSequence = true }
        }
    }

    private var configuredAction: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                if session.draft.workflow.steps.isEmpty, let layout = session.draft.workflow.sceneLayout {
                    Label("Organizar \(layout.windows.count) janelas", systemImage: "rectangle.3.group")
                        .font(.headline)
                } else {
                    ShortcutActionIcon(action: session.draft.action, applications: applications, size: 36)
                    Text(RuleEditorSummary.action(session.draft.action, applications: applications))
                        .font(.headline).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            if !session.draft.workflow.steps.isEmpty {
              ComposerActionParameters(action: $session.draft.action, applications: applications,
                macOSShortcuts: macOSShortcuts,
                showsSelectionTiming: session.draft.workflow.enabledSteps.count > 1)
                // Manter identidade conserva uma URL ainda incompleta ao expandir
                // a sequência; o valor persistível continua sujeito à validação.
                .frame(height: showsSequence ? 0 : nil, alignment: .top).clipped()
                .disabled(showsSequence).accessibilityHidden(showsSequence)
            }
            DisclosureGroup(isExpanded: $showsSequence) {
                WorkflowEditorView(workflow: $session.draft.workflow, applications: applications,
                    macOSShortcuts: macOSShortcuts, reusableWorkflows: reusableWorkflows,
                    onSaveReusable: onSaveReusableWorkflow)
                    .padding(.top, 14)
            } label: {
                Text(session.draft.workflow.steps.count > 1
                     ? "\(session.draft.workflow.steps.count) ações · editar sequência"
                     : "Mais ações e opções")
                    .font(.callout)
            }
            if let issue = validationIssue {
                Label(issue, systemImage: "info.circle")
                    .font(.callout).foregroundStyle(.secondary)
                    .accessibilityIdentifier("tico.composer.action-issue")
            }
        }
    }
}
