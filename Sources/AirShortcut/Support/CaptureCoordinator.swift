import AppKit
import Combine
import Foundation
import OSLog

enum CaptureStartOutcome: Equatable {
    case started
    case blocked(message: String)
    case failed(message: String)
}

/// Owns the lifecycle of global input and trackpad observation.
///
/// The coordinator is main-actor isolated. Platform callbacks enter through
/// tasks scheduled on the main actor, so only one start/stop transition can
/// publish capture state at a time.
@MainActor
final class CaptureCoordinator: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var trackpadCaptureMode: TrackpadCaptureMode = .stopped
    @Published private(set) var trackpadStartupError: String?
    @Published private(set) var detectedTrackpads: [TrackpadHardwareInfo] = []

    let trackpadGestures: TrackpadGestureService

    private let globalEventTap: GlobalEventTapService
    private let permissions: PermissionCoordinator
    private let hardwareDetector: TrackpadHardwareDetector
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pedronazarito.AirShortcut",
        category: "GlobalCapture"
    )
    private var eventHandler: ((InputEventDescriptor) -> Void)?
    private var cancellables = Set<AnyCancellable>()

    init(
        globalEventTap: GlobalEventTapService,
        trackpadGestures: TrackpadGestureService,
        permissions: PermissionCoordinator,
        hardwareDetector: TrackpadHardwareDetector
    ) {
        self.globalEventTap = globalEventTap
        self.trackpadGestures = trackpadGestures
        self.permissions = permissions
        self.hardwareDetector = hardwareDetector

        trackpadGestures.$captureMode
            .removeDuplicates()
            .sink { [weak self] mode in
                self?.trackpadCaptureMode = mode
            }
            .store(in: &cancellables)
        trackpadGestures.$startupError
            .removeDuplicates()
            .sink { [weak self] error in
                self?.trackpadStartupError = error
            }
            .store(in: &cancellables)
    }

    func setEventHandler(_ handler: @escaping (InputEventDescriptor) -> Void) {
        eventHandler = handler
    }

    @discardableResult
    func startTrackpadObservation() -> Bool {
        permissions.refresh()
        if !permissions.status.canCaptureGlobalInput,
           permissions.status.inputMonitoring == .notDetermined {
            permissions.requestInputMonitoring()
            permissions.refresh()
        }
        guard permissions.status.canCaptureGlobalInput else {
            trackpadGestures.stop()
            syncTrackpadState()
            return false
        }

        refreshTrackpadHardware()
        guard !trackpadGestures.isRunning else { return true }
        trackpadGestures.start { [weak self] event in
            self?.eventHandler?(event)
        }
        syncTrackpadState()
        return trackpadGestures.isRunning
    }

    func refreshTrackpadHardware() {
        detectedTrackpads = hardwareDetector.detect()
    }

    @discardableResult
    func startCapture() -> CaptureStartOutcome {
        guard !globalEventTap.isRunning else {
            isRunning = true
            return .started
        }

        permissions.refresh()
        if !permissions.status.canCaptureGlobalInput {
            if permissions.status.inputMonitoring == .notDetermined {
                permissions.requestInputMonitoring()
            }
            if !permissions.status.canCaptureGlobalInput {
                isRunning = false
                let message = permissions.status.inputMonitoring == .denied
                    ? "O Monitoramento de Entrada foi negado. Abra os Ajustes do Sistema, habilite o \(TicoBrand.displayName) e reabra o app."
                    : "Conceda Monitoramento de Entrada e reabra o \(TicoBrand.displayName) para iniciar a captura global."
                if permissions.status.inputMonitoring == .denied {
                    permissions.openInputMonitoringSettings()
                }
                logger.error(
                    "Capture start blocked by TCC: inputMonitoring=\(self.permissions.status.inputMonitoring.rawValue, privacy: .public), accessibility=\(self.permissions.status.accessibilityGranted, privacy: .public)"
                )
                return .blocked(message: message)
            }
        }

        guard startTrackpadObservation() else {
            isRunning = false
            return .blocked(
                message: "Conceda Monitoramento de Entrada e reabra o \(TicoBrand.displayName) para iniciar a captura global."
            )
        }

        do {
            try globalEventTap.start(
                onEvent: { [weak self] event in
                    Task { @MainActor [weak self] in
                        self?.eventHandler?(event)
                    }
                },
                onStateChange: { [weak self] isRunning in
                    Task { @MainActor [weak self] in
                        self?.isRunning = isRunning
                    }
                }
            )
            isRunning = true
            logger.info("Global capture started")
            return .started
        } catch {
            trackpadGestures.stop()
            syncTrackpadState()
            isRunning = false
            let message = permissions.status.canCaptureGlobalInput
                ? "O macOS reconhece a permissão, mas não criou o monitor global. Encerre e reabra o \(TicoBrand.displayName). Detalhe: \(error.localizedDescription)"
                : error.localizedDescription
            logger.error("Global capture failed: \(error.localizedDescription, privacy: .public)")
            return .failed(message: message)
        }
    }

    func stopGlobalCapture() {
        globalEventTap.stop()
        isRunning = false
    }

    func stopTrackpadObservation() {
        trackpadGestures.stop()
        syncTrackpadState()
    }

    func stopCapture() {
        stopGlobalCapture()
        stopTrackpadObservation()
    }

    private func syncTrackpadState() {
        trackpadCaptureMode = trackpadGestures.captureMode
        trackpadStartupError = trackpadGestures.startupError
    }
}
