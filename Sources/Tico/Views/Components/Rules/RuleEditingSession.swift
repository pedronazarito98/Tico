import Combine
import Foundation

/// Rascunho e transições do inspetor, sem persistência ou efeitos de plataforma.
/// A sessão sobrevive à troca de linha; os filhos editam o mesmo valor via Binding.
@MainActor
final class RuleEditingSession: ObservableObject, Identifiable {
    let id: UUID
    let isNew: Bool
    @Published var draft: ShortcutRule
    @Published private(set) var hasChosenAction: Bool
    @Published private(set) var hasChosenTrigger: Bool
    @Published var recordingMode: TriggerRecordingMode?
    @Published var advancedTrackpadOptionsAreExpanded = false
    @Published var saveError: String?
    @Published var pendingConflictSave: ShortcutRule?

    private var originalRule: ShortcutRule
    private var suggestedName: String?

    init(rule: ShortcutRule, isNew: Bool = false) {
        id = rule.id
        self.isNew = isNew
        draft = rule
        originalRule = rule
        hasChosenAction = !isNew
        hasChosenTrigger = !isNew
    }

    /// Valores iniciais satisfazem o domínio, mas não contam como escolhas do usuário.
    /// Paralelo com React: flags de formulário impedem enviar um campo ainda não preenchido.
    var composerValidationMessage: String? {
        if !hasChosenAction { return "Escolha o que você quer fazer." }
        if !hasChosenTrigger { return "Grave um gesto ou escolha um acionamento." }
        return validationMessage
    }

    func chooseAction(_ action: ShortcutAction, title: String) {
        if !hasChosenAction || draft.name == suggestedName || draft.name == draft.action.displayName {
            draft.name = title
        }
        suggestedName = title
        draft.action = action
        hasChosenAction = true
    }

    func chooseTrigger(_ trigger: TriggerDefinition) {
        draft.trigger = trigger
        hasChosenTrigger = true
    }

    /// Restaura apenas personalizações opcionais; ação e gesto continuam escolhidos.
    func resetComposerOptions() {
        draft.notes = ""
        draft.scope = .global
        draft.profileID = nil
        draft.priority = 0
        draft.conditions = []
        draft.workflow.timeout = 60
        if let index = draft.workflow.steps.firstIndex(where: \.isEnabled) {
            draft.workflow.steps[index].delayBefore = 0
        }
    }

    var hasUnsavedChanges: Bool {
        draftForPersistence != originalRule
    }

    var draftForPersistence: ShortcutRule {
        draft
    }

    var urlIsValid: Bool {
        guard case let .openURL(url) = draft.action else { return true }
        return RuleURLValidator.isValidWebURL(url)
    }

    var canSave: Bool { validationMessage == nil }

    /// O mesmo diagnóstico alimenta o rodapé e os avisos visíveis; nenhuma seção
    /// recolhida pode permitir que um rascunho incompleto seja salvo silenciosamente.
    var validationMessage: String? {
        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Dê um nome ao seu atalho."
        }
        if case let .customTrackpad(template) = draft.trigger,
           template.samplePaths.count < CustomGestureTemplate.minimumSampleCount
            || template.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Grave três amostras e dê um nome ao gesto personalizado."
        }
        if case let .sequence(sequence) = draft.trigger, !sequence.isValid {
            return "Complete os movimentos da sequência."
        }
        if case let .applications(ids) = draft.scope, ids.isEmpty {
            return "Em Disponível em, selecione um aplicativo ou escolha Todos os apps."
        }
        return WorkflowEditorValidation.issue(in: draft.workflow)
    }

    func markSaved(_ value: ShortcutRule) {
        draft = value
        originalRule = value
        pendingConflictSave = nil
        saveError = nil
    }

    /// Atualizações do store não apagam texto ainda não salvo. A ativação feita na
    /// tabela acompanha o rascunho apenas quando esse campo não foi editado nele.
    func receivePersisted(_ value: ShortcutRule) {
        guard value != originalRule else { return }
        if !hasUnsavedChanges {
            markSaved(value)
        } else {
            if draft.isEnabled == originalRule.isEnabled { draft.isEnabled = value.isEnabled }
            originalRule = value
        }
    }

    func revert() {
        draft = originalRule
        suggestedName = nil
        pendingConflictSave = nil
        saveError = nil
    }

    func stageConflictSave(_ value: ShortcutRule) {
        pendingConflictSave = value
    }

    func clearPendingConflict() {
        pendingConflictSave = nil
    }

    func recordSaveError(_ error: Error) {
        saveError = error.localizedDescription
    }

    func clearSaveError() {
        saveError = nil
    }

    func makePreset() -> GesturePreset {
        GesturePreset(
            name: draft.name,
            summary: draft.notes,
            trigger: draft.trigger,
            workflow: draft.workflow,
            profileID: draft.profileID
        )
    }

    func applyPreset(_ preset: GesturePreset) {
        draft.trigger = preset.trigger
        draft.workflow = preset.workflow
        draft.profileID = preset.profileID
    }

    func beginRecording(_ mode: TriggerRecordingMode) {
        recordingMode = mode
    }

    func finishRecording() {
        recordingMode = nil
    }

}
