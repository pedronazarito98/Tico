import AppKit
import Combine
import Foundation

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

    let practiceSession = GesturePracticeSession()
    let localInputCapture = LocalInputCaptureService()
    let companion: CompanionCoordinator
    let experiences: ContextualExperienceCoordinator
    let contentInteraction: ContentInteractionCoordinator
    let localIntelligence: any LocalIntelligenceServicing
    @Published private(set) var captureResumesAt: Date?
    private var captureResumeTask: Task<Void, Never>?

    let shortcutStore: ShortcutStore
    let settings: AppSettingsStore
    let eventLogStore: EventLogStore
    let permissions: PermissionCoordinator
    let calibrationStore: TrackpadCalibrationStore
    let validationStore: TrackpadValidationStore
    let metricsStore: MetricsStore
    let capabilityStore: TrackpadCapabilityStore

    private let captureCoordinator: CaptureCoordinator
    private let laboratoryCoordinator: LaboratoryCoordinator
    private let scriptApprovalPresenter = ScriptApprovalPresenter()
    private let automationCoordinator: AutomationCoordinator
    private let applicationCatalogService: ApplicationCatalogService
    private let macOSShortcutCatalog: any MacOSShortcutRunning
    private var activeModifiers: Set<InputModifier> = []
    private var cancellables = Set<AnyCancellable>()
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
        macOSShortcutCatalog: any MacOSShortcutRunning = MacOSShortcutRunner(),
        localIntelligence: any LocalIntelligenceServicing = LocalIntelligenceService(),
        allowsAutomationExecution: Bool = true
    ) {
        self.localIntelligence = localIntelligence
        self.shortcutStore = shortcutStore
        self.settings = settings
        self.eventLogStore = eventLogStore
        self.permissions = permissions
        self.calibrationStore = calibrationStore
        self.validationStore = validationStore
        self.metricsStore = metricsStore
        self.capabilityStore = capabilityStore
        let resolvedTrackpadGestures = trackpadGestures ?? TrackpadGestureService(
            calibrationSet: calibrationStore.calibrationSet,
            validationStore: validationStore
        )
        let resolvedCaptureCoordinator = CaptureCoordinator(
            globalEventTap: globalEventTap,
            trackpadGestures: resolvedTrackpadGestures,
            permissions: permissions,
            hardwareDetector: hardwareDetector
        )
        self.captureCoordinator = resolvedCaptureCoordinator
        self.laboratoryCoordinator = LaboratoryCoordinator(
            captureCoordinator: resolvedCaptureCoordinator,
            calibrationStore: calibrationStore
        )
        let sceneLayouts = SceneLayoutSession(allowsExecution: allowsAutomationExecution)
        self.automationCoordinator = AutomationCoordinator(
            shortcutStore: shortcutStore,
            eventLogStore: eventLogStore,
            metricsStore: metricsStore,
            matcher: matcher,
            actionRunner: actionRunner,
            continuousWindowController: continuousWindowController,
            approvalStore: approvalStore,
            contextSnapshotService: contextSnapshotService,
            sceneLayouts: sceneLayouts,
            allowsExecution: allowsAutomationExecution,
            setContinuousPhasesEnabled: { [weak resolvedCaptureCoordinator] isEnabled in
                resolvedCaptureCoordinator?.setContinuousPhasesEnabled(isEnabled)
            }
        )
        self.companion = CompanionCoordinator(
            store: shortcutStore, automation: automationCoordinator,
            contextProvider: contextSnapshotService ?? ContextSnapshotService(),
            allowsExecution: allowsAutomationExecution
        )
        self.experiences = ContextualExperienceCoordinator(
            store: shortcutStore, automation: automationCoordinator,
            sceneLayouts: sceneLayouts, allowsExecution: allowsAutomationExecution)
        self.contentInteraction = ContentInteractionCoordinator(
            store: shortcutStore, automation: automationCoordinator,
            contextProvider: contextSnapshotService ?? ContextSnapshotService(),
            allowsExecution: allowsAutomationExecution, intelligence: localIntelligence)
        companion.onRequestContent = { [weak contentInteraction] in contentInteraction?.show() }
        companion.onRequestSelection = { [weak contentInteraction] in contentInteraction?.show(useSelection: true) }
        self.applicationCatalogService = applicationCatalogService ?? ApplicationCatalogService()
        self.macOSShortcutCatalog = macOSShortcutCatalog

        captureCoordinator.setEventHandler { [weak self] event in
            self?.receive(event)
        }
        captureCoordinator.$isRunning
            .removeDuplicates()
            .sink { [weak self] isRunning in
                self?.captureIsRunning = isRunning
            }
            .store(in: &cancellables)
        captureCoordinator.$trackpadCaptureMode
            .removeDuplicates()
            .sink { [weak self] mode in
                self?.trackpadCaptureMode = mode
            }
            .store(in: &cancellables)
        captureCoordinator.$trackpadStartupError
            .removeDuplicates()
            .sink { [weak self] error in
                self?.trackpadStartupError = error
            }
            .store(in: &cancellables)
        captureCoordinator.$detectedTrackpads
            .removeDuplicates()
            .sink { [weak self] devices in
                self?.detectedTrackpads = devices
            }
            .store(in: &cancellables)
        laboratoryCoordinator.$snapshot
            .compactMap { $0 }
            .sink { [weak self] snapshot in
                self?.laboratorySnapshot = snapshot
            }
            .store(in: &cancellables)
        laboratoryCoordinator.$isRecording
            .removeDuplicates()
            .sink { [weak self] isRecording in
                self?.laboratoryIsRecording = isRecording
            }
            .store(in: &cancellables)
        laboratoryCoordinator.$recordedFrameCount
            .removeDuplicates()
            .sink { [weak self] count in
                self?.laboratoryRecordedFrameCount = count
            }
            .store(in: &cancellables)
        laboratoryCoordinator.$lastRecording
            .compactMap { $0 }
            .sink { [weak self] document in
                self?.laboratoryLastRecording = document
            }
            .store(in: &cancellables)
        laboratoryCoordinator.$isReplaying
            .removeDuplicates()
            .sink { [weak self] isReplaying in
                self?.laboratoryIsReplaying = isReplaying
            }
            .store(in: &cancellables)
        laboratoryCoordinator.$replayProgress
            .removeDuplicates()
            .sink { [weak self] progress in
                self?.laboratoryReplayProgress = progress
            }
            .store(in: &cancellables)
        automationCoordinator.$currentContextSnapshot
            .sink { [weak self] snapshot in
                self?.currentContextSnapshot = snapshot
            }
            .store(in: &cancellables)
        automationCoordinator.$pendingScriptApproval
            .sink { [weak self] approval in
                guard let self else { return }
                pendingScriptApproval = approval
                scriptApprovalPresenter.update(approval) { [weak self] accepted in
                    self?.automationCoordinator.resolveScriptApproval(approved: accepted)
                }
            }
            .store(in: &cancellables)
        // Uma atividade não pode liberar a execução enquanto outra ainda usa a captura.
        Publishers.CombineLatest3($recordingIsActive, laboratoryCoordinator.$isRecording, laboratoryCoordinator.$isReplaying)
            .map { $0 || $1 || $2 }
            .removeDuplicates()
            .sink { [weak companion, weak experiences, weak contentInteraction] suspended in
                companion?.interactionIsSuspended = suspended
                experiences?.setSuspended(suspended)
                contentInteraction?.interactionIsSuspended = suspended
            }
            .store(in: &cancellables)
        experiences.$message.compactMap { $0 }.sink { [weak self] in self?.presentedError = $0 }
            .store(in: &cancellables)
        automationCoordinator.setErrorHandler { [weak self] message in
            self?.presentedError = message
        }
        refreshApplicationCatalog()
        refreshMacOSShortcutCatalog()
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
        guard captureCoordinator.startTrackpadObservation() else {
            presentTrackpadObservationError()
            return false
        }
        return true
    }

    func refreshTrackpadHardware() {
        captureCoordinator.refreshTrackpadHardware()
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
            contentInteraction.updateMacOSShortcuts(availableMacOSShortcuts)
        }
    }

    func stopTrackpadObservationIfIdle() {
        guard !captureCoordinator.isRunning,
              !recordingIsActive,
              !laboratoryCoordinator.isRecording,
              !laboratoryCoordinator.isReplaying else { return }
        laboratoryCoordinator.stopObservation()
        automationCoordinator.stop()
    }

    func startLaboratoryRecording(name: String) {
        guard !recordingIsActive, !laboratoryCoordinator.isReplaying else {
            presentedError = "Encerre a prática, gravação de gatilho ou replay antes de gravar uma sessão."
            return
        }
        automationCoordinator.stop()
        guard laboratoryCoordinator.startRecording(name: name) else {
            presentTrackpadObservationError()
            return
        }
    }

    @discardableResult
    func stopLaboratoryRecording() -> TrackpadReplayDocument? {
        return laboratoryCoordinator.stopRecording()
    }

    func cancelLaboratoryRecording() {
        laboratoryCoordinator.cancelRecording()
    }

    func replayLaboratoryDocument(_ document: TrackpadReplayDocument, speed: Double = 1) {
        guard !recordingIsActive, !laboratoryCoordinator.isRecording else {
            presentedError = "Encerre a prática ou gravação antes de iniciar o replay."
            return
        }
        automationCoordinator.stop()
        laboratoryCoordinator.replay(document, speed: speed)
    }

    func cancelLaboratoryReplay() {
        laboratoryCoordinator.cancelReplay()
    }

    func activatePublicFallbackForValidation() {
        guard laboratoryCoordinator.activatePublicFallbackForValidation() else {
            presentTrackpadObservationError()
            return
        }
    }

    func restoreAdvancedTrackpadCapture() {
        laboratoryCoordinator.restoreAdvancedCapture()
    }

    func startCapture() {
        captureResumeTask?.cancel()
        captureResumesAt = nil
        switch captureCoordinator.startCapture() {
        case .started:
            presentedError = nil
            experiences.setPausedByUser(false)
        case let .blocked(message), let .failed(message):
            presentedError = message
        }
    }

    func stopCapture() {
        captureResumeTask?.cancel()
        captureResumesAt = nil
        companion.closePanel()
        contentInteraction.close()
        experiences.setPausedByUser(true)
        captureCoordinator.stopCapture()
        automationCoordinator.stop()
    }

    func pauseCaptureTemporarily() {
        guard captureIsRunning else { return }
        stopCapture()
        captureResumesAt = Date().addingTimeInterval(900)
        captureResumeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(900))
            guard !Task.isCancelled, let self else { return }
            startCapture()
        }
    }

    func toggleCapture() {
        captureCoordinator.isRunning ? stopCapture() : startCapture()
    }

    @discardableResult
    func beginRecording() -> Bool { beginRecording(requiresTrackpad: true) }

    /// A captura local não depende de TCC. Ainda possui a mesma exclusão mútua
    /// da gravação global, para que uma edição nunca execute automações.
    func beginLocalRecording() -> Bool { beginRecording(requiresTrackpad: false) }

    private func beginRecording(requiresTrackpad: Bool) -> Bool {
        guard !recordingIsActive, practiceSession.sessionID == nil else {
            presentedError = "Já existe uma prática ou gravação em outra janela. Encerre-a antes de começar."
            return false
        }
        guard !laboratoryCoordinator.isRecording, !laboratoryCoordinator.isReplaying else {
            presentedError = "Encerre a gravação ou replay no Laboratório antes de praticar ou gravar um gatilho."
            return false
        }
        automationCoordinator.stop()
        recordedEvent = nil
        recordingIsActive = true
        captureWasRunningBeforeRecording = captureCoordinator.isRunning
        trackpadWasRunningBeforeRecording = captureCoordinator.isTrackpadObservationRunning
        if requiresTrackpad {
            guard startTrackpadObservation() else {
                recordingIsActive = false
                return false
            }
            if permissions.status.canCaptureGlobalInput { startCapture() }
        }
        localInputCapture.start(onEvent: { [weak self] event in
            guard let self, self.recordingIsActive else { return }
            self.recordedEvent = event
            self.practiceSession.receive(event)
        }, onModifiers: { [weak self] in self?.activeModifiers = $0 }, onCancel: { [weak self] in
            guard let self else { return }
            if let id = self.practiceSession.sessionID { self.endPractice(sessionID: id) }
            else { self.endRecording() }
        })
        return true
    }

    func endRecording() {
        guard recordingIsActive else { return }
        recordingIsActive = false
        localInputCapture.stop()
        activeModifiers = []
        if !captureWasRunningBeforeRecording {
            captureCoordinator.stopGlobalCapture()
        }
        if !trackpadWasRunningBeforeRecording {
            captureCoordinator.stopTrackpadObservation()
        }
        captureWasRunningBeforeRecording = false
        trackpadWasRunningBeforeRecording = false
    }

    func beginPractice(_ rule: ShortcutRule, repetitionLimit: Int? = 3) -> UUID? {
        guard beginRecording(requiresTrackpad: rule.trigger.requiresTrackpadCapture) else { return nil }
        return practiceSession.begin(rule, repetitionLimit: repetitionLimit)
    }

    var availableDisplays: [DisplayCatalogService.Choice] {
        DisplayCatalogService.availableDisplays()
    }

    /// O token impede que o fechamento tardio de outra janela encerre uma nova prática.
    func endPractice(sessionID: UUID) {
        guard practiceSession.sessionID == sessionID else { return }
        endRecording()
        practiceSession.end()
    }

    func clearLog() {
        do {
            try eventLogStore.clear()
        } catch {
            presentedError = error.localizedDescription
        }
    }

    func resolveScriptApproval(approved: Bool) {
        automationCoordinator.resolveScriptApproval(approved: approved)
    }

    func cancelWorkflow(ruleID: UUID) {
        automationCoordinator.cancelWorkflow(ruleID: ruleID)
    }

    private func presentTrackpadObservationError() {
        presentedError = permissions.status.inputMonitoring == .denied
            ? "O Monitoramento de Entrada foi negado. Abra os Ajustes do Sistema, habilite o \(TicoBrand.displayName) e reabra o app."
            : "Conceda Monitoramento de Entrada e reabra o \(TicoBrand.displayName) para observar contatos globais."
    }

    private func receive(_ incomingEvent: InputEventDescriptor) {
        // O monitor local já tratou teclado/mouse nesta sessão. Ignorar a cópia
        // global evita duplicação e evita sobrescrever a combinação ao soltar ⌘.
        if recordingIsActive, incomingEvent.kind != .trackpadGesture { return }
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
            practiceSession.receive(event)
            return
        }
        guard !laboratoryCoordinator.isReplaying, !laboratoryCoordinator.isRecording else { return }
        if captureCoordinator.isRunning, companion.handle(event) { return }
        guard captureCoordinator.isRunning || recordingIsActive else { return }
        lastEvent = event
        guard captureCoordinator.isRunning else { return }
        automationCoordinator.handle(
            event: event,
            modifiers: activeModifiers
        )
    }
}
