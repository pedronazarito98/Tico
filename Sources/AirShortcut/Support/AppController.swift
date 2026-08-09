import AppKit
import Combine
import Foundation
import OSLog

struct PendingScriptApproval: Identifiable {
    let id = UUID()
    let ruleName: String
    let command: String
}

@MainActor
final class AppController: ObservableObject {
    @Published private(set) var lastEvent: InputEventDescriptor?
    @Published private(set) var recordedEvent: InputEventDescriptor?
    @Published private(set) var captureIsRunning = false
    @Published private(set) var recordingIsActive = false
    @Published private(set) var trackpadCaptureMode: TrackpadCaptureMode = .stopped
    @Published private(set) var trackpadStartupError: String?
    @Published private(set) var laboratorySnapshot: TrackpadLaboratorySnapshot?
    @Published private(set) var laboratoryIsRecording = false
    @Published private(set) var laboratoryRecordedFrameCount = 0
    @Published private(set) var laboratoryLastRecording: TrackpadReplayDocument?
    @Published private(set) var laboratoryIsReplaying = false
    @Published private(set) var laboratoryReplayProgress = 0.0
    @Published private(set) var detectedTrackpads: [TrackpadHardwareInfo] = []
    @Published private(set) var availableApplications: [ApplicationChoice] = []
    @Published private(set) var availableMacOSShortcuts: [String] = []
    @Published private(set) var currentContextSnapshot: ContextSnapshot?
    @Published var presentedError: String?
    @Published private(set) var pendingScriptApproval: PendingScriptApproval?

    let shortcutStore: ShortcutStore
    let settings: AppSettingsStore
    let eventLogStore: EventLogStore
    let permissions: PermissionCoordinator
    let calibrationStore: TrackpadCalibrationStore
    let validationStore: TrackpadValidationStore
    let metricsStore: MetricsStore
    let capabilityStore: TrackpadCapabilityStore

    private let globalEventTap: GlobalEventTapService
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pedronazarito.AirShortcut",
        category: "GlobalCapture"
    )
    private let trackpadGestures: TrackpadGestureService
    private let matcher: TriggerMatcher
    private let workflowExecutor: WorkflowExecutor
    private let continuousWindowController: any ContinuousWindowActionControlling
    private let approvalStore: AutomationApprovalStore
    private let hardwareDetector: TrackpadHardwareDetector
    private let contextSnapshotService: any ContextSnapshotProviding
    private let applicationCatalogService: ApplicationCatalogService
    private let macOSShortcutCatalog: any MacOSShortcutRunning
    private var sequenceRuntime = TriggerSequenceRuntime()
    private var activeModifiers: Set<InputModifier> = []
    private var sequenceDeadlineTask: Task<Void, Never>?
    private var workflowTasks: [UUID: Task<Void, Never>] = [:]
    private var activeContinuousSessions: Set<UUID> = []
    private var cancellables = Set<AnyCancellable>()
    private var approvalContinuation: CheckedContinuation<Bool, Never>?
    private var captureWasRunningBeforeRecording = false
    private var trackpadWasRunningBeforeRecording = false

    init(
        shortcutStore: ShortcutStore,
        settings: AppSettingsStore,
        eventLogStore: EventLogStore,
        permissions: PermissionCoordinator,
        calibrationStore: TrackpadCalibrationStore = TrackpadCalibrationStore(),
        validationStore: TrackpadValidationStore = TrackpadValidationStore(),
        metricsStore: MetricsStore = MetricsStore(),
        capabilityStore: TrackpadCapabilityStore = TrackpadCapabilityStore(),
        globalEventTap: GlobalEventTapService = GlobalEventTapService(),
        trackpadGestures: TrackpadGestureService? = nil,
        matcher: TriggerMatcher = TriggerMatcher(),
        actionRunner: ActionRunner = ActionRunner(),
        continuousWindowController: (any ContinuousWindowActionControlling)? = nil,
        approvalStore: AutomationApprovalStore? = nil,
        hardwareDetector: TrackpadHardwareDetector = TrackpadHardwareDetector(),
        contextSnapshotService: (any ContextSnapshotProviding)? = nil,
        applicationCatalogService: ApplicationCatalogService? = nil,
        macOSShortcutCatalog: any MacOSShortcutRunning = MacOSShortcutRunner()
    ) {
        self.shortcutStore = shortcutStore
        self.settings = settings
        self.eventLogStore = eventLogStore
        self.permissions = permissions
        self.calibrationStore = calibrationStore
        self.validationStore = validationStore
        self.metricsStore = metricsStore
        self.capabilityStore = capabilityStore
        self.globalEventTap = globalEventTap
        self.trackpadGestures = trackpadGestures ?? TrackpadGestureService(
            calibrationSet: calibrationStore.calibrationSet,
            validationStore: validationStore
        )
        self.matcher = matcher
        self.workflowExecutor = WorkflowExecutor(actionRunner: actionRunner)
        self.continuousWindowController = continuousWindowController
            ?? ContinuousWindowActionService()
        self.approvalStore = approvalStore ?? AutomationApprovalStore()
        self.hardwareDetector = hardwareDetector
        self.contextSnapshotService = contextSnapshotService ?? ContextSnapshotService()
        self.applicationCatalogService = applicationCatalogService ?? ApplicationCatalogService()
        self.macOSShortcutCatalog = macOSShortcutCatalog

        self.trackpadGestures.$captureMode
            .removeDuplicates()
            .sink { [weak self] mode in
                self?.trackpadCaptureMode = mode
            }
            .store(in: &cancellables)
        refreshApplicationCatalog()
        refreshMacOSShortcutCatalog()
        self.trackpadGestures.$startupError
            .removeDuplicates()
            .sink { [weak self] error in
                self?.trackpadStartupError = error
            }
            .store(in: &cancellables)
        self.trackpadGestures.$laboratorySnapshot
            .compactMap { $0 }
            .sink { [weak self] snapshot in
                self?.laboratorySnapshot = snapshot
            }
            .store(in: &cancellables)
        self.trackpadGestures.$isRecordingSession
            .removeDuplicates()
            .sink { [weak self] isRecording in
                self?.laboratoryIsRecording = isRecording
            }
            .store(in: &cancellables)
        self.trackpadGestures.$recordedFrameCount
            .removeDuplicates()
            .sink { [weak self] count in
                self?.laboratoryRecordedFrameCount = count
            }
            .store(in: &cancellables)
        self.trackpadGestures.$lastRecordedDocument
            .compactMap { $0 }
            .sink { [weak self] document in
                self?.laboratoryLastRecording = document
            }
            .store(in: &cancellables)
        self.trackpadGestures.$isReplaying
            .removeDuplicates()
            .sink { [weak self] isReplaying in
                self?.laboratoryIsReplaying = isReplaying
            }
            .store(in: &cancellables)
        self.trackpadGestures.$replayProgress
            .removeDuplicates()
            .sink { [weak self] progress in
                self?.laboratoryReplayProgress = progress
            }
            .store(in: &cancellables)
        calibrationStore.$calibrationSet
            .sink { [weak self] calibrationSet in
                self?.trackpadGestures.updateCalibration(calibrationSet)
            }
            .store(in: &cancellables)
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
            .sink { [weak self] enabled in
                self?.trackpadGestures.setContinuousPhasesEnabled(enabled)
            }
            .store(in: &cancellables)
        let workspaceNotifications = NSWorkspace.shared.notificationCenter
        workspaceNotifications.publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .merge(with: workspaceNotifications.publisher(
                for: NSWorkspace.didTerminateApplicationNotification
            ))
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.refreshApplicationCatalog()
                }
            }
            .store(in: &cancellables)
    }

    @discardableResult
    func startTrackpadObservation() -> Bool {
        permissions.refresh()
        if !permissions.status.canCaptureGlobalInput {
            if permissions.status.inputMonitoring == .notDetermined {
                permissions.requestInputMonitoring()
                permissions.refresh()
            }
        }
        guard permissions.status.canCaptureGlobalInput else {
            trackpadGestures.stop()
            trackpadCaptureMode = .stopped
            presentedError = permissions.status.inputMonitoring == .denied
                ? "O Monitoramento de Entrada foi negado. Abra os Ajustes do Sistema, habilite o \(TicoBrand.displayName) e reabra o app."
                : "Conceda Monitoramento de Entrada e reabra o \(TicoBrand.displayName) para observar contatos globais."
            return false
        }
        refreshTrackpadHardware()
        guard !trackpadGestures.isRunning else { return true }
        trackpadGestures.start { [weak self] event in
            self?.receive(event)
        }
        trackpadCaptureMode = trackpadGestures.captureMode
        trackpadStartupError = trackpadGestures.startupError
        return trackpadGestures.isRunning
    }

    func refreshTrackpadHardware() {
        detectedTrackpads = hardwareDetector.detect()
    }

    func refreshApplicationCatalog() {
        availableApplications = applicationCatalogService.applications()
    }

    func refreshMacOSShortcutCatalog() {
        Task { [weak self] in
            guard let self else { return }
            do {
                availableMacOSShortcuts = try await macOSShortcutCatalog.list()
            } catch {
                availableMacOSShortcuts = []
            }
        }
    }

    func stopTrackpadObservationIfIdle() {
        guard !captureIsRunning,
              !recordingIsActive,
              !laboratoryIsRecording,
              !laboratoryIsReplaying else { return }
        trackpadGestures.stop()
        trackpadCaptureMode = .stopped
        sequenceRuntime.reset()
        sequenceDeadlineTask?.cancel()
        sequenceDeadlineTask = nil
        cancelAllWorkflows()
    }

    func startLaboratoryRecording(name: String) {
        guard startTrackpadObservation() else { return }
        trackpadGestures.startSessionRecording(name: name)
    }

    @discardableResult
    func stopLaboratoryRecording() -> TrackpadReplayDocument? {
        trackpadGestures.stopSessionRecording()
    }

    func cancelLaboratoryRecording() {
        trackpadGestures.cancelSessionRecording()
    }

    func replayLaboratoryDocument(_ document: TrackpadReplayDocument, speed: Double = 1) {
        trackpadGestures.replay(document, speed: speed)
    }

    func cancelLaboratoryReplay() {
        trackpadGestures.cancelReplay()
    }

    func activatePublicFallbackForValidation() {
        guard startTrackpadObservation() else { return }
        trackpadGestures.activateSystemFallbackForValidation()
    }

    func restoreAdvancedTrackpadCapture() {
        trackpadGestures.restoreAdvancedCapture()
    }

    func startCapture() {
        guard !globalEventTap.isRunning else {
            if !captureIsRunning {
                captureIsRunning = true
            }
            return
        }

        permissions.refresh()
        if !permissions.status.canCaptureGlobalInput {
            if permissions.status.inputMonitoring == .notDetermined {
                permissions.requestInputMonitoring()
            }
            if !permissions.status.canCaptureGlobalInput {
                presentedError = permissions.status.inputMonitoring == .denied
                    ? "O Monitoramento de Entrada foi negado. Abra os Ajustes do Sistema, habilite o \(TicoBrand.displayName) e reabra o app."
                    : "Conceda Monitoramento de Entrada e reabra o \(TicoBrand.displayName) para iniciar a captura global."
                captureIsRunning = false
                logger.error(
                    "Capture start blocked by TCC: inputMonitoring=\(self.permissions.status.inputMonitoring.rawValue, privacy: .public), accessibility=\(self.permissions.status.accessibilityGranted, privacy: .public)"
                )
                if permissions.status.inputMonitoring == .denied {
                    permissions.openInputMonitoringSettings()
                }
                return
            }
        }
        guard startTrackpadObservation() else {
            captureIsRunning = false
            return
        }

        do {
            try globalEventTap.start(
                onEvent: { [weak self] event in
                    Task { @MainActor in
                        self?.receive(event)
                    }
                },
                onStateChange: { [weak self] isRunning in
                    Task { @MainActor in
                        guard let self, self.captureIsRunning != isRunning else { return }
                        self.captureIsRunning = isRunning
                    }
                }
            )
            if !captureIsRunning {
                captureIsRunning = true
            }
            if presentedError != nil {
                presentedError = nil
            }
            logger.info("Global capture started")
        } catch {
            trackpadGestures.stop()
            trackpadCaptureMode = .stopped
            captureIsRunning = false
            presentedError = permissions.status.canCaptureGlobalInput
                ? "O macOS reconhece a permissão, mas não criou o monitor global. Encerre e reabra o \(TicoBrand.displayName). Detalhe: \(error.localizedDescription)"
                : error.localizedDescription
            logger.error("Global capture failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func stopCapture() {
        globalEventTap.stop()
        trackpadGestures.stop()
        trackpadCaptureMode = .stopped
        sequenceRuntime.reset()
        sequenceDeadlineTask?.cancel()
        sequenceDeadlineTask = nil
        cancelAllWorkflows()
        for sessionID in activeContinuousSessions {
            try? continuousWindowController.cancel(sessionID: sessionID)
        }
        activeContinuousSessions.removeAll()
        if captureIsRunning {
            captureIsRunning = false
        }
    }

    func toggleCapture() {
        captureIsRunning ? stopCapture() : startCapture()
    }

    func beginRecording() {
        recordedEvent = nil
        recordingIsActive = true
        captureWasRunningBeforeRecording = captureIsRunning
        trackpadWasRunningBeforeRecording = trackpadGestures.isRunning
        guard startTrackpadObservation() else {
            recordingIsActive = false
            return
        }
        if permissions.status.canCaptureGlobalInput {
            startCapture()
        }
    }

    func endRecording() {
        guard recordingIsActive else { return }
        recordingIsActive = false
        if !captureWasRunningBeforeRecording {
            globalEventTap.stop()
            captureIsRunning = false
        }
        if !trackpadWasRunningBeforeRecording {
            trackpadGestures.stop()
            trackpadCaptureMode = .stopped
        }
        captureWasRunningBeforeRecording = false
        trackpadWasRunningBeforeRecording = false
    }

    func clearLog() {
        do {
            try eventLogStore.clear()
        } catch {
            presentedError = error.localizedDescription
        }
    }

    func resolveScriptApproval(approved: Bool) {
        guard pendingScriptApproval != nil || approvalContinuation != nil else { return }
        if approved, let command = pendingScriptApproval?.command {
            approvalStore.approve(command)
        }
        pendingScriptApproval = nil
        let continuation = approvalContinuation
        approvalContinuation = nil
        continuation?.resume(returning: approved)
    }

    private func receive(_ incomingEvent: InputEventDescriptor) {
        if incomingEvent.kind == .keyboard {
            activeModifiers = incomingEvent.modifiers
        }
        let event = incomingEvent.kind == .trackpadGesture
            ? incomingEvent.withModifiers(activeModifiers)
            : incomingEvent
        if let gestureEvent = event.gestureEvent {
            capabilityStore.observe(
                deviceID: gestureEvent.deviceID,
                pressure: gestureEvent.pressure,
                at: gestureEvent.occurredAt
            )
        }
        if recordingIsActive {
            recordedEvent = event
        }
        guard captureIsRunning || recordingIsActive else { return }
        lastEvent = event
        guard captureIsRunning else { return }
        let context = contextSnapshotService.snapshot(
            modifiers: activeModifiers,
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

    private func execute(
        _ rules: [ShortcutRule],
        event: InputEventDescriptor? = nil
    ) {
        guard !rules.isEmpty else { return }
        for rule in rules {
            workflowTasks[rule.id]?.cancel()
            workflowTasks[rule.id] = Task { [weak self] in
                guard let self else { return }
                let report = await workflowExecutor.execute(
                    rule.workflow,
                    approval: { [weak self] content in
                        guard let self else { return false }
                        return await self.requestScriptApproval(
                            ruleName: rule.name,
                            command: content
                        )
                    }
                )
                guard !Task.isCancelled || report.wasCancelled else { return }
                let result = report.summary
                do {
                    try eventLogStore.record(
                        rule: rule,
                        result: result,
                        stepExecutions: report.stepExecutions
                    )
                } catch {
                    presentedError = error.localizedDescription
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
        }
    }

    func cancelWorkflow(ruleID: UUID) {
        workflowTasks[ruleID]?.cancel()
        workflowTasks[ruleID] = nil
    }

    private func cancelAllWorkflows() {
        workflowTasks.values.forEach { $0.cancel() }
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
                        curve: continuousAction(
                            for: event,
                            context: context
                        )?.curve ?? .linear
                    )
                case .ended:
                    continuousWindowController.commit(sessionID: gestureEvent.sessionID)
                    activeContinuousSessions.remove(gestureEvent.sessionID)
                case .cancelled:
                    try continuousWindowController.cancel(sessionID: gestureEvent.sessionID)
                    activeContinuousSessions.remove(gestureEvent.sessionID)
                }
            } catch {
                presentedError = error.localizedDescription
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
            presentedError = error.localizedDescription
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
        sequenceDeadlineTask = Task { [weak self] in
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

    private func requestScriptApproval(ruleName: String, command: String) async -> Bool {
        if approvalStore.isApproved(command) {
            return true
        }
        if let approvalContinuation {
            approvalContinuation.resume(returning: false)
            self.approvalContinuation = nil
        }
        return await withCheckedContinuation { continuation in
            approvalContinuation = continuation
            pendingScriptApproval = PendingScriptApproval(ruleName: ruleName, command: command)
        }
    }
}
