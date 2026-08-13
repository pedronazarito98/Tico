import Combine
import Foundation

final class TrackpadValidationStore: ObservableObject {
    @Published private(set) var report: TrackpadValidationReport {
        didSet { persist() }
    }
    @Published private(set) var lastAcceptedGesture: TrackpadGesture?

    private let defaults: UserDefaults
    private let storageKey: String

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = TicoBrand.userDefaultsPrefix + "trackpad-validation"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(TrackpadValidationReport.self, from: data) {
            var value = decoded
            // A running timer cannot survive process termination accurately.
            value.normalUseStartedAt = nil
            report = value
        } else {
            report = TrackpadValidationReport()
        }
    }

    func record(_ snapshot: TrackpadLaboratorySnapshot, acceptedEvent: GestureEvent?) {
        var updatedReport = report
        var didChange = false

        if let acceptedEvent {
            updatedReport.recognizedByGesture[acceptedEvent.kind, default: 0] += 1
            lastAcceptedGesture = acceptedEvent.kind
            didChange = true
        } else if snapshot.phase == .ended {
            switch snapshot.diagnostic.outcome {
            case .rejected:
                updatedReport.rejectedSessionCount += 1
                didChange = true
            case .ignored:
                updatedReport.ignoredSessionCount += 1
                didChange = true
            case .inProgress, .accepted, .cancelled:
                break
            }
        }

        guard didChange else { return }
        updatedReport.updatedAt = Date()
        report = updatedReport
    }

    func recordPublicFallbackGesture(_ gesture: TrackpadGesture) {
        var updatedReport = report
        updatedReport.recognizedByGesture[gesture, default: 0] += 1
        updatedReport.completedChecks.insert(.publicFallback)
        updatedReport.updatedAt = Date()
        lastAcceptedGesture = gesture
        report = updatedReport
    }

    func markLastRecognitionAsFalsePositive() {
        guard let lastAcceptedGesture else { return }
        var updatedReport = report
        updatedReport.falsePositivesByGesture[lastAcceptedGesture, default: 0] += 1
        updatedReport.updatedAt = Date()
        report = updatedReport
    }

    func setCheck(_ check: HardwareValidationCheck, completed: Bool) {
        var updatedReport = report
        if completed {
            guard updatedReport.completedChecks.insert(check).inserted else { return }
        } else {
            guard updatedReport.completedChecks.remove(check) != nil else { return }
        }
        updatedReport.updatedAt = Date()
        report = updatedReport
    }

    func startNormalUseMonitoring() {
        guard report.normalUseStartedAt == nil else { return }
        var updatedReport = report
        let timestamp = Date()
        updatedReport.normalUseStartedAt = timestamp
        updatedReport.updatedAt = timestamp
        report = updatedReport
    }

    func stopNormalUseMonitoring() {
        guard let startedAt = report.normalUseStartedAt else { return }
        var updatedReport = report
        let timestamp = Date()
        updatedReport.accumulatedNormalUseDuration += timestamp.timeIntervalSince(startedAt)
        updatedReport.normalUseStartedAt = nil
        updatedReport.completedChecks.insert(.normalUse)
        updatedReport.updatedAt = timestamp
        report = updatedReport
    }

    func reset() {
        report = TrackpadValidationReport()
        lastAcceptedGesture = nil
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(report) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
