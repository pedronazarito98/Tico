import Foundation
import OSLog

final class WorkflowExecutor {
    private struct TimedExecution {
        var result: ActionExecutionResult
        var reachedWorkflowDeadline: Bool
    }

    private let actionRunner: ActionRunner
    private let now: () -> Date
    private let sceneLayouts: SceneLayoutSession?
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pedronazarito.Tico",
        category: "Workflow"
    )

    init(
        actionRunner: ActionRunner = ActionRunner(),
        now: @escaping () -> Date = Date.init,
        sceneLayouts: SceneLayoutSession? = nil
    ) {
        self.actionRunner = actionRunner
        self.now = now
        self.sceneLayouts = sceneLayouts
    }

    func execute(
        _ workflow: ActionWorkflow,
        providedContent: AutomationContent? = nil,
        preparedContent: ContentExecutionContext? = nil,
        approval: ScriptApprovalHandler? = nil,
        requiresLayoutReview: Bool = true,
        onStep: ((WorkflowStepExecution) -> Void)? = nil
    ) async -> WorkflowExecutionReport {
        let startedAt = now()
        guard workflow.timeout.isFinite,
              (1...600).contains(workflow.timeout),
              (0...20).contains(workflow.steps.count), workflow.isValid else {
            return invalidReport(
                workflow: workflow,
                message: "O workflow contém limites inválidos.",
                startedAt: startedAt
            )
        }
        var layoutReservation: UUID?
        if workflow.sceneLayout != nil {
            guard let sceneLayouts else {
                return invalidReport(workflow: workflow, message: "O serviço de layout não está disponível nesta execução.", startedAt: startedAt)
            }
            do { layoutReservation = try await sceneLayouts.acquireReservation(workflowID: workflow.id) }
            catch {
                if Task.isCancelled {
                    return report(workflow: workflow, executions: [], startedAt: startedAt, cancelled: true)
                }
                return invalidReport(workflow: workflow, message: error.localizedDescription, startedAt: startedAt)
            }
        }
        // O corpo não lança: todo retorno, inclusive os atalhos de erro/cancel,
        // volta por este wrapper. A liberação é aguardada, nunca uma Task solta.
        let result = await executeReserved(workflow, providedContent: providedContent,
            preparedContent: preparedContent, approval: approval, requiresLayoutReview: requiresLayoutReview,
            onStep: onStep, startedAt: startedAt, layoutReservation: layoutReservation)
        if let layoutReservation, let sceneLayouts {
            await sceneLayouts.releaseReservation(layoutReservation)
        }
        return result
    }

    private func executeReserved(
        _ workflow: ActionWorkflow,
        providedContent: AutomationContent?,
        preparedContent: ContentExecutionContext?,
        approval: ScriptApprovalHandler?,
        requiresLayoutReview: Bool,
        onStep: ((WorkflowStepExecution) -> Void)?,
        startedAt: Date,
        layoutReservation: UUID?
    ) async -> WorkflowExecutionReport {
        var executions: [WorkflowStepExecution] = []
        let deadline = startedAt.addingTimeInterval(workflow.timeout)
        // Fixa a seleção antes de atrasos ou efeitos mudarem o foco. O snapshot
        // preparado pelo painel mantém a origem mesmo após editar a entrada.
        let contentContext: ContentExecutionContext
        if let preparedContent {
            contentContext = preparedContent
        } else {
            contentContext = await actionRunner.prepareContentContext(
                actions: workflow.enabledSteps.map(\.action), providedContent: providedContent)
        }
        if Task.isCancelled {
            return report(workflow: workflow, executions: [], startedAt: startedAt, cancelled: true)
        }
        if let issue = contentPreflight(workflow: workflow, context: contentContext) {
            return invalidReport(workflow: workflow, message: issue, startedAt: startedAt)
        }

        for (index, step) in workflow.enabledSteps.enumerated() {
            guard step.delayBefore.isFinite,
                  (0...300).contains(step.delayBefore),
                  step.timeout.map({ $0.isFinite && (0.25...300).contains($0) }) ?? true else {
                let execution = WorkflowStepExecution(
                    stepID: step.id,
                    stepName: step.displayName,
                    index: index,
                    result: .failed("A etapa contém limites inválidos.", executedAt: now()),
                    duration: 0
                )
                executions.append(execution)
                onStep?(execution)
                break
            }
            if Task.isCancelled {
                return report(
                    workflow: workflow,
                    executions: executions,
                    startedAt: startedAt,
                    cancelled: true
                )
            }
            let remainingBeforeDelay = deadline.timeIntervalSince(now())
            guard remainingBeforeDelay > 0 else {
                appendWorkflowTimeout(
                    step: step,
                    index: index,
                    workflowTimeout: workflow.timeout,
                    to: &executions,
                    onStep: onStep
                )
                break
            }

            if step.delayBefore > 0 {
                let delay = min(step.delayBefore, remainingBeforeDelay)
                do {
                    try await Task.sleep(for: .seconds(delay))
                } catch {
                    return report(
                        workflow: workflow,
                        executions: executions,
                        startedAt: startedAt,
                        cancelled: true
                    )
                }
                if step.delayBefore >= remainingBeforeDelay {
                    appendWorkflowTimeout(
                        step: step,
                        index: index,
                        workflowTimeout: workflow.timeout,
                        to: &executions,
                        onStep: onStep
                    )
                    break
                }
            }

            let remainingForAction = deadline.timeIntervalSince(now())
            guard remainingForAction > 0 else {
                appendWorkflowTimeout(
                    step: step,
                    index: index,
                    workflowTimeout: workflow.timeout,
                    to: &executions,
                    onStep: onStep
                )
                break
            }
            let timeoutConfiguration: (
                duration: TimeInterval,
                message: String,
                reachesWorkflowDeadline: Bool
            )
            if let stepTimeout = step.timeout, stepTimeout < remainingForAction {
                timeoutConfiguration = (
                    duration: stepTimeout,
                    message: "A etapa excedeu \(Int(stepTimeout)) s.",
                    reachesWorkflowDeadline: false
                )
            } else {
                timeoutConfiguration = (
                    duration: remainingForAction,
                    message: workflowTimeoutMessage(workflow.timeout),
                    reachesWorkflowDeadline: true
                )
            }
            let stepStartedAt = now()
            logger.info(
                "Starting workflow step \(index + 1, privacy: .public) action=\(step.action.displayName, privacy: .public)"
            )
            let timedExecution = await execute(
                step: step,
                approval: approval,
                contentContext: contentContext,
                timeout: timeoutConfiguration.duration,
                timeoutMessage: timeoutConfiguration.message,
                reachesWorkflowDeadline: timeoutConfiguration.reachesWorkflowDeadline
            )
            let execution = WorkflowStepExecution(
                stepID: step.id,
                stepName: step.displayName,
                index: index,
                result: timedExecution.result,
                duration: now().timeIntervalSince(stepStartedAt)
            )
            executions.append(execution)
            onStep?(execution)
            if timedExecution.reachedWorkflowDeadline {
                break
            }
            if !timedExecution.result.success, workflow.failurePolicy == .stop {
                break
            }
        }

        // Layout é a última etapa da cena. A sessão congela o saldo do deadline
        // enquanto a pessoa revisa; consulta/aplicação continuam limitadas.
        // Cancelamento e relatório permanecem na mesma execução.
        if workflow.sceneLayout != nil, !Task.isCancelled,
           workflow.failurePolicy == .continueRemaining || executions.allSatisfy({ $0.result.success }) {
            let layoutResults: [WorkflowStepExecution]
            if let sceneLayouts, let layoutReservation {
                layoutResults = await sceneLayouts.execute(workflow: workflow, deadline: deadline,
                    reservationToken: layoutReservation, requiresReview: requiresLayoutReview)
            } else {
                layoutResults = [.init(stepID: workflow.id, stepName: "Layout de janelas", index: 0,
                    result: .failed("O serviço de layout não está disponível nesta execução."), duration: 0)]
            }
            let firstIndex = executions.count
            for (offset, var execution) in layoutResults.enumerated() {
                execution.index = firstIndex + offset
                executions.append(execution)
                onStep?(execution)
            }
        }

        return report(
            workflow: workflow,
            executions: executions,
            startedAt: startedAt,
            cancelled: Task.isCancelled
        )
    }

    private func execute(
        step: WorkflowStep,
        approval: ScriptApprovalHandler?,
        contentContext: ContentExecutionContext,
        timeout: TimeInterval,
        timeoutMessage: String,
        reachesWorkflowDeadline: Bool
    ) async -> TimedExecution {

        return await withTaskGroup(of: TimedExecution.self) { group in
            group.addTask { [actionRunner] in
                TimedExecution(
                    result: await actionRunner.execute(
                        step.action,
                        scriptApproval: approval,
                        contentContext: contentContext
                    ),
                    reachedWorkflowDeadline: false
                )
            }
            group.addTask { [now] in
                do {
                    try await Task.sleep(for: .seconds(timeout))
                } catch {
                    return TimedExecution(
                        result: .failed("Etapa cancelada.", executedAt: now()),
                        reachedWorkflowDeadline: false
                    )
                }
                return TimedExecution(
                    result: .failed(timeoutMessage, executedAt: now()),
                    reachedWorkflowDeadline: reachesWorkflowDeadline
                )
            }
            let result = await group.next()
                ?? TimedExecution(
                    result: .failed("A etapa não produziu resultado.", executedAt: now()),
                    reachedWorkflowDeadline: false
                )
            group.cancelAll()
            return result
        }
    }

    /// Valida toda entrada conhecida antes do primeiro efeito. Erros são tipados
    /// e sanitizados: relatórios nunca recebem o texto, URL ou caminho fornecido.
    private func contentPreflight(workflow: ActionWorkflow, context: ContentExecutionContext) -> String? {
        do {
            for step in workflow.enabledSteps {
                guard case let .content(configuration) = step.action else { continue }
                guard configuration.validationMessage == nil else { throw ContentActionError.invalidConfiguration }
                let content: AutomationContent
                switch configuration.source {
                case .provided:
                    guard let value = context.providedContent else { throw ContentActionError.emptyContent }
                    content = value
                case .selection:
                    guard configuration.selectionTiming == .workflowStart else { continue }
                    guard let snapshot = context.initialSelection else { throw ContentActionError.selectionUnavailable }
                    content = try snapshot.get()
                }
                try content.validate()
                guard configuration.accepts(content) else { throw ContentActionError.incompatibleContent }
                if case let .search(destination) = configuration.destination { _ = try destination.url(for: content) }
            }
            return nil
        } catch let error as ContentActionError { return error.localizedDescription }
        catch { return ContentActionError.invalidConfiguration.localizedDescription }
    }

    private func appendWorkflowTimeout(
        step: WorkflowStep,
        index: Int,
        workflowTimeout: TimeInterval,
        to executions: inout [WorkflowStepExecution],
        onStep: ((WorkflowStepExecution) -> Void)?
    ) {
        let execution = WorkflowStepExecution(
            stepID: step.id,
            stepName: step.displayName,
            index: index,
            result: .failed(
                workflowTimeoutMessage(workflowTimeout),
                executedAt: now()
            ),
            duration: 0
        )
        executions.append(execution)
        onStep?(execution)
    }

    private func workflowTimeoutMessage(_ timeout: TimeInterval) -> String {
        "O workflow excedeu o tempo limite de \(Int(timeout)) s."
    }

    private func report(
        workflow: ActionWorkflow,
        executions: [WorkflowStepExecution],
        startedAt: Date,
        cancelled: Bool
    ) -> WorkflowExecutionReport {
        WorkflowExecutionReport(
            workflowID: workflow.id,
            stepExecutions: executions,
            startedAt: startedAt,
            finishedAt: now(),
            wasCancelled: cancelled
        )
    }

    private func invalidReport(
        workflow: ActionWorkflow,
        message: String,
        startedAt: Date
    ) -> WorkflowExecutionReport {
        let execution = WorkflowStepExecution(
            stepID: workflow.steps.first?.id ?? workflow.id,
            stepName: workflow.steps.first?.displayName ?? workflow.name,
            index: 0,
            result: .failed(message, executedAt: now()),
            duration: 0
        )
        return report(
            workflow: workflow,
            executions: [execution],
            startedAt: startedAt,
            cancelled: false
        )
    }
}
