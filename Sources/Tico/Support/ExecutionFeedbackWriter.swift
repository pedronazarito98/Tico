import Foundation

/// Owner do feedback persistente depois da conclusão do efeito. Mantém um dreno
/// serial de histórico; a task do workflow não aguarda disco nem pertence a ele.
/// Falhas de record ficam no repositório para flush/retry, sem reexecutar ações.
@MainActor
final class ExecutionFeedbackWriter {
    private let history: EventLogStore
    private let metrics: MetricsStore
    private let onError: (Error) -> Void
    private var entries: [ExecutionLogEntry] = []
    private var drainTask: Task<Void, Never>?

    init(history: EventLogStore, metrics: MetricsStore, onError: @escaping (Error) -> Void) {
        self.history = history; self.metrics = metrics; self.onError = onError
    }

    func enqueue(rule: ShortcutRule, report: WorkflowExecutionReport, event: InputEventDescriptor? = nil) {
        entries.append(ExecutionLogEntry(ruleID: rule.id, ruleName: rule.name, action: rule.action,
            result: report.summary, stepExecutions: report.stepExecutions))
        metrics.record(GestureMetricEvent(occurredAt: report.finishedAt, ruleID: rule.id, ruleName: rule.name,
            gesture: event?.gesture, deviceID: event?.gestureEvent?.deviceID,
            outcome: report.wasCancelled ? .cancelled : (report.success ? .success : .failure),
            confidence: event?.gestureEvent?.confidence, latency: report.finishedAt.timeIntervalSince(report.startedAt)))
        guard drainTask == nil else { return }
        drainTask = Task { [self] in
            defer { drainTask = nil }
            while !entries.isEmpty {
                let entry = entries.removeFirst()
                do { try await history.record(entry) }
                catch { onError(error) }
            }
        }
    }

    func drain() async {
        while let drainTask { await drainTask.value }
    }

    func flush() async throws {
        await drain()
        try Task.checkCancellation()
        try await history.flush()
        try Task.checkCancellation()
        try await metrics.flush()
    }
}
