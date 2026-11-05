import Foundation

/// A fila é dona exclusiva do motor. O lock protege apenas a caixa de entrada,
/// tokens e controles; callbacks nunca executam sob esse lock. A geração do
/// provedor sobrevive à sobrecarga: um token separado revoga a sessão atrasada,
/// inclusive outputs já calculados, até o ingresso observar zero contatos.
final class GestureProcessingWorker: @unchecked Sendable {
    private struct FrameJob {
        let frame: RawTrackpadFrame
        let generation: CaptureGeneration
        var epoch: CaptureGeneration
        let ingress: UInt64
        let trace: UUID?
        let deliverOnlyWhenNeeded: Bool
        let completion: @Sendable (GestureProcessingOutput) -> Void
    }
    private enum Work {
        case prepare(CaptureGeneration?)
        case interruption((@Sendable () -> Void)?)
        case rearm((@Sendable () -> Void)?)
        case frame(FrameJob)
    }
    private let queue: DispatchQueue
    let pipelineMetrics: InputPipelineMetrics
    private let lock = NSLock()
    private var generation: CaptureGeneration?
    private var epoch = CaptureGeneration()
    private var frames: [FrameJob] = []
    private var preparePending = false
    private var interruptionPending = false
    private var rearmPending = false
    private var waitingForZero = false
    private var latestContactCount = 0
    private var draining = false
    private var deliveryPaused = false
    private var onInterruption: (@Sendable () -> Void)?
    private var onRearmed: (@Sendable () -> Void)?
    // Abaixo, estado acessado exclusivamente pela fila serial.
    private var engine = AdvancedGestureEngine()
    private var engineGeneration: CaptureGeneration?
    private var calibrationSet = GestureCalibrationSet()
    private var emitsContinuousPhases = false
    private var includesLaboratorySnapshots = true
    private var hasProcessedCaptureFrame = false
    private var lastTouchCount = 0

    init(queue: DispatchQueue = DispatchQueue(label: "com.pedronazarito.Tico.gesture-processing", qos: .userInteractive),
         pipelineMetrics: InputPipelineMetrics = InputPipelineMetrics()) {
        self.queue = queue
        self.pipelineMetrics = pipelineMetrics
    }

    func prepareForCapture(generation: CaptureGeneration,
                           onInterruption: (@Sendable () -> Void)? = nil,
                           onRearmed: (@Sendable () -> Void)? = nil) {
        lock.lock(); defer { lock.unlock() }
        epoch.invalidate()
        discardFramesLocked()
        self.generation = generation
        epoch = CaptureGeneration()
        self.onInterruption = onInterruption
        self.onRearmed = onRearmed
        preparePending = true
        interruptionPending = false
        rearmPending = false
        waitingForZero = false
        latestContactCount = 0
        deliveryPaused = false
        scheduleLocked()
    }

    func process(_ frame: RawTrackpadFrame, generation: CaptureGeneration? = nil,
                 deliverOnlyWhenNeeded: Bool = false,
                 completion: @escaping @Sendable (GestureProcessingOutput) -> Void) {
        // Replay usa outro worker e espera cada resultado. Nunca abandona sua
        // continuation por uma política destinada à captura física em rajada.
        guard let generation else {
            queue.async { [self] in
                completion(engine.process(frame, includeLaboratorySnapshot: includesLaboratorySnapshots))
            }
            return
        }
        let ingress = pipelineMetrics.now()
        lock.lock(); defer { lock.unlock() }
        guard generation === self.generation, generation.isValid else { return }
        latestContactCount = frame.touches.filter(\.isActivelyTouching).count
        if waitingForZero {
            pipelineMetrics.recordOverload(droppedFrames: 1, cancelled: false)
            if latestContactCount == 0 { rearmLocked() }
            scheduleLocked()
            return
        }
        guard frames.count < 128 else {
            overloadLocked(additionalDrops: 1)
            scheduleLocked()
            return
        }
        frames.append(FrameJob(frame: frame, generation: generation, epoch: epoch,
            ingress: ingress, trace: pipelineMetrics.begin(),
            deliverOnlyWhenNeeded: deliverOnlyWhenNeeded, completion: completion))
        pipelineMetrics.observeQueue(depth: frames.count, ageNanoseconds: 0)
        scheduleLocked()
    }

    /// Entrega tem capacidade própria; ao atingi-la o motor cede até o dreno
    /// da main confirmar consumo. O produtor continua sujeito aos 128/100 ms.
    func setDeliveryPaused(_ paused: Bool, generation: CaptureGeneration) {
        lock.lock(); defer { lock.unlock() }
        guard generation === self.generation, generation.isValid else { return }
        deliveryPaused = paused
        if !paused { scheduleLocked() }
    }

    private func scheduleLocked() {
        guard !draining else { return }
        guard preparePending || interruptionPending || rearmPending || (!deliveryPaused && !frames.isEmpty) else { return }
        draining = true
        queue.async { [self] in drain() }
    }

    private func nextWork() -> Work? {
        lock.lock(); defer { lock.unlock() }
        if preparePending { preparePending = false; return .prepare(generation) }
        if interruptionPending { interruptionPending = false; return .interruption(onInterruption) }
        if rearmPending { rearmPending = false; return .rearm(onRearmed) }
        guard !deliveryPaused, !frames.isEmpty else { draining = false; return nil }
        let age = pipelineMetrics.now() - frames[0].ingress
        pipelineMetrics.observeQueue(depth: frames.count, ageNanoseconds: age)
        if age > 100_000_000 {
            overloadLocked(additionalDrops: 0, preservingQueuedRelease: true)
            interruptionPending = false
            return .interruption(onInterruption)
        }
        return .frame(frames.removeFirst())
    }

    private func overloadLocked(additionalDrops: Int, preservingQueuedRelease: Bool = false) {
        // Na detecção de idade, a retirada já pode estar na fila seguida de um
        // gesto novo completo. Conserva esse sufixo e sua idade; não exige uma
        // segunda retirada nem reconhece apenas a metade final do novo gesto.
        let releaseIndex = preservingQueuedRelease
            ? frames.firstIndex(where: { !$0.frame.touches.contains(where: \.isActivelyTouching) })
            : nil
        let kept = releaseIndex.map { Array(frames.dropFirst($0 + 1)) } ?? []
        let discardedCount = frames.count - kept.count
        epoch.invalidate()
        pipelineMetrics.recordOverload(droppedFrames: discardedCount + additionalDrops,
            cancelled: !interruptionPending)
        frames.prefix(discardedCount).forEach { pipelineMetrics.discard($0.trace) }
        frames = kept
        interruptionPending = true // Controle reservado, fora da capacidade de frames.
        waitingForZero = true
        if releaseIndex != nil || latestContactCount == 0 {
            rearmLocked()
            for index in frames.indices { frames[index].epoch = epoch }
        }
    }

    private func rearmLocked() {
        waitingForZero = false
        epoch = CaptureGeneration()
        rearmPending = true
    }

    private func discardFramesLocked() {
        frames.forEach { pipelineMetrics.discard($0.trace) }
        frames.removeAll(keepingCapacity: true)
    }

    private func drain() {
        while let work = nextWork() {
            switch work {
            case let .prepare(generation):
                engineGeneration = generation
                engine.reset()
                hasProcessedCaptureFrame = false
                lastTouchCount = 0
            case let .interruption(callback):
                _ = engine.cancel()
                hasProcessedCaptureFrame = false
                lastTouchCount = 0
                callback?()
            case let .rearm(callback): callback?()
            case let .frame(job):
                guard job.generation.isValid, job.epoch.isValid else { pipelineMetrics.discard(job.trace); continue }
                var output = engine.process(job.frame, includeLaboratorySnapshot: includesLaboratorySnapshots)
                guard job.generation.isValid, job.epoch.isValid else { pipelineMetrics.discard(job.trace); continue }
                pipelineMetrics.mark(.decision, trace: job.trace)
                output.pipelineTraceID = job.trace
                output.processingEpoch = job.epoch
                let firstFrame = !hasProcessedCaptureFrame
                hasProcessedCaptureFrame = true
                let countChanged = output.activeTouchCount.map { $0 != lastTouchCount } ?? false
                if let count = output.activeTouchCount { lastTouchCount = count }
                if !job.deliverOnlyWhenNeeded || firstFrame || countChanged || output.event != nil
                    || output.laboratorySnapshot != nil || output.completedFeatures != nil {
                    job.completion(output)
                } else { pipelineMetrics.discard(job.trace) }
            }
        }
    }

    func setLaboratorySnapshotsEnabled(_ isEnabled: Bool) {
        queue.async { [self] in includesLaboratorySnapshots = isEnabled }
    }

    func process(_ frame: RawTrackpadFrame) async -> GestureProcessingOutput {
        await withCheckedContinuation { continuation in
            process(frame) { continuation.resume(returning: $0) }
        }
    }

    func cancel(at date: Date = Date(), completion: (@Sendable (GestureProcessingOutput) -> Void)? = nil) {
        lock.lock()
        let cancelledGeneration = generation
        epoch.invalidate()
        discardFramesLocked()
        generation = nil
        interruptionPending = false
        rearmPending = false
        lock.unlock()
        queue.async { [self] in
            guard engineGeneration === cancelledGeneration else { return }
            let output = engine.cancel(at: date)
            completion?(output)
        }
    }

    func reset() { queue.async { [self] in engine.reset() } }

    func updateCalibration(_ calibrationSet: GestureCalibrationSet) {
        queue.async { [self] in
            self.calibrationSet = calibrationSet
            rebuildEngine()
        }
    }

    func setContinuousPhasesEnabled(_ isEnabled: Bool) {
        queue.async { [self] in
            guard emitsContinuousPhases != isEnabled else { return }
            emitsContinuousPhases = isEnabled
            rebuildEngine()
        }
    }

    private func rebuildEngine() {
        engine = AdvancedGestureEngine(configuration: GestureRecognizerConfiguration(
            calibrations: calibrationSet, emitsContinuousPhases: emitsContinuousPhases))
    }
}
