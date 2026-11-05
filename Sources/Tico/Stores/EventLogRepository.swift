import Foundation

enum EventLogMutation: Sendable {
    case record(ExecutionLogEntry)
    case clear
    case flush
}

struct EventLogRevision: Sendable {
    let revision: UInt64
    let entries: [ExecutionLogEntry]
}

/// Porta de confirmação durável. A submissão é síncrona para preservar a ordem
/// de ingresso; somente o ACK pode suspender o chamador.
protocol EventLogPersisting: Sendable {
    var initialEntries: [ExecutionLogEntry] { get }
    var initialError: String? { get }
    func submit(_ mutation: EventLogMutation, revision: UInt64,
                completion: @escaping @Sendable (Result<EventLogRevision, Error>) -> Void)
}

/// A fila é o único owner de durableEntries e failedRecords após o init.
/// `@unchecked Sendable` encapsula FileManager e a fila; nenhum estado mutável
/// escapa dela. O carregamento inicial permanece síncrono e compatível.
final class EventLogRepository: EventLogPersisting, @unchecked Sendable {
    let initialEntries: [ExecutionLogEntry]
    let initialError: String?
    private let queue = DispatchQueue(label: "Tico.EventLogRepository", qos: .utility)
    private let fileURL: URL
    private let fileManager: FileManager
    private let maximumEntryCount: Int
    private var durableEntries: [ExecutionLogEntry]
    private var failedRecords: [ExecutionLogEntry] = []

    init(fileURL: URL, maximumEntryCount: Int, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        self.maximumEntryCount = max(1, maximumEntryCount)
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .millisecondsSince1970
                let document = try decoder.decode(EventLogDocument.self, from: Data(contentsOf: fileURL))
                guard document.version <= 2 else { throw ShortcutStoreError.unsupportedVersion(document.version) }
                initialEntries = Array(document.entries.prefix(self.maximumEntryCount))
            } else { initialEntries = [] }
            initialError = nil
        } catch {
            initialEntries = []
            initialError = error.localizedDescription
        }
        durableEntries = initialEntries
    }

    func submit(_ mutation: EventLogMutation, revision: UInt64,
                completion: @escaping @Sendable (Result<EventLogRevision, Error>) -> Void) {
        queue.async { [self] in
            do {
                var candidate = durableEntries
                switch mutation {
                case let .record(entry):
                    // Registros que falharam continuam pendentes; retentar IO nunca
                    // repete o efeito. UUID evita duplicação em retry explícito.
                    failedRecords.removeAll { $0.id == entry.id }
                    failedRecords.insert(entry, at: 0)
                    failedRecords = Array(failedRecords.prefix(maximumEntryCount))
                case .clear: candidate = []
                case .flush: break
                }
                if case .clear = mutation { } else {
                    let ids = Set(failedRecords.map(\.id))
                    candidate = Array((failedRecords + candidate.filter { !ids.contains($0.id) }).prefix(maximumEntryCount))
                }
                let needsWrite: Bool
                if case .flush = mutation { needsWrite = !failedRecords.isEmpty } else { needsWrite = true }
                if needsWrite {
                    try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    let encoder = JSONEncoder()
                    encoder.dateEncodingStrategy = .millisecondsSince1970
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    try encoder.encode(EventLogDocument(version: 2, entries: candidate)).write(to: fileURL, options: .atomic)
                    durableEntries = candidate
                    failedRecords.removeAll()
                }
                completion(.success(EventLogRevision(revision: revision, entries: durableEntries)))
            } catch {
                // Clear falho não entra na pendência: repeti-lo silenciosamente
                // depois apagaria registros novos aceitos durante a falha.
                completion(.failure(error))
            }
        }
    }
}

private struct EventLogDocument: Codable {
    let version: Int
    let entries: [ExecutionLogEntry]
}
