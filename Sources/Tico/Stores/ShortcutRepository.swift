import Foundation

struct ShortcutRepositoryReadResult {
    let data: Data
    let document: DecodedShortcutDocument
}

/// A persistence boundary for validated shortcut documents.
///
/// Implementations must make write atomic from the store's perspective:
/// either the complete encoded document is available at the destination or
/// the call throws without publishing a partial document.
protocol ShortcutRepository {
    var fileURL: URL { get }

    func readCurrentDocument() throws -> ShortcutRepositoryReadResult?
    func readDocument(from sourceURL: URL) throws -> DecodedShortcutDocument
    func write(_ document: ShortcutDocument, to destinationURL: URL) throws
    func backupCurrentDocument(_ data: Data, version: Int) throws
}

final class FileShortcutRepository: ShortcutRepository {
    let fileURL: URL

    private let fileManager: FileManager

    init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    func readCurrentDocument() throws -> ShortcutRepositoryReadResult? {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try DocumentSecurityPolicy.readBoundedData(from: fileURL)
        return ShortcutRepositoryReadResult(
            data: data,
            document: try ShortcutDocumentCodec.decode(data)
        )
    }

    func readDocument(from sourceURL: URL) throws -> DecodedShortcutDocument {
        let data = try DocumentSecurityPolicy.readBoundedData(from: sourceURL)
        return try ShortcutDocumentCodec.decode(data)
    }

    func write(_ document: ShortcutDocument, to destinationURL: URL) throws {
        let directoryURL = destinationURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try ShortcutDocumentCodec.encode(document)
        try data.write(to: destinationURL, options: .atomic)
    }

    func backupCurrentDocument(_ data: Data, version: Int) throws {
        let baseURL = fileURL.deletingPathExtension()
        var backupURL = baseURL.appendingPathExtension("v\(version).backup.json")
        var suffix = 0
        // Um backup antigo da mesma versão pode conter regras diferentes. Nunca
        // o substituímos nem o tratamos como cópia do documento atual.
        while fileManager.fileExists(atPath: backupURL.path) {
            suffix += 1
            guard suffix <= 1_000 else { throw CocoaError(.fileWriteFileExists) }
            backupURL = baseURL.appendingPathExtension("v\(version).backup-\(suffix).json")
        }
        try data.write(to: backupURL, options: .atomic)
    }
}
