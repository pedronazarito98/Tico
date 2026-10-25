import Combine
import Foundation

/// Owner do objetivo opt-in. O executor informa somente sucessos reais, após concluir a ação.
/// Paralelo com React: estado observado + transições explícitas; a view apenas envia intenções.
@MainActor
final class ShortcutLearningStore: ObservableObject {
    private enum EligibilityError: LocalizedError {
        case continuousWorkflow

        var errorDescription: String? {
            "Para aprender uma ação contínua, use um atalho com somente essa ação e sem layout de cena."
        }
    }

    @Published private(set) var document = ShortcutLearningDocument()
    @Published private(set) var prompt: ShortcutLearningPrompt?
    @Published private(set) var errorMessage: String?
    @Published private(set) var notice: String?
    private let repository: any ShortcutLearningRepository
    private let now: () -> Date
    private var loadedSuccessfully = false
    private var promptExpiration: Task<Void, Never>?

    /// Preferência de apresentação independente do objetivo. Mantemos isEnabled
    /// como fachada compatível e a chave persistida, sem migração de documentos.
    var isEnabled: Bool { document.isEnabled }
    var remindersEnabled: Bool { document.isEnabled }
    var goal: ShortcutLearningGoal? { document.goal }
    var masteredRuleIDs: Set<UUID> { document.masteredRuleIDs }

    convenience init(dataURL: URL) {
        self.init(repository: FileShortcutLearningRepository(dataURL: dataURL))
    }

    init(repository: any ShortcutLearningRepository, now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.now = now
        do {
            document = try repository.read() ?? ShortcutLearningDocument()
            loadedSuccessfully = true
        } catch { errorMessage = ShortcutLearningError.invalidDocument.localizedDescription }
    }

    deinit { promptExpiration?.cancel() }

    func setEnabled(_ enabled: Bool) throws {
        var candidate = document
        candidate.isEnabled = enabled
        try persist(candidate)
        if !enabled { dismissPrompt() }
    }

    func beginLearning(rule: ShortcutRule) throws {
        guard rule.isEnabled else { throw ShortcutLearningError.disabledRule }
        guard supportsLearning(rule) else { throw EligibilityError.continuousWorkflow }
        var candidate = document
        candidate.isEnabled = true
        candidate.masteredRuleRevisions.removeValue(forKey: rule.id)
        candidate.goal = ShortcutLearningGoal(ruleID: rule.id, ruleRevision: rule.updatedAt)
        try persist(candidate)
        dismissPrompt()
        notice = nil
    }

    /// Chamado somente para execução explícita pelo painel; não observa outros aplicativos.
    func recordPanelSuccess(rule: ShortcutRule) {
        guard document.isEnabled, var goal = matchingGoal(rule) else { return }
        goal.panelSuccesses = min(goal.panelSuccesses + 1, 1_000_000)
        let date = now()
        let cooldown = 20.0 * 60.0 * Double(max(1, goal.gestureSuccesses + 1))
        let shouldRemind = (goal.snoozedUntil.map { $0 <= date } ?? true)
            && (goal.lastReminderAt.map { date.timeIntervalSince($0) >= cooldown } ?? true)
        if shouldRemind { goal.lastReminderAt = date }
        var candidate = document
        candidate.goal = goal
        do {
            try persist(candidate)
            if shouldRemind {
                prompt = ShortcutLearningPrompt(id: UUID(), ruleID: rule.id, title: rule.name,
                    triggerDescription: rule.trigger.displayName, successes: goal.gestureSuccesses)
                schedulePromptExpiration()
            }
        } catch { /* persist mantém o estado e publica erro sanitizado. */ }
    }

    /// Prática e replay não chamam esta entrada. Só o acionamento real concluído
    /// conta. Silenciar dicas não interrompe o acompanhamento solicitado.
    func recordGestureSuccess(rule: ShortcutRule) {
        guard var goal = matchingGoal(rule) else { return }
        goal.gestureSuccesses = min(goal.gestureSuccesses + 1, ShortcutLearningGoal.requiredSuccesses)
        var candidate = document
        if goal.gestureSuccesses == ShortcutLearningGoal.requiredSuccesses {
            candidate.masteredRuleRevisions[rule.id] = rule.updatedAt
            candidate.goal = nil
        } else { candidate.goal = goal }
        do { try persist(candidate); dismissPrompt() } catch { }
    }

    /// Qualquer edição invalida objetivo e conclusão daquela revisão. Usamos
    /// updatedAt de modo conservador: até editar o nome pede nova confirmação,
    /// pois não guardamos cópias de gatilhos nem inferimos equivalência entre eles.
    func synchronize(rules: [ShortcutRule]) {
        var candidate = document
        let currentRevisions = rules.reduce(into: [UUID: Date]()) { revisions, rule in
            revisions[rule.id] = rule.updatedAt
        }
        candidate.masteredRuleRevisions = candidate.masteredRuleRevisions.filter {
            currentRevisions[$0.key] == $0.value
        }
        let hadGoal = document.goal != nil
        if let goal = document.goal,
           !rules.contains(where: {
               $0.id == goal.ruleID && $0.isEnabled && $0.updatedAt == goal.ruleRevision
                   && supportsLearning($0)
           }) {
            candidate.goal = nil
        }
        guard candidate != document else { return }
        do {
            try persist(candidate)
            dismissPrompt()
            if hadGoal, candidate.goal == nil {
                notice = "O atalho em aprendizado foi alterado, pausado ou removido. Escolha um objetivo para continuar."
            }
        } catch { }
    }

    func snooze() throws {
        guard var goal = document.goal else { return }
        goal.snoozedUntil = now().addingTimeInterval(24 * 60 * 60)
        var candidate = document
        candidate.goal = goal
        try persist(candidate)
        dismissPrompt()
    }

    func markMastered() throws {
        guard let goal = document.goal else { return }
        var candidate = document
        candidate.masteredRuleRevisions[goal.ruleID] = goal.ruleRevision
        candidate.goal = nil
        try persist(candidate)
        dismissPrompt()
    }

    /// Remove somente o progresso escolhido. Paralelo com React: uma transição
    /// por identidade preserva os demais itens do store e a preferência de avisos.
    func reset(ruleID: UUID) throws {
        var candidate = document
        candidate.masteredRuleRevisions.removeValue(forKey: ruleID)
        if candidate.goal?.ruleID == ruleID { candidate.goal = nil }
        try persist(candidate)
        if prompt?.ruleID == ruleID { dismissPrompt() }
        notice = nil
    }

    func resetAllLearning() throws {
        try persist(ShortcutLearningDocument())
        dismissPrompt()
        notice = nil
    }

    /// Fachada do reset global anterior; novas superfícies devem nomear o escopo.
    func reset() throws { try resetAllLearning() }

    func unavailableReason(for rule: ShortcutRule) -> String? {
        if !rule.isEnabled { return ShortcutLearningError.disabledRule.localizedDescription }
        if !supportsLearning(rule) { return EligibilityError.continuousWorkflow.localizedDescription }
        if !loadedSuccessfully { return ShortcutLearningError.unavailable.localizedDescription }
        return nil
    }

    func dismissPrompt() {
        promptExpiration?.cancel()
        promptExpiration = nil
        prompt = nil
    }

    private func matchingGoal(_ rule: ShortcutRule) -> ShortcutLearningGoal? {
        guard let goal = document.goal, goal.ruleID == rule.id, rule.isEnabled,
              goal.ruleRevision == rule.updatedAt, supportsLearning(rule) else { return nil }
        return goal
    }

    /// A integração contínua existente confirma somente sua própria ação, sem
    /// executar etapas posteriores ou layout. Não oferecemos um objetivo que
    /// nunca poderia receber uma conclusão real do executor.
    private func supportsLearning(_ rule: ShortcutRule) -> Bool {
        let steps = rule.workflow.enabledSteps
        guard steps.contains(where: {
            if case .continuousWindow = $0.action { return true }
            return false
        }) else { return true }
        return steps.count == 1 && rule.workflow.sceneLayout == nil
    }

    private func persist(_ candidate: ShortcutLearningDocument) throws {
        guard loadedSuccessfully else { throw ShortcutLearningError.unavailable }
        do { try repository.write(candidate) } catch {
            errorMessage = ShortcutLearningError.persistence.localizedDescription
            throw ShortcutLearningError.persistence
        }
        document = candidate
        errorMessage = nil
    }

    private func schedulePromptExpiration() {
        promptExpiration?.cancel()
        promptExpiration = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled else { return }
            self?.prompt = nil
        }
    }
}
