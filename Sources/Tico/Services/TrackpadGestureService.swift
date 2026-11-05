import AppKit
import Combine
import Foundation
import OSLog

enum TrackpadCaptureMode: String, Sendable {
    case stopped
    case advancedGlobal
    case systemGestureFallback

    var displayName: String {
        switch self {
        case .stopped: "Parada"
        case .advancedGlobal: "Global avançada"
        case .systemGestureFallback: "Gestos do sistema (fallback)"
        }
    }
}

/// Coordena o provedor e entrega eventos semânticos ao MainActor. Os snapshots
/// visuais são limitados e só permanecem ativos enquanto há consumidor; o
/// reconhecimento e a validação seguem independentes da tela.
@MainActor
final class TrackpadGestureService: ObservableObject {
    typealias EventHandler = (InputEventDescriptor) -> Void
    typealias LaboratoryHandler = (TrackpadLaboratorySnapshot) -> Void
    /// O coordenador ressincroniza flags antes de aceitar frames de uma captura,
    /// incluindo a retomada após sleep e mudanças de provedor.
    var onCaptureWillStart: (() -> Void)?
    /// Controle de ciclo de vida; não é um resultado do reconhecimento.
    var onCaptureInterrupted: (() -> Void)?
    static let fallbackEventMask: NSEvent.EventTypeMask = [.magnify, .rotate, .swipe]

    @Published private(set) var isRunning = false
    @Published private(set) var captureMode: TrackpadCaptureMode = .stopped
    @Published private(set) var latestEvent: InputEventDescriptor?
    @Published private(set) var latestGestureEvent: GestureEvent?
    @Published private(set) var laboratorySnapshot: TrackpadLaboratorySnapshot?
    @Published private(set) var activeTouchCount = 0
    @Published private(set) var startupError: String?
    @Published private(set) var isRecordingSession = false
    @Published private(set) var recordedFrameCount = 0
    @Published private(set) var lastRecordedDocument: TrackpadReplayDocument?
    @Published private(set) var isReplaying = false
    @Published private(set) var replayProgress = 0.0

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pedronazarito.Tico",
        category: "GlobalTrackpad"
    )
    private let providerFactory: () -> any TrackpadFrameProvider
    private let worker: GestureProcessingWorker
    private let replayWorker = GestureProcessingWorker()
    private let recorder = TrackpadSessionRecorder()
    private let validationStore: TrackpadValidationStore
    private var calibrationSet: GestureCalibrationSet
    private var frameProvider: (any TrackpadFrameProvider)?
    private let systemGestureMonitor: any SystemGestureMonitoring
    private var captureGeneration: CaptureGeneration?
    private var eventHandler: EventHandler?
    private var laboratoryHandler: LaboratoryHandler?
    private var accumulatedMagnification: CGFloat = 0
    private var accumulatedRotation: CGFloat = 0
    private var shouldResumeAfterWake = false
    private var resumeCaptureMode: TrackpadCaptureMode?
    private var didReceiveRawFrame = false
    private var lastLaboratoryPublishAt = Date.distantPast
    private var laboratorySnapshotsRequested = true
    private var deferredLaboratorySnapshot: TrackpadLaboratorySnapshot?
    private var replayTask: Task<Void, Never>?
    private var replayGeneration: UInt64 = 0
    private var cancellables = Set<AnyCancellable>()
    private var tapCountComposer = TapCountComposer()

    init(
        providerFactory: @escaping () -> any TrackpadFrameProvider = {
            MultitouchFrameProvider()
        },
        worker: GestureProcessingWorker = GestureProcessingWorker(),
        calibrationSet: GestureCalibrationSet = GestureCalibrationSet(),
        validationStore: TrackpadValidationStore = TrackpadValidationStore(),
        systemGestureMonitor: (any SystemGestureMonitoring)? = nil
    ) {
        self.providerFactory = providerFactory
        self.worker = worker
        self.calibrationSet = calibrationSet
        self.validationStore = validationStore
        self.systemGestureMonitor = systemGestureMonitor ?? SystemGestureMonitor()
        worker.updateCalibration(calibrationSet)
        replayWorker.updateCalibration(calibrationSet)
        let notifications = NSWorkspace.shared.notificationCenter
        notifications.publisher(for: NSWorkspace.willSleepNotification)
            .sink { [weak self] _ in
                Task { @MainActor in self?.suspendForSleep() }
            }
            .store(in: &cancellables)
        notifications.publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in self?.resumeAfterWake() }
            }
            .store(in: &cancellables)
    }

    func start(
        onEvent: @escaping EventHandler,
        onLaboratoryUpdate: LaboratoryHandler? = nil
    ) {
        eventHandler = onEvent
        laboratoryHandler = onLaboratoryUpdate
        updateLaboratorySnapshotDemand()
        guard !isRunning else { return }

        if startAdvancedGlobalCapture() {
            isRunning = true
            captureMode = .advancedGlobal
            logger.info("Advanced global trackpad capture started")
            return
        }

        installSystemGestureFallback()
        isRunning = true
        captureMode = .systemGestureFallback
        logger.warning(
            "Raw trackpad capture unavailable; using NSEvent gesture fallback: \(self.startupError ?? "unknown", privacy: .public)"
        )
    }

    func stop() {
        invalidateCapture()
        frameProvider?.stop()
        systemGestureMonitor.stop()
        frameProvider = nil
        eventHandler = nil
        laboratoryHandler = nil
        updateLaboratorySnapshotDemand()
        cancelReplay()
        accumulatedMagnification = 0
        accumulatedRotation = 0
        activeTouchCount = 0
        shouldResumeAfterWake = false
        resumeCaptureMode = nil
        didReceiveRawFrame = false
        tapCountComposer.reset()
        captureMode = .stopped
        isRunning = false
        logger.info("Trackpad capture stopped")
    }

    func updateCalibration(_ calibrationSet: GestureCalibrationSet) {
        self.calibrationSet = calibrationSet
        worker.updateCalibration(calibrationSet)
        replayWorker.updateCalibration(calibrationSet)
    }

    func setContinuousPhasesEnabled(_ isEnabled: Bool) {
        worker.setContinuousPhasesEnabled(isEnabled)
        replayWorker.setContinuousPhasesEnabled(isEnabled)
    }

    /// O laboratório e a gravação de gatilho são consumidores explícitos. Sem
    /// eles, guardamos apenas o último resultado útil para quando a tela voltar.
    func setLaboratorySnapshotsEnabled(_ isEnabled: Bool) {
        guard laboratorySnapshotsRequested != isEnabled else { return }
        laboratorySnapshotsRequested = isEnabled
        updateLaboratorySnapshotDemand()
    }

    private func updateLaboratorySnapshotDemand() {
        let enabled = laboratorySnapshotsRequested || laboratoryHandler != nil
        worker.setLaboratorySnapshotsEnabled(enabled)
        if enabled, !isReplaying, let snapshot = deferredLaboratorySnapshot {
            deferredLaboratorySnapshot = nil
            laboratorySnapshot = snapshot
            laboratoryHandler?(snapshot)
            lastLaboratoryPublishAt = snapshot.features.occurredAt
        }
    }

    func startSessionRecording(name: String) {
        recorder.start(name: name)
        recordedFrameCount = 0
        lastRecordedDocument = nil
        isRecordingSession = true
    }

    @discardableResult
    func stopSessionRecording() -> TrackpadReplayDocument? {
        let document = recorder.stop()
        isRecordingSession = false
        recordedFrameCount = document?.frames.count ?? 0
        lastRecordedDocument = document
        return document
    }

    func cancelSessionRecording() {
        recorder.cancel()
        isRecordingSession = false
        recordedFrameCount = 0
    }

    func replay(_ document: TrackpadReplayDocument, speed: Double = 1) {
        cancelReplay()
        guard !document.frames.isEmpty else {
            startupError = TrackpadFrameProviderError.invalidReplay.localizedDescription
            return
        }
        replayGeneration &+= 1
        let generation = replayGeneration
        isReplaying = true
        replayProgress = 0
        replayWorker.updateCalibration(calibrationSet)
        replayTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var previousDate = document.frames[0].receivedAt
            for (index, frame) in document.frames.enumerated() {
                guard !Task.isCancelled, isCurrentReplay(generation) else { return }
                if index > 0 {
                    let interval = max(
                        0,
                        frame.receivedAt.timeIntervalSince(previousDate) / max(speed, 0.05)
                    )
                    try? await Task.sleep(for: .seconds(interval))
                }
                guard !Task.isCancelled, isCurrentReplay(generation) else { return }
                let output = await replayWorker.process(frame)
                guard !Task.isCancelled, isCurrentReplay(generation) else { return }
                publishReplayOutput(output)
                replayProgress = Double(index + 1) / Double(document.frames.count)
                previousDate = frame.receivedAt
            }
            guard isCurrentReplay(generation) else { return }
            isReplaying = false
            replayTask = nil
        }
    }

    func cancelReplay() {
        replayGeneration &+= 1
        replayTask?.cancel()
        replayTask = nil
        replayWorker.reset()
        isReplaying = false
        replayProgress = 0
    }

    private func isCurrentReplay(_ generation: UInt64) -> Bool {
        replayGeneration == generation
    }

    func activateSystemFallbackForValidation() {
        invalidateCapture()
        frameProvider?.stop()
        frameProvider = nil
        removeSystemGestureMonitors()
        installSystemGestureFallback()
        startupError = "Fallback público ativado manualmente para validação."
        captureMode = .systemGestureFallback
        isRunning = true
        logger.info("Public AppKit gesture fallback activated for validation")
    }

    func restoreAdvancedCapture() {
        invalidateCapture()
        removeSystemGestureMonitors()
        frameProvider?.stop()
        frameProvider = nil
        if startAdvancedGlobalCapture() {
            startupError = nil
            captureMode = .advancedGlobal
            isRunning = true
            logger.info("Advanced global trackpad capture restored after fallback validation")
        } else {
            installSystemGestureFallback()
            captureMode = .systemGestureFallback
            isRunning = true
            logger.warning("Advanced capture restore failed; remaining on public fallback")
        }
    }

    private func startAdvancedGlobalCapture() -> Bool {
        let generation = beginCaptureGeneration()
        let provider = providerFactory()
        let worker = self.worker
        let recorder = self.recorder
        let owner = WeakTrackpadGestureServiceBox(self)
        let delivery = GestureOutputDelivery(worker: worker, generation: generation,
            onInterruption: {
                guard let service = owner.value, service.isCurrentCapture(generation) else { return }
                service.onCaptureInterrupted?()
                service.tapCountComposer.reset()
                service.activeTouchCount = 0
                service.laboratorySnapshot = nil
                service.deferredLaboratorySnapshot = nil
            }, onRearmed: {
                guard let service = owner.value, service.isCurrentCapture(generation) else { return }
                service.onCaptureWillStart?()
            }, consume: { output in
                guard let service = owner.value, service.isCurrentCapture(generation) else {
                    worker.pipelineMetrics.discard(output.pipelineTraceID)
                    return
                }
                service.handleRawOutput(output)
                service.noteRawFrame()
            })
        worker.prepareForCapture(generation: generation,
            onInterruption: { [weak delivery] in delivery?.interrupt() },
            onRearmed: { [weak delivery] in delivery?.rearm() })
        do {
            try provider.start { frame in
                guard let didRecord = generation.whileValid({ recorder.append(frame) }) else { return }
                worker.process(frame, generation: generation, deliverOnlyWhenNeeded: !didRecord) { output in
                    delivery.append(output)
                }
            }
            frameProvider = provider
            startupError = nil
            return true
        } catch {
            invalidateCapture()
            startupError = error.localizedDescription
            provider.stop()
            return false
        }
    }

    private func installSystemGestureFallback() {
        let generation = beginCaptureGeneration()
        systemGestureMonitor.start { [weak self] sample in
            guard let self, self.isCurrentCapture(generation) else { return }
            self.processSystemGesture(sample)
        }
    }

    private func removeSystemGestureMonitors() {
        systemGestureMonitor.stop()
        accumulatedMagnification = 0
        accumulatedRotation = 0
    }

    private func beginCaptureGeneration() -> CaptureGeneration {
        let generation = CaptureGeneration()
        captureGeneration = generation
        onCaptureWillStart?()
        return generation
    }

    private func isCurrentCapture(_ generation: CaptureGeneration) -> Bool {
        generation === captureGeneration && generation.isValid
    }

    /// Revoga primeiro, antes de parar o produtor. O controle cancela efeitos
    /// vigentes sem permitir que um output antigo volte ao handler de regras.
    private func invalidateCapture() {
        guard let generation = captureGeneration else { return }
        generation.invalidate()
        captureGeneration = nil
        worker.cancel()
        onCaptureInterrupted?()
        tapCountComposer.reset()
        deferredLaboratorySnapshot = nil
        laboratorySnapshot = nil
        activeTouchCount = 0
        didReceiveRawFrame = false
    }

    private func noteRawFrame() {
        if !didReceiveRawFrame {
            didReceiveRawFrame = true
            logger.info("Receiving raw global trackpad frames")
        }
        if isRecordingSession {
            let count = recorder.frameCount()
            if count != recordedFrameCount {
                recordedFrameCount = count
            }
        }
    }

    private func handleRawOutput(_ output: GestureProcessingOutput) {
        worker.pipelineMetrics.mark(.delivery, trace: output.pipelineTraceID)
        var emitted = false
        defer { if !emitted { worker.pipelineMetrics.discard(output.pipelineTraceID) } }
        if let count = output.activeTouchCount, count != activeTouchCount {
            activeTouchCount = count
        }
        if let snapshot = output.laboratorySnapshot {
            validationStore.record(snapshot, acceptedEvent: output.event)
            // Cancelamentos produzidos pelo worker não passam por process(frame).
            if output.activeTouchCount == nil, snapshot.phase == .cancelled, activeTouchCount != 0 {
                activeTouchCount = 0
            }
            let shouldPublish = snapshot.phase == .ended
                || snapshot.phase == .cancelled
                || snapshot.features.occurredAt.timeIntervalSince(lastLaboratoryPublishAt) >= 1 / 60
            if laboratorySnapshotsRequested || laboratoryHandler != nil {
                if shouldPublish, !isReplaying {
                    laboratorySnapshot = snapshot
                    laboratoryHandler?(snapshot)
                    lastLaboratoryPublishAt = snapshot.features.occurredAt
                }
            } else {
                deferredLaboratorySnapshot = snapshot
            }
        }
        if let event = output.event {
            let composedEvent = tapCountComposer.process(event)
            latestGestureEvent = composedEvent
            emitted = true
            emit(InputEventDescriptor.trackpad(composedEvent).withPipelineTrace(output.pipelineTraceID))
            return
        }
        if let features = output.completedFeatures,
           features.maximumFingerCount >= 2,
           CustomGesturePath.normalized(
               features.centroidPath,
               pointCount: CustomGestureTemplate.defaultPointCount
           ) != nil {
            emitted = true
            emit(InputEventDescriptor.unclassifiedTrackpadPath(features).withPipelineTrace(output.pipelineTraceID))
        }
    }

    private func processSystemGesture(_ event: SystemGestureSample) {
        let descriptor: InputEventDescriptor?
        switch event.type {
        case .swipe:
            descriptor = Self.classifySwipe(
                deltaX: event.deltaX,
                deltaY: event.deltaY,
                timestamp: Date()
            )
        case .magnify:
            // Cancelamento é terminal sem reconhecimento, mesmo acima do limiar.
            if event.phase.contains(.cancelled) {
                accumulatedMagnification = 0
                return
            }
            if event.phase.contains(.began) { accumulatedMagnification = 0 }
            accumulatedMagnification += event.magnification
            if event.phase.contains(.ended) {
                descriptor = Self.classifyMagnification(accumulatedMagnification, timestamp: Date())
                accumulatedMagnification = 0
            } else {
                descriptor = nil
            }
        case .rotate:
            if event.phase.contains(.cancelled) {
                accumulatedRotation = 0
                return
            }
            if event.phase.contains(.began) { accumulatedRotation = 0 }
            accumulatedRotation += CGFloat(event.rotation)
            if event.phase.contains(.ended) {
                descriptor = Self.classifyRotation(accumulatedRotation, timestamp: Date())
                accumulatedRotation = 0
            } else {
                descriptor = nil
            }
        default:
            descriptor = nil
        }
        if let descriptor, let gesture = descriptor.gesture {
            let semanticEvent = GestureEvent(
                sessionID: UUID(),
                kind: gesture,
                phase: .ended,
                fingerCount: descriptor.fingerCount ?? gesture.defaultFingerCount,
                startRegion: .any,
                endRegion: .any,
                confidence: 0.7,
                occurredAt: descriptor.timestamp
            )
            latestGestureEvent = semanticEvent
            validationStore.recordPublicFallbackGesture(gesture)
            emit(.trackpad(semanticEvent))
        }
    }

    private func emit(_ descriptor: InputEventDescriptor) {
        latestEvent = descriptor
        eventHandler?(descriptor)
        logger.info("Recognized global trackpad gesture: \(descriptor.displayName, privacy: .public)")
    }

    private func suspendForSleep() {
        guard isRunning else { return }
        shouldResumeAfterWake = true
        resumeCaptureMode = captureMode
        invalidateCapture()
        frameProvider?.stop()
        frameProvider = nil
        removeSystemGestureMonitors()
        captureMode = .stopped
        isRunning = false
        logger.info("Trackpad capture suspended for system sleep")
    }

    private func resumeAfterWake() {
        guard shouldResumeAfterWake else { return }
        shouldResumeAfterWake = false
        let mode = resumeCaptureMode
        resumeCaptureMode = nil
        if mode == .systemGestureFallback {
            installSystemGestureFallback()
            captureMode = .systemGestureFallback
            isRunning = true
        } else if startAdvancedGlobalCapture() {
            captureMode = .advancedGlobal
            isRunning = true
            validationStore.setCheck(.sleepWake, completed: true)
            logger.info("Raw trackpad capture resumed after system wake")
        } else {
            installSystemGestureFallback()
            captureMode = .systemGestureFallback
            isRunning = true
            logger.error("Raw trackpad capture could not resume; public fallback installed")
        }
    }

    private func publishReplayOutput(_ output: GestureProcessingOutput) {
        if let snapshot = output.laboratorySnapshot {
            laboratorySnapshot = snapshot
            laboratoryHandler?(snapshot)
        }
        if let event = output.event {
            latestGestureEvent = event
        }
    }

    nonisolated static func classifySwipe(
        deltaX: CGFloat,
        deltaY: CGFloat,
        timestamp: Date = Date()
    ) -> InputEventDescriptor? {
        let minimumDistance: CGFloat = 0.01
        guard max(abs(deltaX), abs(deltaY)) >= minimumDistance else { return nil }
        if abs(deltaX) > abs(deltaY) {
            return .trackpad(deltaX > 0 ? .swipeRight : .swipeLeft, timestamp: timestamp)
        }
        return .trackpad(deltaY > 0 ? .swipeUp : .swipeDown, timestamp: timestamp)
    }

    nonisolated static func classifyMagnification(
        _ magnification: CGFloat,
        timestamp: Date = Date()
    ) -> InputEventDescriptor? {
        guard abs(magnification) >= 0.03 else { return nil }
        return .trackpad(magnification > 0 ? .pinchOut : .pinchIn, timestamp: timestamp)
    }

    nonisolated static func classifyRotation(
        _ rotation: CGFloat,
        timestamp: Date = Date()
    ) -> InputEventDescriptor? {
        guard abs(rotation) >= 2 else { return nil }
        return .trackpad(
            rotation > 0 ? .rotateCounterclockwise : .rotateClockwise,
            timestamp: timestamp
        )
    }
}

/// The box stores only a weak reference and is captured to bridge a provider
/// callback back into the main-actor service. The weak storage may be cleared
/// by object lifetime; the callback does not mutate the service directly and
/// schedules work on `MainActor` first.
private final class WeakTrackpadGestureServiceBox: @unchecked Sendable {
    // The weak reference changes only as the actor-owned service is deallocated;
    // the callback reads it before scheduling work on MainActor.
    weak var value: TrackpadGestureService?

    init(_ value: TrackpadGestureService) {
        self.value = value
    }
}
