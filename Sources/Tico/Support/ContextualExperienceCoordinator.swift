import Combine
import Foundation

/// Integra aprendizado e rotinas ao executor existente. O AppController é seu
/// owner e informa exclusão de prática, replay, gravação e pausa explícita.
/// Paralelo com React: composição de estados especializados, sem duplicar suas
/// fontes de verdade nem executar efeitos dentro da árvore visual.
@MainActor
final class ContextualExperienceCoordinator: ObservableObject {
    let learning: ShortcutLearningStore
    let routineStore: DisplayRoutineStore
    let sceneLayouts: SceneLayoutSession
    var onPractice: ((UUID) -> Void)?
    @Published private(set) var message: String?

    private let store: ShortcutStore
    private let automation: AutomationCoordinator
    private let allowsExecution: Bool
    private let feedback = ExperiencePanelPresenter()
    private var subscriptions = Set<AnyCancellable>()
    private var suspended = false
    private var pausedByUser = false
    private var presentedFeedbackID: UUID?

    /// O handle pertence à execução, não ao workflowID reutilizável. Cancelá-lo
    /// nunca atinge uma execução manual mais recente da mesma cena. O token também
    /// impede que a conclusão antiga limpe o estado de outra rotina.
    private struct RoutineExecution {
        let token: UUID
        let intent: DisplayRoutineExecutionIntent
        let task: Task<WorkflowExecutionReport, Never>
    }
    private var routineExecution: RoutineExecution?

    lazy var displayRoutines = DisplayRoutineCoordinator(
        store: routineStore,
        workflowLookup: { [weak self] id in self?.store.reusableWorkflows.first { $0.id == id } },
        isExecutionAllowed: { [weak self] in self?.canExecuteRoutine == true },
        onAutomaticExecution: { [weak self] intent in self?.executeRoutine(intent, automatically: true) },
        onExecutionContextChanged: { [weak self] in self?.invalidateRoutineIfNeeded() })

    init(store: ShortcutStore, automation: AutomationCoordinator,
         sceneLayouts: SceneLayoutSession, allowsExecution: Bool) {
        self.store = store
        self.automation = automation
        self.sceneLayouts = sceneLayouts
        self.allowsExecution = allowsExecution
        let directory = store.fileURL.deletingLastPathComponent()
        learning = ShortcutLearningStore(dataURL: directory.appendingPathComponent("learning.json"))
        routineStore = DisplayRoutineStore(dataURL: directory.appendingPathComponent("display-routines.json"))
        sceneLayouts.workflowSource = { [weak store] workflow in
            guard let store else { return nil }
            let sources = store.reusableWorkflows + store.rules.map(\.workflow)
            // O painel de conteúdo pode fixar alvos relativos nas ações. A origem
            // canônica continua identificada pelo workflow e pelo mesmo layout.
            return sources.first { $0 == workflow }
                ?? sources.first { $0.id == workflow.id && $0.sceneLayout == workflow.sceneLayout }
        }

        automation.onExecutionFinished = { [weak self] rule, report, origin in
            self?.didFinish(rule: rule, report: report, origin: origin)
        }
        store.$rules.receive(on: RunLoop.main).sink { [weak self] rules in
            self?.learning.synchronize(rules: rules)
            guard let self else { return }
            self.sceneLayouts.reconcileResumableWorkflows(rules.map(\.workflow) + self.store.reusableWorkflows)
        }.store(in: &subscriptions)
        store.$reusableWorkflows.dropFirst().receive(on: RunLoop.main).sink { [weak self] workflows in
            guard let self else { return }
            displayRoutines.rebaseline()
            self.sceneLayouts.reconcileResumableWorkflows(workflows + self.store.rules.map(\.workflow))
        }.store(in: &subscriptions)
        learning.$prompt.receive(on: RunLoop.main).sink { [weak self] _ in
            self?.refreshFeedback()
        }.store(in: &subscriptions)
        displayRoutines.$suggestion.receive(on: RunLoop.main).sink { [weak self] _ in
            self?.refreshFeedback()
        }.store(in: &subscriptions)
        if allowsExecution {
            displayRoutines.start()
            displayRoutines.setRuntimeAvailable(true)
        }
    }

    deinit { routineExecution?.task.cancel() }

    func setSuspended(_ value: Bool) {
        suspended = value
        sceneLayouts.interactionIsSuspended = value
        updateAvailability()
    }

    func setPausedByUser(_ value: Bool) {
        pausedByUser = value
        if value { sceneLayouts.cancelOperation() }
        updateAvailability()
    }

    func acceptRoutine(_ id: UUID) {
        guard let intent = displayRoutines.acceptSuggestion(routineID: id) else { return }
        executeRoutine(intent)
    }

    private var canExecuteRoutine: Bool {
        allowsExecution && !suspended && !pausedByUser
            && routineExecution == nil
            && automation.runningRuleIDs.isEmpty && !sceneLayouts.isBusy
    }

    private func updateAvailability() {
        displayRoutines.setRuntimeAvailable(allowsExecution && !suspended && !pausedByUser)
        if suspended || pausedByUser {
            learning.dismissPrompt()
            feedback.close()
        }
    }

    private func didFinish(rule: ShortcutRule, report: WorkflowExecutionReport,
                           origin: AutomationExecutionOrigin) {
        guard allowsExecution, !suspended, report.success,
              let current = store.rules.first(where: { $0.id == rule.id }),
              current.updatedAt == rule.updatedAt else { return }
        switch origin {
        case .trigger: learning.recordGestureSuccess(rule: current)
        case .contextualPanel: learning.recordPanelSuccess(rule: current)
        case .contentPanel, .scene, .displayRoutine: break
        }
    }

    private func executeRoutine(_ intent: DisplayRoutineExecutionIntent, automatically: Bool = false) {
        guard !automatically || DisplayRoutineCoordinator.supportsAutomaticExecution(intent.workflow) else { return }
        guard canExecuteRoutine, displayRoutines.validate(intent: intent) else { return }
        let workflow = intent.workflow
        let rule = ShortcutRule(id: workflow.id, name: workflow.name, isEnabled: false,
            trigger: .keyboard(keyCode: 49, modifiers: []),
            action: workflow.steps.first?.action ?? .notification(title: "Tico", body: "Cena"),
            workflow: workflow)
        if let task = automation.runManually(rule, origin: .displayRoutine, requiresLayoutReview: !automatically) {
            let token = UUID()
            routineExecution = RoutineExecution(token: token, intent: intent, task: task)
            Task { @MainActor [weak self] in
                _ = await task.value
                guard let self, routineExecution?.token == token else { return }
                routineExecution = nil
            }
        }
        feedback.close()
    }

    /// Inclui a rotina aceita por sugestão que aguarda a revisão de layout: o
    /// cancelamento da Task chega ao handler da continuação de SceneLayoutSession.
    /// Efeitos já concluídos não são desfeitos; recuperação segue sob seu owner.
    private func invalidateRoutineIfNeeded() {
        guard let execution = routineExecution,
              !displayRoutines.executionContextIsCurrent(execution.intent) else { return }
        routineExecution = nil
        execution.task.cancel()
        message = "Rotina interrompida porque o ambiente ou a configuração mudou. As ações já concluídas foram preservadas."
    }

    private func refreshFeedback() {
        guard allowsExecution, !suspended, !pausedByUser else {
            presentedFeedbackID = nil
            feedback.close()
            return
        }
        if let suggestion = displayRoutines.suggestion {
            guard presentedFeedbackID != suggestion.id else { return }
            presentedFeedbackID = suggestion.id
            feedback.show(DisplayRoutinePromptView(suggestion: suggestion,
                onAccept: { [weak self] in self?.acceptRoutine($0) },
                onDismiss: { [weak self] in self?.displayRoutines.dismissSuggestion() }),
                purpose: .feedback, onClose: { [weak self] in
                    guard let self, displayRoutines.suggestion?.id == suggestion.id else { return }
                    displayRoutines.dismissSuggestion()
                })
        } else if let prompt = learning.prompt {
            guard presentedFeedbackID != prompt.id else { return }
            presentedFeedbackID = prompt.id
            feedback.show(ShortcutLearningPromptView(prompt: prompt,
                onPractice: { [weak self] in
                    self?.learning.dismissPrompt()
                    self?.onPractice?(prompt.ruleID)
                },
                onMastered: { [weak self] in self?.performLearningAction { try $0.markMastered() } },
                onSnooze: { [weak self] in self?.performLearningAction { try $0.snooze() } },
                onDismiss: { [weak self] in self?.learning.dismissPrompt() }),
                purpose: .feedback, onClose: { [weak self] in
                    guard let self, learning.prompt?.id == prompt.id else { return }
                    learning.dismissPrompt()
                })
        } else {
            presentedFeedbackID = nil
            feedback.close()
        }
    }

    private func performLearningAction(_ action: (ShortcutLearningStore) throws -> Void) {
        do { try action(learning); message = nil }
        catch { message = error.localizedDescription }
    }
}
