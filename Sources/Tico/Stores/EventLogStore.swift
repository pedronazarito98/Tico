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

/// Projeção MainActor do histórico confirmado, nunca da intenção de gravar.
/// Paralelo com React: revisões impedem que um efeito assíncrono antigo publique
/// sobre um resultado novo; o writer serial mantém a ordem real no disco.
@MainActor
final class EventLogStore: ObservableObject {
    nonisolated static let currentDocumentVersion = 2
    @Published private(set) var entries: [ExecutionLogEntry]
    @Published private(set) var lastError: String?
    let fileURL: URL
    let maximumEntryCount: Int
    private let repository: any EventLogPersisting
    private var nextRevision: UInt64 = 0
    private var durableRevision: UInt64 = 0
    private var statusRevision: UInt64 = 0

    init(fileURL: URL? = nil, maximumEntryCount: Int = 100,
         fileManager: FileManager = .default, repository: (any EventLogPersisting)? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)
        self.maximumEntryCount = max(1, maximumEntryCount)
        let repository = repository ?? EventLogRepository(fileURL: self.fileURL,
            maximumEntryCount: self.maximumEntryCount, fileManager: fileManager)
        self.repository = repository
        entries = repository.initialEntries
        lastError = repository.initialError
    }

    nonisolated static func defaultFileURL(fileManager: FileManager = .default) -> URL {
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory,
            in: .userDomainMask).first ?? fileManager.temporaryDirectory
        return applicationSupport.appendingPathComponent(TicoBrand.applicationSupportDirectoryName,
            isDirectory: true).appendingPathComponent("execution-log.json", isDirectory: false)
    }

    func record(_ entry: ExecutionLogEntry) async throws { try await commit(.record(entry)) }

    @discardableResult
    func record(rule: ShortcutRule, result: ActionExecutionResult,
                stepExecutions: [WorkflowStepExecution] = []) async throws -> ExecutionLogEntry {
        let entry = ExecutionLogEntry(ruleID: rule.id, ruleName: rule.name, action: rule.action,
            result: result, stepExecutions: stepExecutions)
        try await record(entry)
        return entry
    }

    func clear() async throws { try await commit(.clear) }
    func flush() async throws { try await commit(.flush) }

    private func commit(_ mutation: EventLogMutation) async throws {
        nextRevision &+= 1
        let revision = nextRevision
        let result = await withCheckedContinuation { continuation in
            repository.submit(mutation, revision: revision) { continuation.resume(returning: $0) }
        }
        switch result {
        case let .success(receipt):
            if receipt.revision >= durableRevision {
                durableRevision = receipt.revision
                entries = receipt.entries
            }
            if revision >= statusRevision { statusRevision = revision; lastError = nil }
        case let .failure(error):
            if revision >= statusRevision { statusRevision = revision; lastError = error.localizedDescription }
            throw error
        }
    }
}
