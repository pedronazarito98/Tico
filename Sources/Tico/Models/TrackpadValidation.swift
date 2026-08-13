import Foundation

enum HardwareValidationCheck: String, Codable, CaseIterable, Identifiable, Sendable {
    case internalTrackpad
    case magicTrackpad
    case sleepWake
    case disconnectReconnect
    case publicFallback
    case normalUse

    var id: Self { self }
}

struct TrackpadValidationReport: Codable, Equatable, Sendable {
    var recognizedByGesture: [TrackpadGesture: Int] = [:]
    var falsePositivesByGesture: [TrackpadGesture: Int] = [:]
    var rejectedSessionCount = 0
    var ignoredSessionCount = 0
    var completedChecks: Set<HardwareValidationCheck> = []
    var normalUseStartedAt: Date?
    var accumulatedNormalUseDuration: TimeInterval = 0
    var updatedAt = Date()

    var recognizedCount: Int {
        recognizedByGesture.values.reduce(0, +)
    }

    var falsePositiveCount: Int {
        falsePositivesByGesture.values.reduce(0, +)
    }

    var falsePositiveRate: Double {
        guard recognizedCount > 0 else { return 0 }
        return Double(falsePositiveCount) / Double(recognizedCount)
    }

    var normalUseDuration: TimeInterval {
        accumulatedNormalUseDuration
            + (normalUseStartedAt.map { Date().timeIntervalSince($0) } ?? 0)
    }
}
