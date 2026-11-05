import Combine
import Foundation

struct PendingScriptApproval: Identifiable {
    let id = UUID()
    let ruleName: String
    let command: String
}

/// Coordena regras e efeitos depois que um evento semântico cruza a captura.
/// O MainActor mantém o progresso das sequências, workflows, sessões contínuas
/// e aprovação de scripts em uma única ordem; o processamento bruto permanece
/// no serviço de trackpad. Paralelo com React: este owner distribui ações e
/// estado, mas a serialização do MainActor é própria da concorrência Swift.
@MainActor
final class AutomationCoordinator: ObservableObject, ApplicationTerminationPreparing {
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
    private(set) var acceptsInput = true
    private var isTerminating = false
    private let pipelineMetrics: InputPipelineMetrics
    private var pendingSequenceTrace: UUID?
    private lazy var feedbackWriter = ExecutionFeedbackWriter(history: eventLogStore, metrics: metricsStore,
        onError: { [weak self] in self?.reportError($0) })

    private var sequenceRuntime = TriggerSequenceRuntime()
    private var sequenceDeadlineTask: Task<Void, Never>?
    private var workflowTasks: [UUID: RunningWorkflow] = [:]
    private lazy var continuousAutomation = ContinuousAutomationController(store: shortcutStore, matcher: matcher,
        controller: continuousWindowController, metrics: pipelineMetrics,
        onFinished: { [weak self] rule, report in
            // Preserva o contrato contínuo: feedback observável/callback, sem
            // adicionar histórico ou métricas ao conjunto de efeitos persistidos.
            self?.lastWorkflowReport = report
            self?.onExecutionFinished?(rule, report, .trigger)
        }, onError: { [weak self] in self?.reportError($0) })
    private var contextObservers: Set<UUID> = []
    private var contextObservationTokens: [UUID: UUID] = [:]
    private var contextRevision: UInt64 = 0
    private struct PendingInput {
        let event: InputEventDescriptor
        let request: ContextSnapshotRequest
        let isModifierChange: Bool
        let captureGeneration: UUID
        let contextRevision: UInt64
        let targets: [ApplicationTarget: ContinuousWindowTarget]
    }
    /// Enquanto o primeiro contexto aguarda AX, guarda apenas o changed recente
    /// e o terminal. Não transfere a rajada para Tasks nem para uma fila paralela.
    private struct PreparingContinuousInput {
        var latest: InputEventDescriptor?
        var terminal: InputEventDescriptor?
    }
    private var preparingContinuousInputs: [UUID: PreparingContinuousInput] = [:]
    // Um dreno preserva a ordem sem criar uma Task por evento. A geração de
    // trackpad é independente para não cancelar atalhos de teclado no restart.
    private var pendingInputs: [PendingInput] = []
    private var inputDrain: Task<Void, Never>?
    private var inputGeneration = UUID()
    private var trackpadInputGeneration = UUID()
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
        pipelineMetrics: InputPipelineMetrics = InputPipelineMetrics(),
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
        self.pipelineMetrics = pipelineMetrics

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

    /// O editor completo precisa de título e monitor mesmo para condições em
    /// rascunho. Cada janela mantém sua própria inscrição até fechar o editor.
    func beginContextObservation(id: UUID, modifiers: Set<InputModifier>) {
        guard contextObservers.insert(id).inserted, allowsExecution else { return }
        let request = contextSnapshotService.makeRequest(modifiers: modifiers, at: Date(), includeWindowContext: true)
        contextRevision &+= 1
        let revision = contextRevision
        currentContextSnapshot = request.base
        let token = UUID()
        contextObservationTokens[id] = token
        Task { [weak self] in
            guard let self, let context = await contextSnapshotService.resolve(request),
                  contextObservers.contains(id), contextObservationTokens[id] == token,
                  contextRevision == revision,
                  contextSnapshotService.isCurrent(request) else { return }
            currentContextSnapshot = context
        }
    }

    func endContextObservation(id: UUID) {
        contextObservers.remove(id)
        contextObservationTokens[id] = nil
    }

    /// Avalia um evento normalizado após o AppController conferir a captura.
    func handle(
        event: InputEventDescriptor,
        modifiers: Set<InputModifier>,
        isModifierChange: Bool = false
    ) {
        guard allowsExecution, acceptsInput else { return }
        if let gesture = event.gestureEvent {
            let id = gesture.sessionID
            if continuousAutomation.isClosed(sessionID: id) {
                pipelineMetrics.discard(event.pipelineTraceID)
                return
            }
            if var preparing = preparingContinuousInputs[id] {
                if gesture.phase == .cancelled {
                    pipelineMetrics.discard(preparing.latest?.pipelineTraceID)
                    pipelineMetrics.discard(preparing.terminal?.pipelineTraceID)
                    preparing.latest = nil
                    preparing.terminal = event
                } else if preparing.terminal == nil {
                    if gesture.phase == .ended { preparing.terminal = event }
                    else if gesture.phase == .changed {
                        pipelineMetrics.discard(preparing.latest?.pipelineTraceID)
                        preparing.latest = event
                    } else { pipelineMetrics.discard(event.pipelineTraceID) }
                } else { pipelineMetrics.discard(event.pipelineTraceID) }
                preparingContinuousInputs[id] = preparing
                return
            }
            if let context = continuousAutomation.context(sessionID: id),
               continuousAutomation.handle(event: event, context: context) { return }
        }
        let preparation = continuousAutomation.prepare(event: event)
        if preparation.isCandidate, let id = event.gestureEvent?.sessionID {
            preparingContinuousInputs[id] = PreparingContinuousInput()
        }
        let request = contextSnapshotService.makeRequest(
            modifiers: modifiers, at: event.timestamp,
            includeWindowContext: !contextObservers.isEmpty || needsWindowContext(for: event)
        )
        contextRevision &+= 1
        let input = PendingInput(event: event, request: request, isModifierChange: isModifierChange,
            captureGeneration: trackpadInputGeneration, contextRevision: contextRevision, targets: preparation.targets)
        if inputDrain == nil, pendingInputs.isEmpty, !request.requiresResolution {
            process(input, context: request.base)
            return
        }
        pendingInputs.append(input)
        guard inputDrain == nil else { return }
        let generation = inputGeneration
        inputDrain = Task { [weak self] in
            guard let self else { return }
            defer { if inputGeneration == generation { inputDrain = nil } }
            while !Task.isCancelled, inputGeneration == generation, !pendingInputs.isEmpty {
                let input = pendingInputs.removeFirst()
                guard let context = await contextSnapshotService.resolve(input.request),
                      !Task.isCancelled, inputGeneration == generation,
                      contextSnapshotService.isCurrent(input.request),
                      input.event.kind != .trackpadGesture || input.captureGeneration == trackpadInputGeneration else {
                    discardPreparingInput(input.event)
                    continue
                }
                process(input, context: context)
            }
        }
    }

    private func process(_ input: PendingInput, context: ContextSnapshot) {
        if input.contextRevision == contextRevision { currentContextSnapshot = context }
        let preparing = input.event.gestureEvent.flatMap { preparingContinuousInputs.removeValue(forKey: $0.sessionID) }
        if preparing?.terminal?.gestureEvent?.phase == .cancelled {
            discardPreparingInput(input.event)
            pipelineMetrics.discard(preparing?.latest?.pipelineTraceID)
            pipelineMetrics.discard(preparing?.terminal?.pipelineTraceID)
            return
        }
        evaluate(event: input.event, context: context, isModifierChange: input.isModifierChange, targets: input.targets)
        let terminalHasValue = preparing?.terminal?.gestureEvent.map { $0.progress != nil || !$0.path.isEmpty } == true
        if let latest = preparing?.latest {
            if terminalHasValue { pipelineMetrics.discard(latest.pipelineTraceID) }
            else { evaluate(event: latest, context: context, targets: input.targets) }
        }
        if let terminal = preparing?.terminal { evaluate(event: terminal, context: context, targets: input.targets) }
    }

    private func discardPreparingInput(_ event: InputEventDescriptor) {
        pipelineMetrics.discard(event.pipelineTraceID)
        guard let id = event.gestureEvent?.sessionID else { return }
        if let preparing = preparingContinuousInputs.removeValue(forKey: id) {
            pipelineMetrics.discard(preparing.latest?.pipelineTraceID)
            pipelineMetrics.discard(preparing.terminal?.pipelineTraceID)
        }
        continuousAutomation.ignore(sessionID: id)
    }

    private func evaluate(event: InputEventDescriptor, context: ContextSnapshot, isModifierChange: Bool = false,
                          targets: [ApplicationTarget: ContinuousWindowTarget]) {
        if continuousAutomation.handle(event: event, context: context, targets: targets) { return }
        if let phase = event.gestureEvent?.phase,
           phase == .changed || phase == .cancelled {
            return
        }

        let input: CapturedInput = isModifierChange
            ? .modifierChange(ModifierChange(keyCode: event.keyCode, modifiers: event.modifiers, timestamp: event.timestamp))
            : .activation(event)
        let evaluation = sequenceRuntime.process(
            input: input,
            rules: shortcutStore.rules,
            context: context
        )
        explanation = AutomationExplanation.evaluate(
            event: event, context: context, rules: shortcutStore.rules, matchedRules: evaluation.matchedRules,
            isWaiting: evaluation.nextDeadline != nil || sequenceRuntime.hasProgress
        )
        if evaluation.nextDeadline != nil {
            pipelineMetrics.discard(pendingSequenceTrace)
            pendingSequenceTrace = event.pipelineTraceID
            pipelineMetrics.beginIntentionalWait(trace: pendingSequenceTrace)
        } else if evaluation.matchedRules.isEmpty { pipelineMetrics.discard(event.pipelineTraceID) }
        scheduleSequenceDeadline(evaluation.nextDeadline)
        execute(evaluation.matchedRules, event: event)
    }

    /// O filtro só decide se AX é necessário; o runtime continua recebendo todos
    /// os eventos. Sequências em progresso e famílias de toque múltiplo exigem
    /// contexto completo para preservar cancelamento e resolução de prefixos.
    private func needsWindowContext(for event: InputEventDescriptor) -> Bool {
        for rule in shortcutStore.rules where rule.isEnabled {
            let needsWindow = rule.conditions.contains { condition in
                switch condition {
                case .windowTitle, .display: true
                case .application, .modifiers, .timeRange: false
                }
            }
            guard needsWindow else { continue }
            // Entradas anteriores ainda aguardando AX podem iniciar/alterar
            // progresso antes desta. Capture o contexto agora, sem retarget
            // posterior, inclusive para que uma tecla errada cancele a sequência.
            if sequenceRuntime.hasProgress || inputDrain != nil { return true }

            switch rule.trigger {
            case let .sequence(sequence):
                if sequence.isValid && sequence.steps.first.map({
                    matcher.matchesStep($0, event: event)
                }) == true { return true }
            case let .trackpad(spec) where spec.gesture == .tap && event.gesture == .tap:
                return true
            default:
                if matcher.matches(rule.trigger, event: event) { return true }
            }
        }
        return false
    }

    /// Cancela os efeitos sem perder seus handles; chamadas repetidas preservam
    /// cleanup e resolução de aprovação idempotentes. Não reinicia efeitos.
    func stop() {
        inputGeneration = UUID()
        inputDrain?.cancel()
        inputDrain = nil
        for input in pendingInputs { pipelineMetrics.discard(input.event.pipelineTraceID) }
        pendingInputs.removeAll()
        contextObservationTokens.removeAll()
        sequenceRuntime.reset()
        sequenceDeadlineTask?.cancel()
        sequenceDeadlineTask = nil
        cancelAllWorkflows()
        cancelContinuousSessions()
        resolveScriptApproval(approved: false)
    }

    /// Interromper o trackpad não cancela workflows independentes de teclado.
    /// Retira identidades antes do efeito para tornar cleanup repetido idempotente.
    func cancelContinuousSessions() {
        trackpadInputGeneration = UUID()
        pendingInputs.removeAll { input in
            guard input.event.kind == .trackpadGesture else { return false }
            pipelineMetrics.discard(input.event.pipelineTraceID)
            return true
        }
        for (id, preparing) in preparingContinuousInputs {
            pipelineMetrics.discard(preparing.latest?.pipelineTraceID)
            pipelineMetrics.discard(preparing.terminal?.pipelineTraceID)
            continuousAutomation.ignore(sessionID: id)
        }
        preparingContinuousInputs.removeAll()
        continuousAutomation.cancelAll()
    }

    /// O chamador de shutdown aguarda esta barreira antes de drenar feedback.
    func drainContinuousSessions() async -> [Error] { await continuousAutomation.drain() }

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
        guard allowsExecution, acceptsInput, rule.workflow.isValid else { return nil }
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
        requiresLayoutReview: Bool = true,
        pipelineTrace: UUID? = nil
    ) -> [Task<WorkflowExecutionReport, Never>] {
        guard allowsExecution, acceptsInput, !rules.isEmpty else { return [] }
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
            let trace = event?.pipelineTraceID ?? pipelineTrace
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
                    pipelineMetrics.mark(.effectStart, trace: trace)
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
                pipelineMetrics.mark(.effectEnd, trace: trace)
                if Task.isCancelled { report.wasCancelled = true }
                guard isCurrentWorkflow(executionID, ruleID: rule.id) else { return report }

                lastWorkflowReport = report
                feedbackWriter.enqueue(rule: rule, report: report, event: event)
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
        // Mantém os handles e identidades até a conclusão real do cleanup.
        // Shutdown e a próxima execução no mesmo alvo aguardam essas tasks.
    }

    /// Suspende todas as entradas, inclusive manual/contexto em voo, antes de
    /// cancelar os efeitos. Retornar o estado anterior permite rollback do quit.
    func suspendForTermination() -> Bool {
        let previous = acceptsInput
        acceptsInput = false
        isTerminating = true
        stop()
        return previous
    }

    func restoreAfterFailedTermination(wasAccepting: Bool) {
        isTerminating = false
        acceptsInput = wasAccepting
    }
    func presentTerminationFailure(_ error: Error) { reportError(error) }

    func drainForTermination() async throws {
        let effects = workflowTasks.values.map(\.task)
        for effect in effects { _ = await effect.value }
        let failures = await continuousAutomation.drain()
        await feedbackWriter.drain()
        try Task.checkCancellation()
        if let failure = failures.first { throw failure }
        try await feedbackWriter.flush()
    }

    /// Barreira explícita para exportação/evidência e saída. Não pertence à vida
    /// da task do efeito; chamar depois que os efeitos esperados terminaram.
    func flushFeedback() async throws { try await feedbackWriter.flush() }

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
            // Uma entrada já capturada pode completar a sequência longa, mas
            // ainda esperar AX. O deadline não pode ultrapassá-la; o runtime
            // decide validade pelo timestamp do evento quando o dreno a avalia.
            while let drain = inputDrain {
                await drain.value
                guard !Task.isCancelled else { return }
            }
            let rules = sequenceRuntime.flushExpired(
                rules: shortcutStore.rules,
                at: Date()
            )
            if !rules.isEmpty {
                explanation = AutomationExplanation(title: "Atalho reconhecido",
                    detail: rules.map(\.name).joined(separator: ", ") + ". O intervalo de reconhecimento terminou.",
                    ruleIDs: rules.map(\.id))
            }
            pipelineMetrics.endIntentionalWait(trace: pendingSequenceTrace)
            execute(rules, pipelineTrace: pendingSequenceTrace)
            if rules.isEmpty { pipelineMetrics.discard(pendingSequenceTrace) }
            pendingSequenceTrace = nil
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
        // Durante o dreno, os stores conservam a falha e o término a apresenta
        // pela lifecycle. Não abre também um alert na ContentView existente.
        guard !isTerminating else { return }
        errorHandler?(error.localizedDescription)
    }
}
