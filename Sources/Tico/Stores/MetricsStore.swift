import Combine
import Foundation

enum MetricOutcome: String, Codable, CaseIterable, Hashable, Sendable {
    case success
    case failure
    case rejected
    case cancelled
}

struct GestureMetricEvent: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var occurredAt: Date
    var ruleID: UUID?
    var ruleName: String?
    var gesture: TrackpadGesture?
    var deviceID: String?
    var outcome: MetricOutcome
    var confidence: Double?
    var latency: TimeInterval

    init(
        id: UUID = UUID(),
        occurredAt: Date = Date(),
        ruleID: UUID? = nil,
        ruleName: String? = nil,
        gesture: TrackpadGesture? = nil,
        deviceID: String? = nil,
        outcome: MetricOutcome,
        confidence: Double? = nil,
        latency: TimeInterval = 0
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.ruleID = ruleID
        self.ruleName = ruleName
        self.gesture = gesture
        self.deviceID = deviceID
        self.outcome = outcome
        self.confidence = confidence.map { min(max($0, 0), 1) }
        self.latency = max(0, latency)
    }
}

struct MetricsSummary: Equatable {
    var total: Int
    var successes: Int
    var failures: Int
    var rejections: Int
    var averageConfidence: Double?
    var averageLatency: TimeInterval

    var successRate: Double {
        guard total > 0 else { return 0 }
        return Double(successes) / Double(total)
    }
}

@MainActor
final class MetricsStore: ObservableObject {
    nonisolated static let currentVersion = 1

    @Published private(set) var events: [GestureMetricEvent] = []
    @Published private(set) var lastError: String?

    let fileURL: URL
    let maximumEventCount: Int

    private let repository: MetricsRepository

    init(fileURL: URL? = nil, maximumEventCount: Int = 1_000,
         fileManager: FileManager = .default, scheduler: (any MetricsWriteScheduling)? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)
        self.maximumEventCount = max(10, maximumEventCount)
        repository = MetricsRepository(fileURL: self.fileURL, maximumEventCount: self.maximumEventCount,
            fileManager: fileManager, scheduler: scheduler)
        events = repository.events
        lastError = repository.lastError
        repository.onChange = { [weak self] in self?.publishRepository() }
    }

    nonisolated    static func defaultFileURL(fileManager: FileManager = .default) -> URL {
        let root = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory
        return root
            .appendingPathComponent(
                TicoBrand.applicationSupportDirectoryName,
                isDirectory: true
            )
            .appendingPathComponent("metrics.json")
    }

    var summary: MetricsSummary {
        let confidenceValues = events.compactMap(\.confidence)
        return MetricsSummary(
            total: events.count,
            successes: events.filter { $0.outcome == .success }.count,
            failures: events.filter { $0.outcome == .failure }.count,
            rejections: events.filter { $0.outcome == .rejected }.count,
            averageConfidence: confidenceValues.isEmpty
                ? nil
                : confidenceValues.reduce(0, +) / Double(confidenceValues.count),
            averageLatency: events.isEmpty
                ? 0
                : events.map(\.latency).reduce(0, +) / Double(events.count)
        )
    }

    func record(_ event: GestureMetricEvent) {
        repository.record(event)
        publishRepository()
    }

    func clear() async throws { try await repository.clear(); publishRepository() }
    func flush() async throws { try await repository.flush(); publishRepository() }

    /// O recorte é imutável desde a solicitação; a barreira confirma as revisões
    /// anteriores antes de exportar, mesmo se novos eventos chegarem durante IO.
    func exportCSV(to url: URL, events selection: [GestureMetricEvent]? = nil) async throws {
        try await repository.export(to: url, selection: selection ?? events)
    }

    private func publishRepository() {
        events = repository.events
        lastError = repository.lastError
    }
}
