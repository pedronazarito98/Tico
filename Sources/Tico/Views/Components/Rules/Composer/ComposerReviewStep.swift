import SwiftUI

/// A revisão descreve a intenção causal e separa reconhecimento de efeitos reais.
/// A sessão continua sendo a única fonte da regra; ensaiar não executa suas ações.
struct ComposerReviewStep: View {
    @ObservedObject var session: RuleEditingSession
    @ObservedObject var practice: GesturePracticeSession
    let applications: [ApplicationChoice]
    let conflicts: [RuleConflict]
    let isPracticing: Bool
    let canCaptureGlobalInput: Bool
    let onOpenPermissions: () -> Void
    let onEditTrigger: () -> Void
    let onEditAction: () -> Void
    let onOptions: () -> Void
    var availableWidth: CGFloat = 900
    @State private var showsScope = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text(isPracticing ? (practice.lastInputMatched ? "Acionamento reconhecido" : "Faça seu acionamento") : "Confira seu atalho")
                    .font(.title2.weight(.semibold))
                Text(isPracticing ? "Este teste reconhece a entrada. As ações não serão executadas." : "Este é o resultado que você vai ter ao usar o atalho.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("QUANDO EU USAR").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                        TriggerKeycaps(trigger: session.draft.trigger)
                    }
                    Spacer()
                    Button("Alterar acionamento", action: onEditTrigger).buttonStyle(.borderless).fixedSize()
                }
                Divider()
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("O TICO VAI").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                        ForEach(session.draft.workflow.enabledSteps) { step in
                            HStack(spacing: 10) {
                                ShortcutActionIcon(action: step.action, applications: applications, size: 28)
                                Text(RuleEditorSummary.action(step.action, applications: applications))
                                    .font(.callout.weight(.medium))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        if let layout = session.draft.workflow.sceneLayout {
                            Label("Organizar \(layout.windows.count) janelas após revisar o layout", systemImage: "rectangle.3.group")
                                .font(.callout)
                        }
                    }
                    Spacer()
                    Button("Alterar ações", action: onEditAction).buttonStyle(.borderless).fixedSize()
                }
            }
            .padding(18).background(TicoBrand.Palette.surface, in: .rect(cornerRadius: 12))
            if isPracticing { practiceFeedback }
            else { savedConfiguration }
        }
        .frame(maxWidth: 760, alignment: .leading)
    }

    private var practiceFeedback: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(practice.lastInputMatched ? "A entrada corresponde ao seu atalho." : practice.feedback,
                  systemImage: practice.lastInputMatched ? "checkmark.circle.fill" : "hand.draw")
                .foregroundStyle(practice.lastInputMatched ? Color.green : Color.secondary)
            if !practice.lastInputMatched, let observed = practice.lastReceivedDescription {
                (availableWidth < 640 ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                                     : AnyLayout(HStackLayout(spacing: 12))) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recebido: \(observed)").font(.callout.weight(.medium))
                        Text("Esperado: \(RuleEditorSummary.trigger(session.draft.trigger))")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Button("Ajustar acionamento", action: onEditTrigger)
                        .fixedSize()
                }
            }
            Text("As janelas e os aplicativos permanecem como estão durante este teste.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(TicoBrand.Palette.primary.opacity(0.05), in: .rect(cornerRadius: 10))
    }

    private var savedConfiguration: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Text("Nome").font(.callout).foregroundStyle(.secondary).frame(width: 105, alignment: .leading)
                TextField("Nome do atalho", text: $session.draft.name).textFieldStyle(.plain)
                    .accessibilityIdentifier("tico.composer.name")
            }
            HStack(spacing: 12) {
                Text("Disponível em").font(.callout).foregroundStyle(.secondary).frame(width: 105, alignment: .leading)
                Button { showsScope = true } label: {
                    Label(session.draft.scope.displayName(applications: applications), systemImage: "globe")
                }.buttonStyle(.borderless).accessibilityIdentifier("tico.composer.scope")
                    .popover(isPresented: $showsScope) {
                        ShortcutScopePicker(scope: $session.draft.scope, applications: applications)
                    }
                Spacer()
            }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ativar ao salvar").font(.callout.weight(.medium))
                    Text(session.draft.isEnabled ? "Pronto para usar quando a captura estiver ativa." : "Será salvo pausado. Você pode ativá-lo depois.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Ativar ao salvar", isOn: $session.draft.isEnabled).labelsHidden().toggleStyle(.switch)
                    .accessibilityIdentifier("tico.composer.enabled")
            }
            if !canCaptureGlobalInput && session.draft.isEnabled {
                (availableWidth < 640 ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                                     : AnyLayout(HStackLayout(spacing: 12))) {
                    Label("Autorize a captura para usar fora do Tico.", systemImage: "hand.raised")
                        .font(.callout).foregroundStyle(.secondary)
                    Button("Abrir Ajustes", action: onOpenPermissions).buttonStyle(.borderless)
                        .fixedSize()
                }
            }
            ForEach(Array(conflicts.enumerated()), id: \.offset) { _, conflict in
                Label(conflict.message, systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(.orange)
            }
            if let issue = session.validationMessage {
                Label(issue, systemImage: "exclamationmark.circle").foregroundStyle(.orange).font(.callout)
            }
            Button("Mais ajustes", systemImage: "slider.horizontal.3", action: onOptions)
                .buttonStyle(.borderless).accessibilityIdentifier("tico.composer.options")
        }
    }
}
