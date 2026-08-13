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

final class MetricsStore: ObservableObject {
    static let currentVersion = 1

    @Published private(set) var events: [GestureMetricEvent] = []
    @Published private(set) var lastError: String?

    let fileURL: URL
    let maximumEventCount: Int

    private let fileManager: FileManager

    init(
        fileURL: URL? = nil,
        maximumEventCount: Int = 1_000,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)
        self.maximumEventCount = max(10, maximumEventCount)
        do {
            try load()
        } catch {
            lastError = error.localizedDescription
        }
    }

    static func defaultFileURL(fileManager: FileManager = .default) -> URL {
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
        events.insert(event, at: 0)
        if events.count > maximumEventCount {
            events.removeLast(events.count - maximumEventCount)
        }
        persist()
    }

    func clear() {
        events.removeAll()
        persist()
    }

    func exportCSV(to url: URL) throws {
        var lines = ["date,rule,gesture,device,outcome,confidence,latency_ms"]
        let formatter = ISO8601DateFormatter()
        for event in events {
            let confidenceText = event.confidence.map { String($0) } ?? ""
            let row: [String] = [
                formatter.string(from: event.occurredAt),
                csv(event.ruleName ?? ""),
                event.gesture?.rawValue ?? "",
                csv(event.deviceID ?? ""),
                event.outcome.rawValue,
                confidenceText,
                String(format: "%.2f", event.latency * 1_000)
            ]
            lines.append(row.joined(separator: ","))
        }
        try Data(lines.joined(separator: "\n").utf8).write(to: url, options: .atomic)
    }

    private func load() throws {
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let document = try decoder.decode(
            MetricsDocument.self,
            from: Data(contentsOf: fileURL)
        )
        guard document.version <= Self.currentVersion else {
            throw ShortcutStoreError.unsupportedVersion(document.version)
        }
        events = Array(document.events.prefix(maximumEventCount))
    }

    private func persist() {
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .millisecondsSince1970
            let document = MetricsDocument(version: Self.currentVersion, events: events)
            try encoder.encode(document).write(to: fileURL, options: .atomic)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func csv(_ value: String) -> String {
        let firstNonWhitespace = value.first { !$0.isWhitespace }
        let neutralized = firstNonWhitespace.map { "=+-@".contains($0) } == true
            ? "'\(value)"
            : value
        return "\"\(neutralized.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

private struct MetricsDocument: Codable {
    var version: Int
    var events: [GestureMetricEvent]
}
