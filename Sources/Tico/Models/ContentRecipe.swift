import Foundation

/// Receita manual: guarda somente intenção e destino, sem gatilho nem conteúdo.
/// É independente de ShortcutRule; regras existentes continuam intactas.
struct ContentRecipe: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = ""
    var configuration = ContentActionConfiguration(source: .provided, destination: .search(.web))

    var title: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? configuration.destination.recipeTitle : name
    }

    var validationMessage: String? {
        guard name.utf8.count <= 160, !name.contains("\0"),
              configuration.source == .provided else {
            return "Use um nome mais curto e o conteúdo fornecido no painel."
        }
        return configuration.validationMessage
    }

    static let google = ContentRecipe(
        id: UUID(uuid: (116, 105, 99, 111, 0, 0, 64, 0, 128, 0, 0, 0, 0, 0, 0, 1)),
        configuration: .init(source: .provided, destination: .search(.web)))
    static let apple = ContentRecipe(
        id: UUID(uuid: (116, 105, 99, 111, 0, 0, 64, 0, 128, 0, 0, 0, 0, 0, 0, 2)),
        configuration: .init(source: .provided, destination: .search(.documentation)))
    static let builtIns = [google, apple]
}

/// Sidecar aditivo. A versão 1 não altera o documento de regras nem seus IDs.
struct ContentRecipeDocument: Codable, Equatable {
    var version = 1
    var recipes: [ContentRecipe] = []
}

enum ContentRecipeError: LocalizedError {
    case invalidDocument, unavailable, persistence
    var errorDescription: String? {
        switch self {
        case .invalidDocument: "Revise a receita. São permitidas até 64 receitas com destinos válidos."
        case .unavailable: "Não foi possível carregar suas receitas. O arquivo anterior foi preservado."
        case .persistence: "Não foi possível salvar. Suas receitas anteriores foram preservadas."
        }
    }
}
