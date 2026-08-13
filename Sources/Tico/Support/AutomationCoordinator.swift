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
    @Published private(set) var currentContextSnapshot: ContextSnapshot?
    @Published private(set) var pendingScriptApproval: PendingScriptApproval?

    private struct RunningWorkflow {
        let executionID: UUID
        let task: Task<Void, Never>
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

    private var sequenceRuntime = TriggerSequenceRuntime()
    private var sequenceDeadlineTask: Task<Void, Never>?
    private var workflowTasks: [UUID: RunningWorkflow] = [:]
    private var activeContinuousSessions: Set<UUID> = []
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
        setContinuousPhasesEnabled: @escaping (Bool) -> Void
    ) {
        self.shortcutStore = shortcutStore
        self.eventLogStore = eventLogStore
        self.metricsStore = metricsStore
        self.matcher = matcher
        self.workflowExecutor = WorkflowExecutor(actionRunner: actionRunner)
        self.continuousWindowController = continuousWindowController
            ?? ContinuousWindowActionService()
        self.approvalStore = approvalStore ?? AutomationApprovalStore()
        self.contextSnapshotService = contextSnapshotService ?? ContextSnapshotService()
        self.setContinuousPhasesEnabled = setContinuousPhasesEnabled

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
            context: context,
            profiles: shortcutStore.profiles
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
        for sessionID in activeContinuousSessions {
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
        workflowTasks[ruleID] = nil
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

    private func execute(
        _ rules: [ShortcutRule],
        event: InputEventDescriptor? = nil
    ) {
        guard !rules.isEmpty else { return }

        for rule in rules {
            cancelWorkflow(ruleID: rule.id)
            let executionID = UUID()
            let task = Task { @MainActor [weak self] in
                guard let self else { return }
                let report = await workflowExecutor.execute(
                    rule.workflow,
                    approval: { [weak self] content in
                        guard let self else { return false }
                        return await self.requestScriptApproval(
                            ruleName: rule.name,
                            command: content,
                            ruleID: rule.id,
                            executionID: executionID
                        )
                    }
                )
                guard !Task.isCancelled || report.wasCancelled else { return }
                guard isCurrentWorkflow(executionID, ruleID: rule.id) else { return }

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
            }
            workflowTasks[rule.id] = RunningWorkflow(
                executionID: executionID,
                task: task
            )
        }
    }

    private func isCurrentWorkflow(_ executionID: UUID, ruleID: UUID) -> Bool {
        workflowTasks[ruleID]?.executionID == executionID
    }

    private func cancelAllWorkflows() {
        workflowTasks.values.forEach { $0.task.cancel() }
        workflowTasks.removeAll()
    }

    private func handleContinuousAction(
        event: InputEventDescriptor,
        context: ContextSnapshot
    ) -> Bool {
        guard let gestureEvent = event.gestureEvent else { return false }

        if activeContinuousSessions.contains(gestureEvent.sessionID) {
            do {
                switch gestureEvent.phase {
                case .began:
                    break
                case .changed:
                    try continuousWindowController.update(
                        sessionID: gestureEvent.sessionID,
                        progress: continuousProgress(for: gestureEvent),
                        curve: continuousAction(for: event, context: context)?.curve ?? .linear
                    )
                case .ended:
                    continuousWindowController.commit(sessionID: gestureEvent.sessionID)
                    activeContinuousSessions.remove(gestureEvent.sessionID)
                case .cancelled:
                    try continuousWindowController.cancel(sessionID: gestureEvent.sessionID)
                    activeContinuousSessions.remove(gestureEvent.sessionID)
                }
            } catch {
                reportError(error)
            }
            return true
        }

        guard gestureEvent.phase == .began || gestureEvent.phase == .changed,
              let action = continuousAction(for: event, context: context) else {
            return false
        }

        do {
            try continuousWindowController.begin(
                sessionID: gestureEvent.sessionID,
                target: action.target,
                operation: action.operation
            )
            activeContinuousSessions.insert(gestureEvent.sessionID)
            if gestureEvent.phase == .changed {
                try continuousWindowController.update(
                    sessionID: gestureEvent.sessionID,
                    progress: continuousProgress(for: gestureEvent),
                    curve: action.curve
                )
            }
        } catch {
            reportError(error)
        }
        return true
    }

    private func continuousAction(
        for event: InputEventDescriptor,
        context: ContextSnapshot
    ) -> (
        target: ApplicationTarget,
        operation: ContinuousWindowOperation,
        curve: ContinuousResponseCurve
    )? {
        let matches = matcher.matchingRules(
            in: shortcutStore.rules,
            for: event,
            context: context,
            profiles: shortcutStore.profiles
        )
        for rule in matches {
            guard let step = rule.workflow.enabledSteps.first,
                  case let .continuousWindow(target, operation, curve) = step.action else {
                continue
            }
            return (target, operation, curve)
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
                at: Date(),
                profiles: shortcutStore.profiles
            )
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
        if approvalStore.isApproved(command) {
            return true
        }
        if approvalRequest != nil {
            resolveScriptApproval(approved: false)
        }
        return await withCheckedContinuation { continuation in
            approvalRequest = ApprovalRequest(
                ruleID: ruleID,
                executionID: executionID,
                continuation: continuation
            )
            pendingScriptApproval = PendingScriptApproval(
                ruleName: ruleName,
                command: command
            )
        }
    }

    private func reportError(_ error: Error) {
        errorHandler?(error.localizedDescription)
    }
}
