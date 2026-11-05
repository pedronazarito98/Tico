import Foundation

/// A fila executa toda codificação/escrita; propriedades são imutáveis após init.
/// O MainActor só chama load na construção, antes de haver trabalho concorrente.
final class MetricsFileStorage: @unchecked Sendable {
    private let queue = DispatchQueue(label: "Tico.MetricsRepository", qos: .utility)
    private let fileURL: URL
    private let fileManager: FileManager
    init(fileURL: URL, fileManager: FileManager) { self.fileURL = fileURL; self.fileManager = fileManager }

    func load() throws -> [GestureMetricEvent] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let document = try decoder.decode(MetricsDocument.self, from: Data(contentsOf: fileURL))
        guard document.version <= 1 else { throw ShortcutStoreError.unsupportedVersion(document.version) }
        return document.events
    }

    func write(_ events: [GestureMetricEvent]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                do {
                    try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .millisecondsSince1970
                    try encoder.encode(MetricsDocument(version: 1, events: events)).write(to: fileURL, options: .atomic)
                    continuation.resume()
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    func export(to url: URL, events: [GestureMetricEvent]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    var lines = ["date,rule,gesture,device,outcome,confidence,latency_ms"]
                    let formatter = ISO8601DateFormatter()
                    for event in events {
                        let row = [formatter.string(from: event.occurredAt), Self.csv(event.ruleName ?? ""),
                            event.gesture?.rawValue ?? "", Self.csv(event.deviceID ?? ""), event.outcome.rawValue,
                            event.confidence.map { String($0) } ?? "", String(format: "%.2f", event.latency * 1_000)]
                        lines.append(row.joined(separator: ","))
                    }
                    try Data(lines.joined(separator: "\n").utf8).write(to: url, options: .atomic)
                    continuation.resume()
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    private static func csv(_ value: String) -> String {
        let firstNonWhitespace = value.first { !$0.isWhitespace }
        let neutralized = firstNonWhitespace.map { "=+-@".contains($0) } == true ? "'\(value)" : value
        return "\"\(neutralized.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}

private struct MetricsDocument: Codable {
    let version: Int
    let events: [GestureMetricEvent]
}
