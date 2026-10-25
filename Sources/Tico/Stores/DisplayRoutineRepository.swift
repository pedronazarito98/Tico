import Foundation

protocol DisplayRoutineRepository {
    func read() throws -> DisplayRoutineDocument?
    func write(_ document: DisplayRoutineDocument) throws
}

/// Sidecar limitado, validado e atômico; falhas nunca substituem os dados por defaults.
final class FileDisplayRoutineRepository: DisplayRoutineRepository {
    private let dataURL: URL
    private static let maximumBytes = 128 * 1_024
    init(dataURL: URL) { self.dataURL = dataURL }

    func read() throws -> DisplayRoutineDocument? {
        guard FileManager.default.fileExists(atPath: dataURL.path) else { return nil }
        guard dataURL.isFileURL,
              try dataURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else {
            throw DisplayRoutineError.invalidDocument
        }
        let handle = try FileHandle(forReadingFrom: dataURL)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: Self.maximumBytes + 1) ?? Data()
        guard data.count <= Self.maximumBytes else { throw DisplayRoutineError.invalidDocument }
        let document = try JSONDecoder().decode(DisplayRoutineDocument.self, from: data)
        try Self.validate(document)
        return document
    }

    func write(_ document: DisplayRoutineDocument) throws {
        try Self.validate(document)
        guard dataURL.isFileURL else { throw DisplayRoutineError.invalidDocument }
        let data = try JSONEncoder().encode(document)
        guard data.count <= Self.maximumBytes else { throw DisplayRoutineError.invalidDocument }
        try FileManager.default.createDirectory(at: dataURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: dataURL, options: .atomic)
    }

    static func validate(_ document: DisplayRoutineDocument) throws {
        guard document.version == 1, document.routines.count <= 64,
              Set(document.routines.map(\.id)).count == document.routines.count else {
            throw DisplayRoutineError.invalidDocument
        }
        for routine in document.routines {
            guard !routine.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  routine.name.utf8.count <= 160,
                  routine.externalCount.map({ (0...32).contains($0) }) ?? true,
                  routine.mainDisplayRole != .unavailable else {
                throw DisplayRoutineError.invalidDocument
            }
        }
    }
}
