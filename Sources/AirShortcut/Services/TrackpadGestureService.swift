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

/// Coordinates provider lifecycle and publishes only semantic events or
/// coalesced laboratory snapshots to the main actor.
@MainActor
final class TrackpadGestureService: ObservableObject {
    typealias EventHandler = (InputEventDescriptor) -> Void
    typealias LaboratoryHandler = (TrackpadLaboratorySnapshot) -> Void
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
        subsystem: Bundle.main.bundleIdentifier ?? "com.pedronazarito.AirShortcut",
        category: "GlobalTrackpad"
    )
    private let providerFactory: () -> any TrackpadFrameProvider
    private let worker: GestureProcessingWorker
    private let replayWorker = GestureProcessingWorker()
    private let recorder = TrackpadSessionRecorder()
    private let validationStore: TrackpadValidationStore
    private var calibrationSet: GestureCalibrationSet
    private var frameProvider: (any TrackpadFrameProvider)?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var eventHandler: EventHandler?
    private var laboratoryHandler: LaboratoryHandler?
    private var accumulatedMagnification: CGFloat = 0
    private var accumulatedRotation: CGFloat = 0
    private var shouldResumeAfterWake = false
    private var didReceiveRawFrame = false
    private var lastLaboratoryPublishAt = Date.distantPast
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
        validationStore: TrackpadValidationStore = TrackpadValidationStore()
    ) {
        self.providerFactory = providerFactory
        self.worker = worker
        self.calibrationSet = calibrationSet
        self.validationStore = validationStore
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
        frameProvider?.stop()
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        frameProvider = nil
        localMonitor = nil
        globalMonitor = nil
        eventHandler = nil
        laboratoryHandler = nil
        worker.cancel()
        cancelReplay()
        accumulatedMagnification = 0
        accumulatedRotation = 0
        activeTouchCount = 0
        shouldResumeAfterWake = false
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
        frameProvider?.stop()
        frameProvider = nil
        worker.cancel()
        removeSystemGestureMonitors()
        installSystemGestureFallback()
        startupError = "Fallback público ativado manualmente para validação."
        captureMode = .systemGestureFallback
        isRunning = true
        logger.info("Public AppKit gesture fallback activated for validation")
    }

    func restoreAdvancedCapture() {
        removeSystemGestureMonitors()
        frameProvider?.stop()
        frameProvider = nil
        worker.cancel()
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
        let provider = providerFactory()
        let worker = self.worker
        let recorder = self.recorder
        let owner = WeakTrackpadGestureServiceBox(self)
        do {
            try provider.start { frame in
                recorder.append(frame)
                worker.process(frame) { output in
                    Task { @MainActor in
                        owner.value?.handleRawOutput(output)
                    }
                }
                Task { @MainActor in
                    owner.value?.noteRawFrame()
                }
            }
            frameProvider = provider
            startupError = nil
            return true
        } catch {
            startupError = error.localizedDescription
            provider.stop()
            return false
        }
    }

    private func installSystemGestureFallback() {
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: Self.fallbackEventMask
        ) { [weak self] event in
            MainActor.assumeIsolated { self?.processSystemGesture(event) }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: Self.fallbackEventMask
        ) { [weak self] event in
            Task { @MainActor in self?.processSystemGesture(event) }
        }
    }

    private func removeSystemGestureMonitors() {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil
        globalMonitor = nil
        accumulatedMagnification = 0
        accumulatedRotation = 0
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
        if let snapshot = output.laboratorySnapshot {
            validationStore.record(snapshot, acceptedEvent: output.event)
            activeTouchCount = snapshot.phase == .ended || snapshot.phase == .cancelled
                ? 0
                : snapshot.contacts.filter {
                    $0.transition == .down || $0.transition == .move
                }.count
            let shouldPublish = snapshot.phase == .ended
                || snapshot.phase == .cancelled
                || snapshot.features.occurredAt.timeIntervalSince(lastLaboratoryPublishAt) >= 1 / 60
            if shouldPublish, !isReplaying {
                laboratorySnapshot = snapshot
                laboratoryHandler?(snapshot)
                lastLaboratoryPublishAt = snapshot.features.occurredAt
            }
        }
        if let event = output.event {
            let composedEvent = tapCountComposer.process(event)
            latestGestureEvent = composedEvent
            emit(.trackpad(composedEvent))
            return
        }
        if let features = output.completedFeatures,
           features.maximumFingerCount >= 2,
           CustomGesturePath.normalized(
               features.centroidPath,
               pointCount: CustomGestureTemplate.defaultPointCount
           ) != nil {
            emit(.unclassifiedTrackpadPath(features))
        }
    }

    private func processSystemGesture(_ event: NSEvent) {
        let descriptor: InputEventDescriptor?
        switch event.type {
        case .swipe:
            descriptor = Self.classifySwipe(
                deltaX: event.deltaX,
                deltaY: event.deltaY,
                timestamp: Date()
            )
        case .magnify:
            if event.phase.contains(.began) { accumulatedMagnification = 0 }
            accumulatedMagnification += event.magnification
            if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
                descriptor = Self.classifyMagnification(accumulatedMagnification, timestamp: Date())
                accumulatedMagnification = 0
            } else {
                descriptor = nil
            }
        case .rotate:
            if event.phase.contains(.began) { accumulatedRotation = 0 }
            accumulatedRotation += CGFloat(event.rotation)
            if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
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
        guard frameProvider != nil else { return }
        shouldResumeAfterWake = isRunning
        frameProvider?.stop()
        frameProvider = nil
        let owner = WeakTrackpadGestureServiceBox(self)
        worker.cancel { output in
            Task { @MainActor in
                owner.value?.handleRawOutput(output)
            }
        }
        activeTouchCount = 0
        didReceiveRawFrame = false
        captureMode = .stopped
        isRunning = false
        logger.info("Raw trackpad capture suspended for system sleep")
    }

    private func resumeAfterWake() {
        guard shouldResumeAfterWake else { return }
        shouldResumeAfterWake = false
        if startAdvancedGlobalCapture() {
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
