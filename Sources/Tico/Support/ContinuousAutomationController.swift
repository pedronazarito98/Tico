import Foundation

/// Owner das sessões contínuas de AutomationCoordinator. Aceita comandos sem
/// aguardar IPC, fixa regra/contexto/alvo e publica sucesso somente depois da
/// confirmação terminal do worker. Uma Task por terminal aguarda cleanup;
/// changed nunca cria Task nem uma segunda fila de atualizações.
@MainActor
final class ContinuousAutomationController {
    private struct Session {
        let rule: ShortcutRule
        let context: ContextSnapshot
        let step: WorkflowStep
        let curve: ContinuousResponseCurve
        let startedAt: Date
        let traceID: UUID?
        var appliedUpdate = false
    }
    struct Preparation {
        var isCandidate = false
        var targets: [ApplicationTarget: ContinuousWindowTarget] = [:]
    }
    private let store: ShortcutStore
    private let matcher: TriggerMatcher
    private let controller: any ContinuousWindowActionControlling
    private let metrics: InputPipelineMetrics
    private let onFinished: (ShortcutRule, WorkflowExecutionReport) -> Void
    private let onError: (Error) -> Void
    private var active: [UUID: Session] = [:]
    private struct Terminal {
        let task: Task<Error?, Never>
        var cancellationRequested: Bool
    }
    private var terminals: [UUID: Terminal] = [:]
    private var closed: [UUID] = []

    init(store: ShortcutStore, matcher: TriggerMatcher, controller: any ContinuousWindowActionControlling,
         metrics: InputPipelineMetrics, onFinished: @escaping (ShortcutRule, WorkflowExecutionReport) -> Void,
         onError: @escaping (Error) -> Void) {
        self.store = store; self.matcher = matcher; self.controller = controller
        self.metrics = metrics; self.onFinished = onFinished; self.onError = onError
    }

    func context(sessionID: UUID) -> ContextSnapshot? { active[sessionID]?.context }
    func isClosed(sessionID: UUID) -> Bool { closed.contains(sessionID) }
    func ignore(sessionID: UUID) {
        guard !closed.contains(sessionID) else { return }
        closed.append(sessionID)
        if closed.count > 128 { closed.removeFirst() }
    }

    /// Captura AppKit sincronicamente antes de o coordenador aguardar contexto.
    /// Um dicionário por alvo evita ler telas novamente para regras equivalentes.
    func prepare(event: InputEventDescriptor) -> Preparation {
        guard let gesture = event.gestureEvent, gesture.phase == .began || gesture.phase == .changed else { return Preparation() }
        var result = Preparation()
        var captured: Set<ApplicationTarget> = []
        for rule in store.rules where rule.isEnabled && matcher.matches(rule.trigger, event: event) {
            guard let step = rule.workflow.enabledSteps.first,
                  case let .continuousWindow(target, _, _) = step.action else { continue }
            result.isCandidate = true
            if captured.insert(target).inserted { result.targets[target] = controller.captureTarget(target) }
        }
        return result
    }

    func handle(event: InputEventDescriptor, context: ContextSnapshot,
                targets: [ApplicationTarget: ContinuousWindowTarget] = [:]) -> Bool {
        guard let gesture = event.gestureEvent else { return false }
        let id = gesture.sessionID
        if isClosed(sessionID: id) { metrics.discard(event.pipelineTraceID); return true }
        if var session = active[id] {
            metrics.discard(event.pipelineTraceID)
            guard isCurrent(session) else { terminate(id, session: session, cancelled: true); return true }
            do {
                switch gesture.phase {
                case .began: break
                case .changed:
                    try controller.update(sessionID: id, progress: progress(for: gesture), curve: session.curve)
                    session.appliedUpdate = true
                    active[id] = session
                case .ended:
                    if gesture.progress != nil || !gesture.path.isEmpty {
                        try controller.update(sessionID: id, progress: progress(for: gesture), curve: session.curve)
                        session.appliedUpdate = true
                    }
                    terminate(id, session: session, cancelled: false)
                case .cancelled: terminate(id, session: session, cancelled: true)
                }
            } catch {
                onError(error)
                terminate(id, session: session, cancelled: true)
            }
            return true
        }
        guard gesture.phase == .began || gesture.phase == .changed else { return false }
        for rule in matcher.matchingRules(in: store.rules, for: event, context: context) {
            guard let step = rule.workflow.enabledSteps.first,
                  case let .continuousWindow(target, operation, curve) = step.action else { continue }
            var session = Session(rule: rule, context: context, step: step, curve: curve,
                startedAt: Date(), traceID: event.pipelineTraceID)
            active[id] = session
            metrics.mark(.effectStart, trace: session.traceID)
            do {
                try controller.begin(sessionID: id, target: target, operation: operation, capturedTarget: targets[target])
                if gesture.phase == .changed {
                    try controller.update(sessionID: id, progress: progress(for: gesture), curve: curve)
                    session.appliedUpdate = true
                    active[id] = session
                }
            } catch {
                onError(error)
                terminate(id, session: session, cancelled: true)
            }
            return true
        }
        return false
    }

    func cancelAll() {
        for (id, session) in active { terminate(id, session: session, cancelled: true) }
        for (id, var terminal) in terminals where !terminal.cancellationRequested {
            terminal.cancellationRequested = true
            terminals[id] = terminal
            _ = controller.cancel(sessionID: id)
            // Um commit já confirmado ainda produz seu feedback real. O
            // resultado do owner AX distingue commit de cancelamento efetivo.
        }
    }

    /// Barreira de efeito para a saída normal; persistência/feedback pertencem
    /// aos seus próprios owners. Erros das confirmações drenadas são explícitos.
    func drain() async -> [Error] {
        var failures: [Error] = []
        while !terminals.isEmpty {
            let tasks = terminals.values.map(\.task)
            for task in tasks { if let error = await task.value { failures.append(error) } }
        }
        return failures
    }

    private func terminate(_ id: UUID, session: Session, cancelled: Bool) {
        active[id] = nil
        ignore(sessionID: id)
        let completion = cancelled ? controller.cancel(sessionID: id) : controller.commit(sessionID: id)
        guard terminals[id] == nil else { return }
        let task = Task { [weak self] () -> Error? in
            guard let self else { return nil }
            defer { terminals[id] = nil; metrics.mark(.effectEnd, trace: session.traceID) }
            do {
                let outcome = try await completion.wait()
                guard outcome == .committed, !cancelled,
                      session.appliedUpdate, isCurrent(session), session.rule.workflow.enabledSteps.count == 1,
                      session.rule.workflow.sceneLayout == nil else { return nil }
                let finishedAt = Date()
                let execution = WorkflowStepExecution(stepID: session.step.id, stepName: session.step.displayName, index: 0,
                    result: .succeeded("Gesto contínuo concluído.", executedAt: finishedAt),
                    duration: finishedAt.timeIntervalSince(session.startedAt))
                onFinished(session.rule, WorkflowExecutionReport(workflowID: session.rule.workflow.id,
                    stepExecutions: [execution], startedAt: session.startedAt, finishedAt: finishedAt, wasCancelled: false))
                return nil
            } catch { onError(error); return error }
        }
        terminals[id] = Terminal(task: task, cancellationRequested: cancelled)
    }

    private func isCurrent(_ session: Session) -> Bool {
        store.rules.contains { $0.id == session.rule.id && $0.updatedAt == session.rule.updatedAt
            && $0.workflow == session.rule.workflow && $0.matches(session.context) }
    }
    private func progress(for event: GestureEvent) -> Double {
        if let progress = event.progress {
            let signed = switch event.kind {
            case .swipeLeft, .swipeDown, .pinchIn, .rotateClockwise: -progress
            default: progress
            }
            return min(max(signed, -1), 1)
        }
        guard let start = event.path.first, let end = event.path.last else { return 0 }
        let delta: Double
        switch event.kind {
        case .swipeUp, .swipeDown: delta = (end.y - start.y) * 3
        default: delta = (end.x - start.x) * 3
        }
        return min(max(delta, -1), 1)
    }
}
