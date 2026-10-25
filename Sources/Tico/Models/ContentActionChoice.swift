import Foundation

/// Projeção de uma receita manual ou regra existente. A entrada pessoal nunca
/// integra o catálogo; a receita transporta apenas configuração para revalidação.
struct ContentActionChoice: Identifiable, Equatable {
    let id: UUID
    let title: String
    var detail: String = ""
    var acceptedKinds: Set<ContentKind> = [.text, .webURL, .files]
    var recipe: ContentRecipe?
    var isEditable = false

    init(id: UUID, title: String, detail: String = "",
         acceptedKinds: Set<ContentKind> = [.text, .webURL, .files],
         recipe: ContentRecipe? = nil, isEditable: Bool = false) {
        self.id = id
        self.title = title
        self.detail = detail
        self.acceptedKinds = acceptedKinds
        self.recipe = recipe
        self.isEditable = isEditable
    }

    init(recipe: ContentRecipe, isEditable: Bool = false) {
        self.id = recipe.id
        self.title = recipe.title
        self.detail = recipe.configuration.destination.deliverySummary
        self.acceptedKinds = ContentRecipeIntent(destination: recipe.configuration.destination) == .shortcut
            ? [.text, .webURL, .files] : [.text, .webURL]
        self.recipe = recipe
        self.isEditable = isEditable
    }
}
