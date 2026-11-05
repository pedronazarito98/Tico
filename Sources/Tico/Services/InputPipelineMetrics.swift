import Foundation
import OSLog

/// Medição efêmera compartilhada pelas fronteiras de captura e efeito.
/// O lock protege somente números/instantes; nenhum payload de entrada entra
/// aqui. O relógio é monotônico do host, independente de Date e do bridge.
/// Paralelo com React: marcas de performance com correlação por request;
/// não é estado de UI nem persistência. Amostras e traces têm memória limitada.
final class InputPipelineMetrics: @unchecked Sendable {
    enum Stage: String, CaseIterable, Sendable {
        case ingressToDecision, decisionToDelivery, deliveryToEffect
        case effectDuration, intentionalWait, ingressToEffect
    }
    enum Milestone: Sendable { case decision, delivery, effectStart, effectEnd }
    struct Snapshot: Sendable {
        let milliseconds: [Stage: [Double]]
        let sampleCounts: [Stage: Int]
        let maximumQueueDepth: Int
        let maximumQueueAgeMilliseconds: Double
        let droppedFrames: Int
        let cancellations: Int
        let activeTraceCount: Int
    }
    private struct Trace {
        let ingress: UInt64
        var decision: UInt64?
        var delivery: UInt64?
        var effectStart: UInt64?
        var waitStart: UInt64?
    }
    private let enabled: Bool
    private let sampleLimit: Int
    private let clock: () -> UInt64
    private let lock = NSLock()
    private var traces: [UUID: Trace] = [:]
    private var samples: [Stage: [Double]] = [:]
    private var counts: [Stage: Int] = [:]
    private var maximumDepth = 0
    private var maximumAge: UInt64 = 0
    private var dropped = 0
    private var cancelled = 0
    private let signposter = OSSignposter(subsystem: "com.pedronazarito.Tico", category: "InputPipeline")

    init(isEnabled: Bool = false, sampleLimit: Int = 16_384, now: (() -> UInt64)? = nil) {
        enabled = isEnabled
        self.sampleLimit = max(1, sampleLimit)
        let origin = ContinuousClock.now
        clock = now ?? {
            let duration = origin.duration(to: .now).components
            return UInt64(max(0, duration.seconds)) * 1_000_000_000
                + UInt64(max(0, duration.attoseconds / 1_000_000_000))
        }
    }

    func now() -> UInt64 { clock() }

    func begin() -> UUID? {
        guard enabled else { return nil }
        lock.lock(); defer { lock.unlock() }
        // Instrumentação nunca impõe backpressure ao produto.
        guard traces.count < 512 else { return nil }
        let id = UUID()
        traces[id] = Trace(ingress: clock())
        signposter.emitEvent("Ingress")
        return id
    }

    func mark(_ milestone: Milestone, trace id: UUID?) {
        guard enabled, let id else { return }
        lock.lock(); defer { lock.unlock() }
        guard var trace = traces[id] else { return }
        let instant = clock()
        switch milestone {
        case .decision:
            guard trace.decision == nil else { return }
            add(.ingressToDecision, from: trace.ingress, to: instant)
            trace.decision = instant
            signposter.emitEvent("Decision")
        case .delivery:
            guard let decision = trace.decision, trace.delivery == nil else { return }
            add(.decisionToDelivery, from: decision, to: instant)
            trace.delivery = instant
            signposter.emitEvent("Delivery")
        case .effectStart:
            guard let delivery = trace.delivery, trace.effectStart == nil else { return }
            add(.deliveryToEffect, from: delivery, to: instant)
            add(.ingressToEffect, from: trace.ingress, to: instant)
            trace.effectStart = instant
            signposter.emitEvent("EffectStart")
        case .effectEnd:
            if let start = trace.effectStart { add(.effectDuration, from: start, to: instant) }
            traces[id] = nil
            signposter.emitEvent("EffectEnd")
            return
        }
        traces[id] = trace
    }

    func beginIntentionalWait(trace id: UUID?) {
        guard enabled, let id else { return }
        lock.lock(); defer { lock.unlock() }
        traces[id]?.waitStart = clock()
    }

    func endIntentionalWait(trace id: UUID?) {
        guard enabled, let id else { return }
        lock.lock(); defer { lock.unlock() }
        if let start = traces[id]?.waitStart { add(.intentionalWait, from: start, to: clock()) }
        traces[id]?.waitStart = nil
    }

    func discard(_ id: UUID?) {
        guard enabled, let id else { return }
        lock.lock(); defer { lock.unlock() }
        traces[id] = nil
    }

    func observeQueue(depth: Int, ageNanoseconds: UInt64) {
        guard enabled else { return }
        lock.lock(); defer { lock.unlock() }
        maximumDepth = max(maximumDepth, depth)
        maximumAge = max(maximumAge, ageNanoseconds)
    }

    func recordOverload(droppedFrames: Int, cancelled: Bool) {
        guard enabled else { return }
        lock.lock(); defer { lock.unlock() }
        dropped += droppedFrames
        if cancelled { self.cancelled += 1 }
    }

    func snapshot() -> Snapshot {
        lock.lock(); defer { lock.unlock() }
        return Snapshot(milliseconds: samples, sampleCounts: counts,
            maximumQueueDepth: maximumDepth,
            maximumQueueAgeMilliseconds: Double(maximumAge) / 1_000_000,
            droppedFrames: dropped, cancellations: cancelled, activeTraceCount: traces.count)
    }

    private func add(_ stage: Stage, from start: UInt64, to end: UInt64) {
        counts[stage, default: 0] += 1
        if samples[stage, default: []].count < sampleLimit {
            samples[stage, default: []].append(Double(end >= start ? end - start : 0) / 1_000_000)
        }
    }
}
