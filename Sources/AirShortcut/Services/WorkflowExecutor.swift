import Foundation
import OSLog

final class WorkflowExecutor {
    private struct TimedExecution {
        var result: ActionExecutionResult
        var reachedWorkflowDeadline: Bool
    }

    private let actionRunner: ActionRunner
    private let now: () -> Date
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pedronazarito.AirShortcut",
        category: "Workflow"
    )

    init(
        actionRunner: ActionRunner = ActionRunner(),
        now: @escaping () -> Date = Date.init
    ) {
        self.actionRunner = actionRunner
        self.now = now
    }

    func execute(
        _ workflow: ActionWorkflow,
        approval: ScriptApprovalHandler? = nil,
        onStep: ((WorkflowStepExecution) -> Void)? = nil
    ) async -> WorkflowExecutionReport {
        let startedAt = now()
        var executions: [WorkflowStepExecution] = []
        guard workflow.timeout.isFinite,
              (1...600).contains(workflow.timeout),
              (1...20).contains(workflow.steps.count) else {
            return invalidReport(
                workflow: workflow,
                message: "O workflow contém limites inválidos.",
                startedAt: startedAt
            )
        }
        let deadline = startedAt.addingTimeInterval(workflow.timeout)

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
        timeout: TimeInterval,
        timeoutMessage: String,
        reachesWorkflowDeadline: Bool
    ) async -> TimedExecution {

        return await withTaskGroup(of: TimedExecution.self) { group in
            group.addTask { [actionRunner] in
                TimedExecution(
                    result: await actionRunner.execute(
                        step.action,
                        scriptApproval: approval
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
