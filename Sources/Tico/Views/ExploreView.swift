import SwiftUI

/// Catálogo de resultados com filtros explícitos. Personalizar entrega um
/// rascunho ao shell; a descoberta não persiste nem executa a receita.
struct ExploreView: View {
    let applications: [ApplicationChoice]
    let onChoose: (ShortcutRule) -> Void
    let onPractice: (ShortcutRule) -> Void
    let onDescribe: () -> Void
    let onOpenLibrary: () -> Void
    var searchText = ""
    @State private var category: RecipeCategory?

    private var recipes: [AutomationRecipe] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return AutomationRecipeCatalog.recipes.filter { recipe in
            (category == nil || recipe.category == category)
                && (query.isEmpty || [recipe.name, recipe.summary, recipe.category.rawValue,
                                     recipe.trigger.displayName, recipe.applicationName ?? ""]
                    .contains { $0.localizedStandardContains(query) })
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("O que você quer facilitar?").font(.title2.weight(.semibold))
                        Text("Escolha uma ideia e personalize o resultado e o acionamento.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Menu("Outras formas de começar") {
                        Button("Montar uma frase", systemImage: "text.bubble", action: onDescribe)
                        Button("Modelos salvos", systemImage: "square.stack.3d.up", action: onOpenLibrary)
                    }.fixedSize()
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        categoryButton(nil, title: "Todas as ideias")
                        ForEach(RecipeCategory.allCases) { category in
                            categoryButton(category, title: categoryTitle(category))
                        }
                    }.padding(.vertical, 2)
                }
                if recipes.isEmpty {
                    ContentUnavailableView("Nenhuma ideia encontrada", systemImage: "magnifyingglass",
                        description: Text("Tente outra busca ou escolha uma categoria diferente."))
                        .frame(maxWidth: .infinity, minHeight: 250)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), alignment: .top)], spacing: 14) {
                        ForEach(recipes) { recipe in
                            RecipeCardView(recipe: recipe, applications: applications,
                                onChoose: onChoose, onPractice: onPractice)
                        }
                    }
                }
                Label("Personalizar abre o editor. Você confere tudo antes de criar o atalho.",
                      systemImage: "checkmark.shield")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(24)
        }.navigationTitle("Explorar")
    }

    private func categoryButton(_ value: RecipeCategory?, title: String) -> some View {
        Button { category = value } label: {
            HStack(spacing: 5) {
                if category == value { Image(systemName: "checkmark").font(.caption) }
                Text(title)
            }
        }
        .buttonStyle(.bordered)
        .tint(category == value ? TicoBrand.Palette.primary : .secondary)
        .accessibilityLabel(value?.rawValue ?? title)
        .accessibilityAddTraits(category == value ? .isSelected : [])
    }

    private func categoryTitle(_ category: RecipeCategory) -> String {
        switch category {
        case .windows: "Janelas"
        case .browsing: "Navegação"
        case .development: "Programação"
        case .comfort: "Conforto"
        }
    }
}

/// O cartão representa o resultado; demonstrações animadas pertencem ao ensaio
/// escolhido pelo usuário, não a todos os itens visíveis ao mesmo tempo.
private struct RecipeCardView: View {
    let recipe: AutomationRecipe
    let applications: [ApplicationChoice]
    let onChoose: (ShortcutRule) -> Void
    let onPractice: (ShortcutRule) -> Void

    private var missingApplication: String? {
        guard let id = recipe.applicationID, let name = recipe.applicationName,
              !applications.contains(where: { $0.bundleIdentifier == id }) else { return nil }
        return name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: recipe.symbol).font(.title2)
                    .foregroundStyle(TicoBrand.Palette.primary).frame(width: 30)
                Text(recipe.name).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                Menu {
                    Button("Experimentar sem executar") { onPractice(recipe.makeRule()) }
                } label: { Image(systemName: "ellipsis") }
                    .menuStyle(.borderlessButton).fixedSize()
                    .accessibilityLabel("Opções de \(recipe.name)")
            }
            Text(recipe.summary).font(.callout).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Label(recipe.trigger.displayName, systemImage: RuleEditorSummary.symbol(recipe.trigger))
                .font(.caption).foregroundStyle(.secondary)
            if let missingApplication {
                Label("Requer \(missingApplication). Você pode trocar o app no editor.", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
            } else if let applicationName = recipe.applicationName {
                Text(applicationName).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            HStack {
                Spacer()
                Button("Personalizar", systemImage: "arrow.right") { onChoose(recipe.makeRule()) }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("tico.recipe.\(recipe.id)")
                    .accessibilityHint("Abre um rascunho para revisar antes de salvar")
            }
        }
        .padding(18).frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .background(TicoBrand.Palette.surface.opacity(0.7), in: .rect(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.07)) }
    }
}
