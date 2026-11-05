import Foundation

/// Uma caixa de entrega por provedor. O lock protege outputs e dois controles
/// reservados; somente a main os consome. Pausar/retomar exige a mesma geração.
/// O ACK reavalia a próxima caixa sob o lock: não libera um lote preenchido
/// durante o consumo. Cleanup e rearm compartilham a ordem dos outputs, mesmo
/// quando um dreno main antigo já estava agendado antes da sobrecarga.
final class GestureOutputDelivery: @unchecked Sendable {
    private enum Delivery {
        case output(GestureProcessingOutput)
        case interruption
        case rearm
    }
    private let lock = NSLock()
    private var pending: [Delivery] = []
    private var scheduled = false
    private let worker: GestureProcessingWorker
    private let generation: CaptureGeneration
    private let schedule: @Sendable (@escaping @MainActor () -> Void) -> Void
    private let consume: @MainActor (GestureProcessingOutput) -> Void
    private let onInterruption: @MainActor () -> Void
    private let onRearmed: @MainActor () -> Void

    init(worker: GestureProcessingWorker, generation: CaptureGeneration,
         schedule: @escaping @Sendable (@escaping @MainActor () -> Void) -> Void = { action in
             DispatchQueue.main.async { MainActor.assumeIsolated { action() } }
         }, onInterruption: @escaping @MainActor () -> Void = {},
         onRearmed: @escaping @MainActor () -> Void = {},
         consume: @escaping @MainActor (GestureProcessingOutput) -> Void) {
        self.worker = worker
        self.generation = generation
        self.schedule = schedule
        self.consume = consume
        self.onInterruption = onInterruption
        self.onRearmed = onRearmed
    }

    func append(_ output: GestureProcessingOutput) { append(.output(output)) }
    func interrupt() { append(.interruption) }
    func rearm() { append(.rearm) }

    private func append(_ delivery: Delivery) {
        lock.lock()
        switch delivery {
        case .interruption:
            pending.removeAll { if case .rearm = $0 { return true }; return false }
            if !pending.contains(where: { if case .interruption = $0 { return true }; return false }) {
                pending.append(delivery)
            }
        case .rearm:
            if !pending.contains(where: { if case .rearm = $0 { return true }; return false }) {
                pending.append(delivery)
            }
        case .output: pending.append(delivery)
        }
        if outputCount >= 64 { worker.setDeliveryPaused(true, generation: generation) }
        let shouldSchedule = !scheduled
        scheduled = true
        lock.unlock()
        if shouldSchedule { schedule { [self] in drain() } }
    }

    private var outputCount: Int {
        pending.reduce(0) { count, item in if case .output = item { return count + 1 }; return count }
    }

    @MainActor private func drain() {
        lock.lock()
        let deliveries = pending
        pending.removeAll(keepingCapacity: true)
        scheduled = false
        lock.unlock()
        for delivery in deliveries {
            switch delivery {
            case let .output(output):
                if generation.isValid, output.processingEpoch?.isValid != false { consume(output) }
                else { worker.pipelineMetrics.discard(output.pipelineTraceID) }
            case .interruption: if generation.isValid { onInterruption() }
            case .rearm: if generation.isValid { onRearmed() }
            }
        }
        lock.lock()
        if outputCount < 64 { worker.setDeliveryPaused(false, generation: generation) }
        lock.unlock()
    }
}
