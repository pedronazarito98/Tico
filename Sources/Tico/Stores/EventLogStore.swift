import Combine
import Foundation

struct ExecutionLogEntry: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var ruleID: UUID?
    var ruleName: String
    var action: ShortcutAction
    var result: ActionExecutionResult
    var stepExecutions: [WorkflowStepExecution]

    init(
        id: UUID = UUID(),
        ruleID: UUID? = nil,
        ruleName: String,
        action: ShortcutAction,
        result: ActionExecutionResult,
        stepExecutions: [WorkflowStepExecution] = []
    ) {
        self.id = id
        self.ruleID = ruleID
        self.ruleName = ruleName
        self.action = action
        self.result = result
        self.stepExecutions = stepExecutions
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case ruleID
        case ruleName
        case action
        case result
        case stepExecutions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        ruleID = try container.decodeIfPresent(UUID.self, forKey: .ruleID)
        ruleName = try container.decode(String.self, forKey: .ruleName)
        action = try container.decode(ShortcutAction.self, forKey: .action)
        result = try container.decode(ActionExecutionResult.self, forKey: .result)
        stepExecutions = try container.decodeIfPresent(
            [WorkflowStepExecution].self,
            forKey: .stepExecutions
        ) ?? []
    }
}

final class EventLogStore: ObservableObject {
    static let currentDocumentVersion = 1

    @Published private(set) var entries: [ExecutionLogEntry] = []
    @Published private(set) var lastError: String?

    let fileURL: URL
    let maximumEntryCount: Int

    private let fileManager: FileManager

    init(
        fileURL: URL? = nil,
        maximumEntryCount: Int = 100,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)
        self.maximumEntryCount = max(1, maximumEntryCount)

        do {
            try load()
        } catch {
            lastError = error.localizedDescription
        }
    }

    static func defaultFileURL(fileManager: FileManager = .default) -> URL {
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory

        return applicationSupport
            .appendingPathComponent(
                TicoBrand.applicationSupportDirectoryName,
                isDirectory: true
            )
            .appendingPathComponent("execution-log.json", isDirectory: false)
    }

    func load() throws {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            entries = []
            lastError = nil
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            let document = try decoder.decode(EventLogDocument.self, from: Data(contentsOf: fileURL))
            guard document.version <= Self.currentDocumentVersion else {
                throw ShortcutStoreError.unsupportedVersion(document.version)
            }
            entries = Array(document.entries.prefix(maximumEntryCount))
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    func record(_ entry: ExecutionLogEntry) throws {
        try commit { entries in
            entries.insert(entry, at: 0)
            if entries.count > maximumEntryCount {
                entries.removeLast(entries.count - maximumEntryCount)
            }
        }
    }

    @discardableResult
    func record(
        rule: ShortcutRule,
        result: ActionExecutionResult,
        stepExecutions: [WorkflowStepExecution] = []
    ) throws -> ExecutionLogEntry {
        let entry = ExecutionLogEntry(
            ruleID: rule.id,
            ruleName: rule.name,
            action: rule.action,
            result: result,
            stepExecutions: stepExecutions
        )
        try record(entry)
        return entry
    }

    func clear() throws {
        try commit { $0.removeAll() }
    }

    private func commit(_ mutation: (inout [ExecutionLogEntry]) -> Void) throws {
        let previousEntries = entries

        do {
            mutation(&entries)
            try save()
            lastError = nil
        } catch {
            entries = previousEntries
            lastError = error.localizedDescription
            throw error
        }
    }

    private func save() throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let document = EventLogDocument(
            version: Self.currentDocumentVersion,
            entries: entries
        )
        try encoder.encode(document).write(to: fileURL, options: .atomic)
    }
}

private struct EventLogDocument: Codable {
    let version: Int
    let entries: [ExecutionLogEntry]
}
