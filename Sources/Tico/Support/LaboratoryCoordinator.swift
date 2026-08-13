import Combine
import Foundation

/// Owns recording, replay and validation controls for the laboratory.
///
/// `TrackpadGestureService` remains the single source of truth for raw and
/// derived laboratory state. The published values here are projections for
/// consumers that should not reach the service directly.
@MainActor
final class LaboratoryCoordinator: ObservableObject {
    @Published private(set) var snapshot: TrackpadLaboratorySnapshot?
    @Published private(set) var isRecording = false
    @Published private(set) var recordedFrameCount = 0
    @Published private(set) var lastRecording: TrackpadReplayDocument?
    @Published private(set) var isReplaying = false
    @Published private(set) var replayProgress = 0.0

    private let captureCoordinator: CaptureCoordinator
    private let trackpadGestures: TrackpadGestureService
    private let calibrationStore: TrackpadCalibrationStore
    private var cancellables = Set<AnyCancellable>()

    init(
        captureCoordinator: CaptureCoordinator,
        calibrationStore: TrackpadCalibrationStore
    ) {
        self.captureCoordinator = captureCoordinator
        self.trackpadGestures = captureCoordinator.trackpadGestures
        self.calibrationStore = calibrationStore

        trackpadGestures.$laboratorySnapshot
            .compactMap { $0 }
            .sink { [weak self] snapshot in
                self?.snapshot = snapshot
            }
            .store(in: &cancellables)
        trackpadGestures.$isRecordingSession
            .removeDuplicates()
            .sink { [weak self] isRecording in
                self?.isRecording = isRecording
            }
            .store(in: &cancellables)
        trackpadGestures.$recordedFrameCount
            .removeDuplicates()
            .sink { [weak self] count in
                self?.recordedFrameCount = count
            }
            .store(in: &cancellables)
        trackpadGestures.$lastRecordedDocument
            .compactMap { $0 }
            .sink { [weak self] document in
                self?.lastRecording = document
            }
            .store(in: &cancellables)
        trackpadGestures.$isReplaying
            .removeDuplicates()
            .sink { [weak self] isReplaying in
                self?.isReplaying = isReplaying
            }
            .store(in: &cancellables)
        trackpadGestures.$replayProgress
            .removeDuplicates()
            .sink { [weak self] progress in
                self?.replayProgress = progress
            }
            .store(in: &cancellables)
        calibrationStore.$calibrationSet
            .sink { [weak self] calibrationSet in
                self?.trackpadGestures.updateCalibration(calibrationSet)
            }
            .store(in: &cancellables)
    }

    @discardableResult
    func startObservation() -> Bool {
        captureCoordinator.startTrackpadObservation()
    }

    func stopObservation() {
        captureCoordinator.stopTrackpadObservation()
    }

    @discardableResult
    func startRecording(name: String) -> Bool {
        guard startObservation() else { return false }
        trackpadGestures.startSessionRecording(name: name)
        return true
    }

    @discardableResult
    func stopRecording() -> TrackpadReplayDocument? {
        trackpadGestures.stopSessionRecording()
    }

    func cancelRecording() {
        trackpadGestures.cancelSessionRecording()
    }

    func replay(_ document: TrackpadReplayDocument, speed: Double = 1) {
        trackpadGestures.replay(document, speed: speed)
    }

    func cancelReplay() {
        trackpadGestures.cancelReplay()
    }

    func activatePublicFallbackForValidation() -> Bool {
        guard startObservation() else { return false }
        trackpadGestures.activateSystemFallbackForValidation()
        return true
    }

    func restoreAdvancedCapture() {
        trackpadGestures.restoreAdvancedCapture()
    }
}
