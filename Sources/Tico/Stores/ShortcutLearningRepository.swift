import Foundation

protocol ShortcutLearningRepository {
    func read() throws -> ShortcutLearningDocument?
    func write(_ document: ShortcutLearningDocument) throws
}

/// Sidecar independente do schema das regras. A escrita atômica antecede a publicação.
final class FileShortcutLearningRepository: ShortcutLearningRepository {
    private let dataURL: URL
    private static let maximumBytes = 128 * 1_024

    init(dataURL: URL) { self.dataURL = dataURL }

    func read() throws -> ShortcutLearningDocument? {
        guard FileManager.default.fileExists(atPath: dataURL.path) else { return nil }
        guard dataURL.isFileURL,
              try dataURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
            throw ShortcutLearningError.invalidDocument
        }
        let handle = try FileHandle(forReadingFrom: dataURL)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: Self.maximumBytes + 1) ?? Data()
        guard data.count <= Self.maximumBytes else { throw ShortcutLearningError.invalidDocument }
        let document = try JSONDecoder().decode(ShortcutLearningDocument.self, from: data)
        try validate(document)
        return document
    }

    func write(_ document: ShortcutLearningDocument) throws {
        try validate(document)
        guard dataURL.isFileURL else { throw ShortcutLearningError.invalidDocument }
        let data = try JSONEncoder().encode(document)
        guard data.count <= Self.maximumBytes else { throw ShortcutLearningError.invalidDocument }
        try FileManager.default.createDirectory(at: dataURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: dataURL, options: .atomic)
    }

    private func validate(_ document: ShortcutLearningDocument) throws {
        guard document.version == ShortcutLearningDocument.currentVersion,
              document.masteredRuleRevisions.count <= 1_000,
              document.masteredRuleRevisions.values.allSatisfy({ $0.timeIntervalSince1970.isFinite }) else {
            throw ShortcutLearningError.invalidDocument
        }
        if let goal = document.goal {
            guard (0...ShortcutLearningGoal.requiredSuccesses).contains(goal.gestureSuccesses),
                  (0...1_000_000).contains(goal.panelSuccesses),
                  !document.masteredRuleIDs.contains(goal.ruleID),
                  [goal.ruleRevision, goal.lastReminderAt, goal.snoozedUntil].compactMap({ $0 })
                    .allSatisfy({ $0.timeIntervalSince1970.isFinite }) else {
                throw ShortcutLearningError.invalidDocument
            }
        }
    }
}
