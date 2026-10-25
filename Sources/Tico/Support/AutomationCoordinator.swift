import Combine
import Foundation

struct PendingScriptApproval: Identifiable {
    let id = UUID()
    let ruleName: String
    let command: String
}

/// Owns rule evaluation and automation effects after a semantic input event
/// has crossed the capture boundary.
///
/// The coordinator is main-actor isolated because it owns sequence progress,
/// in-flight workflow tasks, continuous-window sessions and the one pending
/// script-approval continuation. The `TrackpadGestureService` receives only
/// the derived continuous-phase preference through the injected capture
/// boundary; it remains the owner of raw trackpad processing.
@MainActor
final class AutomationCoordinator: ObservableObject {
    @Published private(set) var explanation: AutomationExplanation?
    @Published private(set) var lastWorkflowReport: WorkflowExecutionReport?
    @Published private(set) var runningRuleIDs: Set<UUID> = []
    @Published private(set) var currentContextSnapshot: ContextSnapshot?
    @Published private(set) var pendingScriptApproval: PendingScriptApproval?

    /// O composition root conecta aprendizado e feedback sem consultar histórico.
    /// A conclusão é emitida uma vez, somente para a execução ainda pertencente
    /// a este coordenador. Cancelamentos e falhas continuam explicitamente tipados.
    var onExecutionFinished: ((ShortcutRule, WorkflowExecutionReport, AutomationExecutionOrigin) -> Void)?
    var onContentRequested: ((ShortcutRule) -> Void)?

    private struct RunningWorkflow {
        let executionID: UUID
        let task: Task<WorkflowExecutionReport, Never>
    }

    /// O gesto mantém o mesmo owner até terminar: não rematcheamos uma curva ou
    /// regra diferente no meio do movimento. Contexto e revisão são transitórios.
    /// Uma falha fica marcada até a fase terminal para não reiniciar e dar crédito
    /// ao mesmo gesto após um erro de Acessibilidade.
    private struct ContinuousSession {
        let rule: ShortcutRule
        let context: ContextSnapshot
        let step: WorkflowStep
        let curve: ContinuousResponseCurve
        let startedAt: Date
        var appliedUpdate = false
        var failed = false
    }

    private struct ApprovalRequest {
        let ruleID: UUID
        let executionID: UUID
        let continuation: CheckedContinuation<Bool, Never>
    }

    private let shortcutStore: ShortcutStore
    private let matcher: TriggerMatcher
    private let workflowExecutor: WorkflowExecutor
    private let continuousWindowController: any ContinuousWindowActionControlling
    private let approvalStore: AutomationApprovalStore
    private let contextSnapshotService: any ContextSnapshotProviding
    private let eventLogStore: EventLogStore
    private let metricsStore: MetricsStore
    private let setContinuousPhasesEnabled: (Bool) -> Void
    private let allowsExecution: Bool

    private var sequenceRuntime = TriggerSequenceRuntime()
    private var sequenceDeadlineTask: Task<Void, Never>?
    private var workflowTasks: [UUID: RunningWorkflow] = [:]
    private var activeContinuousSessions: [UUID: ContinuousSession] = [:]
    private var approvalRequest: ApprovalRequest?
    private var cancellables = Set<AnyCancellable>()
    private var errorHandler: ((String) -> Void)?

    init(
        shortcutStore: ShortcutStore,
        eventLogStore: EventLogStore,
        metricsStore: MetricsStore,
        matcher: TriggerMatcher = TriggerMatcher(),
        actionRunner: ActionRunner = ActionRunner(),
        continuousWindowController: (any ContinuousWindowActionControlling)? = nil,
        approvalStore: AutomationApprovalStore? = nil,
        contextSnapshotService: (any ContextSnapshotProviding)? = nil,
        sceneLayouts: SceneLayoutSession? = nil,
        allowsExecution: Bool = true,
        setContinuousPhasesEnabled: @escaping (Bool) -> Void
    ) {
        self.shortcutStore = shortcutStore
        self.eventLogStore = eventLogStore
        self.metricsStore = metricsStore
        self.matcher = matcher
        self.workflowExecutor = WorkflowExecutor(actionRunner: actionRunner, sceneLayouts: sceneLayouts)
        self.continuousWindowController = continuousWindowController
            ?? ContinuousWindowActionService()
        self.approvalStore = approvalStore ?? AutomationApprovalStore()
        self.contextSnapshotService = contextSnapshotService ?? ContextSnapshotService()
        self.setContinuousPhasesEnabled = setContinuousPhasesEnabled
        self.allowsExecution = allowsExecution

        shortcutStore.$rules
            .map { rules in
                rules.contains { rule in
                    rule.isEnabled && rule.workflow.enabledSteps.contains {
                        if case .continuousWindow = $0.action { return true }
                        return false
                    }
                }
            }
            .removeDuplicates()
            .sink { [setContinuousPhasesEnabled] enabled in
                setContinuousPhasesEnabled(enabled)
            }
            .store(in: &cancellables)
    }

    func setErrorHandler(_ handler: @escaping (String) -> Void) {
        errorHandler = handler
    }

    /// Evaluates one already-normalized event. Capture state is checked by
    /// `AppController`; this boundary owns all subsequent automation work.
    func handle(
        event: InputEventDescriptor,
        modifiers: Set<InputModifier>
    ) {
        guard allowsExecution else { return }
        let context = contextSnapshotService.snapshot(
            modifiers: modifiers,
            at: event.timestamp
        )
        currentContextSnapshot = context

        if handleContinuousAction(event: event, context: context) {
            return
        }
        if let phase = event.gestureEvent?.phase,
           phase == .changed || phase == .cancelled {
            return
        }

        let evaluation = sequenceRuntime.process(
            event: event,
            rules: shortcutStore.rules,
            context: context
        )
        explanation = AutomationExplanation.evaluate(
            event: event, context: context, rules: shortcutStore.rules, matchedRules: evaluation.matchedRules,
            isWaiting: evaluation.nextDeadline != nil || sequenceRuntime.hasProgress
        )
        scheduleSequenceDeadline(evaluation.nextDeadline)
        execute(evaluation.matchedRules, event: event)
    }

    /// Cancels all automation owned by this coordinator. Repeated calls are
    /// safe: task cancellation, session cleanup and approval resolution are
    /// all idempotent at this boundary.
    func stop() {
        sequenceRuntime.reset()
        sequenceDeadlineTask?.cancel()
        sequenceDeadlineTask = nil
        cancelAllWorkflows()
        for sessionID in activeContinuousSessions.keys {
            try? continuousWindowController.cancel(sessionID: sessionID)
        }
        activeContinuousSessions.removeAll()
        resolveScriptApproval(approved: false)
    }

    func cancelWorkflow(ruleID: UUID) {
        if let request = approvalRequest,
           request.ruleID == ruleID,
           workflowTasks[ruleID]?.executionID == request.executionID {
            resolveScriptApproval(approved: false)
        }
        workflowTasks[ruleID]?.task.cancel()
        // Mantém a identidade até o executor publicar o relatório de cancelamento.
        // Se outra execução começar, o executionID antigo será descartado normalmente.
    }

    func resolveScriptApproval(approved: Bool) {
        guard let request = approvalRequest else {
            pendingScriptApproval = nil
            return
        }
        if approved, let command = pendingScriptApproval?.command {
            approvalStore.approve(command)
        }
        pendingScriptApproval = nil
        approvalRequest = nil
        request.continuation.resume(returning: approved)
    }

    /// A execução manual passa pela mesma aprovação e pelo mesmo executor das regras.
    @discardableResult
    func runManually(
        _ rule: ShortcutRule,
        origin: AutomationExecutionOrigin = .scene,
        providedContent: AutomationContent? = nil,
        preparedContent: ContentExecutionContext? = nil,
        requiresLayoutReview: Bool = true
    ) -> Task<WorkflowExecutionReport, Never>? {
        guard allowsExecution, rule.workflow.isValid else { return nil }
        explanation = AutomationExplanation(title: "Execução solicitada", detail: rule.name, ruleIDs: [rule.id])
        return execute([rule], origin: origin, providedContent: providedContent,
                       preparedContent: preparedContent, requiresLayoutReview: requiresLayoutReview).first
    }

    @discardableResult
    private func execute(
        _ rules: [ShortcutRule],
        event: InputEventDescriptor? = nil,
        origin: AutomationExecutionOrigin = .trigger,
        providedContent: AutomationContent? = nil,
        preparedContent: ContentExecutionContext? = nil,
        requiresLayoutReview: Bool = true
    ) -> [Task<WorkflowExecutionReport, Never>] {
        guard allowsExecution, !rules.isEmpty else { return [] }
        var tasks: [Task<WorkflowExecutionReport, Never>] = []

        for rule in rules {
            if providedContent == nil, let onContentRequested,
               rule.workflow.enabledSteps.contains(where: {
                   if case let .content(configuration) = $0.action { return configuration.source == .provided }
                   return false
               }) {
                onContentRequested(rule)
                continue
            }
            let precedingTask = workflowTasks[rule.id]?.task
            cancelWorkflow(ruleID: rule.id)
            let executionID = UUID()
            let task = Task { @MainActor [weak self] () -> WorkflowExecutionReport in
                // Espera a limpeza da execução substituída antes de tocar nos
                // mesmos destinos. Cancelar não significa que o efeito já terminou.
                if let precedingTask { _ = await precedingTask.value }
                guard let self else {
                    return WorkflowExecutionReport(workflowID: rule.workflow.id,
                        stepExecutions: [], startedAt: Date(), finishedAt: Date(), wasCancelled: true)
                }
                var report: WorkflowExecutionReport
                if Task.isCancelled {
                    report = WorkflowExecutionReport(workflowID: rule.workflow.id,
                        stepExecutions: [], startedAt: Date(), finishedAt: Date(), wasCancelled: true)
                } else {
                    report = await workflowExecutor.execute(
                    rule.workflow,
                    providedContent: providedContent,
                    preparedContent: preparedContent,
                    approval: { [weak self] content in
                        guard let self else { return false }
                        return await self.requestScriptApproval(
                            ruleName: rule.name,
                            command: content,
                            ruleID: rule.id,
                            executionID: executionID
                        )
                    },
                    requiresLayoutReview: requiresLayoutReview
                    )
                }
                if Task.isCancelled { report.wasCancelled = true }
                guard isCurrentWorkflow(executionID, ruleID: rule.id) else { return report }

                lastWorkflowReport = report
                do {
                    try eventLogStore.record(
                        rule: rule,
                        result: report.summary,
                        stepExecutions: report.stepExecutions
                    )
                } catch {
                    reportError(error)
                }
                metricsStore.record(GestureMetricEvent(
                    occurredAt: report.finishedAt,
                    ruleID: rule.id,
                    ruleName: rule.name,
                    gesture: event?.gesture,
                    deviceID: event?.gestureEvent?.deviceID,
                    outcome: report.wasCancelled
                        ? .cancelled
                        : (report.success ? .success : .failure),
                    confidence: event?.gestureEvent?.confidence,
                    latency: report.finishedAt.timeIntervalSince(report.startedAt)
                ))
                workflowTasks[rule.id] = nil
                runningRuleIDs.remove(rule.id)
                onExecutionFinished?(rule, report, origin)
                return report
            }
            runningRuleIDs.insert(rule.id)
            workflowTasks[rule.id] = RunningWorkflow(
                executionID: executionID,
                task: task
            )
            tasks.append(task)
        }
        return tasks
    }

    private func isCurrentWorkflow(_ executionID: UUID, ruleID: UUID) -> Bool {
        workflowTasks[ruleID]?.executionID == executionID
    }

    private func cancelAllWorkflows() {
        workflowTasks.values.forEach { $0.task.cancel() }
        workflowTasks.removeAll()
        runningRuleIDs.removeAll()
    }

    private func handleContinuousAction(
        event: InputEventDescriptor,
        context: ContextSnapshot
    ) -> Bool {
        guard let gestureEvent = event.gestureEvent else { return false }

        let sessionID = gestureEvent.sessionID
        if var session = activeContinuousSessions[sessionID] {
            let isTerminal = gestureEvent.phase == .ended || gestureEvent.phase == .cancelled
            guard !session.failed else {
                if isTerminal { activeContinuousSessions[sessionID] = nil }
                return true
            }
            guard continuousSessionIsCurrent(session) else {
                session.failed = true
                activeContinuousSessions[sessionID] = isTerminal ? nil : session
                do { try continuousWindowController.cancel(sessionID: sessionID) }
                catch { reportError(error) }
                return true
            }
            do {
                switch gestureEvent.phase {
                case .began:
                    break
                case .changed:
                    try continuousWindowController.update(
                        sessionID: sessionID,
                        progress: continuousProgress(for: gestureEvent),
                        curve: session.curve
                    )
                    session.appliedUpdate = true
                    activeContinuousSessions[sessionID] = session
                case .ended:
                    activeContinuousSessions[sessionID] = nil
                    continuousWindowController.commit(sessionID: sessionID)
                    finishContinuousSession(session)
                case .cancelled:
                    activeContinuousSessions[sessionID] = nil
                    try continuousWindowController.cancel(sessionID: sessionID)
                }
            } catch {
                if var failedSession = activeContinuousSessions[sessionID] {
                    failedSession.failed = true
                    activeContinuousSessions[sessionID] = failedSession
                }
                try? continuousWindowController.cancel(sessionID: sessionID)
                reportError(error)
            }
            return true
        }

        guard gestureEvent.phase == .began || gestureEvent.phase == .changed,
              let action = continuousAction(for: event, context: context) else {
            return false
        }

        var session = ContinuousSession(rule: action.rule, context: context, step: action.step,
            curve: action.curve, startedAt: Date())
        activeContinuousSessions[sessionID] = session
        do {
            try continuousWindowController.begin(
                sessionID: sessionID,
                target: action.target,
                operation: action.operation
            )
            if gestureEvent.phase == .changed {
                try continuousWindowController.update(
                    sessionID: sessionID,
                    progress: continuousProgress(for: gestureEvent),
                    curve: action.curve
                )
                session.appliedUpdate = true
                activeContinuousSessions[sessionID] = session
            }
        } catch {
            session.failed = true
            activeContinuousSessions[sessionID] = session
            try? continuousWindowController.cancel(sessionID: sessionID)
            reportError(error)
        }
        return true
    }

    private func continuousSessionIsCurrent(_ session: ContinuousSession) -> Bool {
        shortcutStore.rules.contains {
            $0.id == session.rule.id && $0.updatedAt == session.rule.updatedAt
                && $0.workflow == session.rule.workflow
                && $0.matches(session.context)
        }
    }

    /// Commit apenas encerra o handle no serviço. Só há sucesso após uma escrita
    /// real sem erro, e somente se essa etapa representar toda a regra. O caminho
    /// contínuo legado não executa etapas posteriores nem layouts; não atribuímos
    /// sucesso a efeitos que não ocorreram.
    private func finishContinuousSession(_ session: ContinuousSession) {
        guard session.appliedUpdate, !session.failed, continuousSessionIsCurrent(session),
              session.rule.workflow.enabledSteps.count == 1,
              session.rule.workflow.sceneLayout == nil else { return }
        let finishedAt = Date()
        let execution = WorkflowStepExecution(stepID: session.step.id,
            stepName: session.step.displayName, index: 0,
            result: .succeeded("Gesto contínuo concluído.", executedAt: finishedAt),
            duration: finishedAt.timeIntervalSince(session.startedAt))
        let report = WorkflowExecutionReport(workflowID: session.rule.workflow.id,
            stepExecutions: [execution], startedAt: session.startedAt,
            finishedAt: finishedAt, wasCancelled: false)
        lastWorkflowReport = report
        onExecutionFinished?(session.rule, report, .trigger)
    }

    private func continuousAction(
        for event: InputEventDescriptor,
        context: ContextSnapshot
    ) -> (
        rule: ShortcutRule,
        step: WorkflowStep,
        target: ApplicationTarget,
        operation: ContinuousWindowOperation,
        curve: ContinuousResponseCurve
    )? {
        let matches = matcher.matchingRules(
            in: shortcutStore.rules,
            for: event,
            context: context
        )
        for rule in matches {
            guard let step = rule.workflow.enabledSteps.first,
                  case let .continuousWindow(target, operation, curve) = step.action else {
                continue
            }
            return (rule, step, target, operation, curve)
        }
        return nil
    }

    private func continuousProgress(for event: GestureEvent) -> Double {
        if let progress = event.progress {
            let signed = switch event.kind {
            case .swipeLeft, .swipeDown, .pinchIn, .rotateClockwise:
                -progress
            default:
                progress
            }
            return min(max(signed, -1), 1)
        }
        guard let start = event.path.first, let end = event.path.last else { return 0 }
        let delta: Double
        switch event.kind {
        case .swipeUp, .swipeDown:
            delta = (end.y - start.y) * 3
        default:
            delta = (end.x - start.x) * 3
        }
        return min(max(delta, -1), 1)
    }

    private func scheduleSequenceDeadline(_ deadline: Date?) {
        sequenceDeadlineTask?.cancel()
        guard let deadline else {
            sequenceDeadlineTask = nil
            return
        }
        let delay = max(0, deadline.timeIntervalSinceNow)
        sequenceDeadlineTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            let rules = sequenceRuntime.flushExpired(
                rules: shortcutStore.rules,
                at: Date()
            )
            if !rules.isEmpty {
                explanation = AutomationExplanation(title: "Atalho reconhecido",
                    detail: rules.map(\.name).joined(separator: ", ") + ". O intervalo de reconhecimento terminou.",
                    ruleIDs: rules.map(\.id))
            }
            execute(rules)
            sequenceDeadlineTask = nil
        }
    }

    private func requestScriptApproval(
        ruleName: String,
        command: String,
        ruleID: UUID,
        executionID: UUID
    ) async -> Bool {
        guard !Task.isCancelled, isCurrentWorkflow(executionID, ruleID: ruleID) else { return false }
        if approvalStore.isApproved(command) {
            return true
        }
        if approvalRequest != nil {
            resolveScriptApproval(approved: false)
        }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard !Task.isCancelled, isCurrentWorkflow(executionID, ruleID: ruleID) else {
                    continuation.resume(returning: false)
                    return
                }
                approvalRequest = ApprovalRequest(ruleID: ruleID, executionID: executionID,
                                                  continuation: continuation)
                pendingScriptApproval = PendingScriptApproval(ruleName: ruleName, command: command)
            }
        } onCancel: {
            // O timeout da etapa pode cancelar antes de o diálogo aparecer.
            // O token impede que essa limpeza recuse uma aprovação mais recente.
            Task { @MainActor [weak self] in
                guard let self, let request = approvalRequest,
                      request.ruleID == ruleID, request.executionID == executionID else { return }
                resolveScriptApproval(approved: false)
            }
        }
    }

    private func reportError(_ error: Error) {
        errorHandler?(error.localizedDescription)
    }
}
