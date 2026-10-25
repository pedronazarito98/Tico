import Combine
import Foundation

/// Publica após a escrita atômica; falha mantém o último estado válido em memória.
/// Paralelo com React: uma fonte observável compartilhada, sem copiar o payload.
@MainActor
final class ContentRecipeStore: ObservableObject {
    @Published private(set) var recipes: [ContentRecipe] = []
    @Published private(set) var errorMessage: String?
    private let repository: any ContentRecipeRepository
    private var loadedSuccessfully = false

    init(repository: any ContentRecipeRepository) {
        self.repository = repository
        do {
            recipes = try repository.read()?.recipes ?? []
            loadedSuccessfully = true
        } catch { errorMessage = ContentRecipeError.unavailable.localizedDescription }
    }

    func save(_ recipe: ContentRecipe) throws {
        var candidate = recipes
        var normalized = recipe
        normalized.name = normalized.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let index = candidate.firstIndex(where: { $0.id == recipe.id }) {
            candidate[index] = normalized
        } else { candidate.append(normalized) }
        try persist(candidate)
    }

    func remove(_ id: UUID) throws {
        try persist(recipes.filter { $0.id != id })
    }

    private func persist(_ candidate: [ContentRecipe]) throws {
        guard loadedSuccessfully else { throw ContentRecipeError.unavailable }
        let document = ContentRecipeDocument(recipes: candidate)
        try FileContentRecipeRepository.validate(document)
        do { try repository.write(document) }
        catch {
            errorMessage = ContentRecipeError.persistence.localizedDescription
            throw ContentRecipeError.persistence
        }
        recipes = candidate
        errorMessage = nil
    }
}
