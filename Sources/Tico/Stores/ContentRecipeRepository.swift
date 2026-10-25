import Foundation

protocol ContentRecipeRepository {
    func read() throws -> ContentRecipeDocument?
    func write(_ document: ContentRecipeDocument) throws
}

/// Persistência limitada e atômica de configurações. Nunca recebe o payload do
/// painel. Documento inválido não é substituído por defaults durante o carregamento.
final class FileContentRecipeRepository: ContentRecipeRepository {
    private let dataURL: URL
    private static let maximumBytes = 128 * 1_024

    init(dataURL: URL) { self.dataURL = dataURL }

    func read() throws -> ContentRecipeDocument? {
        guard dataURL.isFileURL else { throw ContentRecipeError.invalidDocument }
        guard FileManager.default.fileExists(atPath: dataURL.path) else { return nil }
        let values = try dataURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw ContentRecipeError.invalidDocument
        }
        let handle = try FileHandle(forReadingFrom: dataURL)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: Self.maximumBytes + 1) ?? Data()
        guard data.count <= Self.maximumBytes else { throw ContentRecipeError.invalidDocument }
        let document = try JSONDecoder().decode(ContentRecipeDocument.self, from: data)
        try Self.validate(document)
        return document
    }

    func write(_ document: ContentRecipeDocument) throws {
        try Self.validate(document)
        guard dataURL.isFileURL else { throw ContentRecipeError.invalidDocument }
        if FileManager.default.fileExists(atPath: dataURL.path) {
            let values = try dataURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else {
                throw ContentRecipeError.invalidDocument
            }
        }
        let data = try JSONEncoder().encode(document)
        guard data.count <= Self.maximumBytes else { throw ContentRecipeError.invalidDocument }
        try FileManager.default.createDirectory(at: dataURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: dataURL, options: .atomic)
    }

    static func validate(_ document: ContentRecipeDocument) throws {
        guard document.version == 1, document.recipes.count <= 64,
              Set(document.recipes.map(\.id)).count == document.recipes.count,
              document.recipes.allSatisfy({ recipe in
                  recipe.validationMessage == nil && !ContentRecipe.builtIns.contains(where: { $0.id == recipe.id })
              }) else { throw ContentRecipeError.invalidDocument }
    }
}
