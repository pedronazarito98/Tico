import Foundation

enum WorkflowFailurePolicy: String, Codable, CaseIterable, Hashable, Sendable {
    case stop
    case continueRemaining
}

struct WorkflowStep: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var action: ShortcutAction
    var delayBefore: TimeInterval
    var timeout: TimeInterval?
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String = "",
        action: ShortcutAction,
        delayBefore: TimeInterval = 0,
        timeout: TimeInterval? = nil,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.action = action
        self.delayBefore = min(max(delayBefore, 0), 300)
        self.timeout = timeout.map { min(max($0, 0.25), 300) }
        self.isEnabled = isEnabled
    }

    var displayName: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? action.displayName : trimmedName
    }
}

struct ActionWorkflow: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var steps: [WorkflowStep]
    var failurePolicy: WorkflowFailurePolicy
    var timeout: TimeInterval

    init(
        id: UUID = UUID(),
        name: String = "",
        steps: [WorkflowStep],
        failurePolicy: WorkflowFailurePolicy = .stop,
        timeout: TimeInterval = 60
    ) {
        self.id = id
        self.name = name
        self.steps = Array(steps.prefix(20))
        self.failurePolicy = failurePolicy
        self.timeout = min(max(timeout, 1), 600)
    }

    init(action: ShortcutAction) {
        self.init(steps: [WorkflowStep(action: action)])
    }

    var enabledSteps: [WorkflowStep] {
        steps.filter(\.isEnabled)
    }

    var isValid: Bool {
        !enabledSteps.isEmpty && steps.count <= 20
    }
}

struct WorkflowStepExecution: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var stepID: UUID
    var stepName: String
    var index: Int
    var result: ActionExecutionResult
    var duration: TimeInterval

    init(
        id: UUID = UUID(),
        stepID: UUID,
        stepName: String,
        index: Int,
        result: ActionExecutionResult,
        duration: TimeInterval
    ) {
        self.id = id
        self.stepID = stepID
        self.stepName = stepName
        self.index = index
        self.result = result
        self.duration = max(0, duration)
    }
}

struct WorkflowExecutionReport: Codable, Hashable, Sendable {
    var workflowID: UUID
    var stepExecutions: [WorkflowStepExecution]
    var startedAt: Date
    var finishedAt: Date
    var wasCancelled: Bool

    var success: Bool {
        !wasCancelled
            && !stepExecutions.isEmpty
            && stepExecutions.allSatisfy(\.result.success)
    }

    var summary: ActionExecutionResult {
        if wasCancelled {
            return .failed("Workflow cancelado.", executedAt: finishedAt)
        }
        if let failure = stepExecutions.first(where: { !$0.result.success }) {
            return .failed(
                "Etapa \(failure.index + 1) — \(failure.stepName): \(failure.result.message)",
                executedAt: finishedAt
            )
        }
        return .succeeded(
            "\(stepExecutions.count) etapa(s) executada(s) com sucesso.",
            executedAt: finishedAt
        )
    }
}

