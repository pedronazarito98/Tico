import SwiftUI

struct ExploreView: View {
    let applications: [ApplicationChoice]
    let onChoose: (ShortcutRule) -> Void
    let onPractice: (ShortcutRule) -> Void
    let onDescribe: () -> Void
    let onOpenLibrary: () -> Void
    @State private var category: RecipeCategory = .windows

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("O que você quer facilitar?").font(.largeTitle.bold())
                Text("Escolha uma receita, experimente o movimento e ajuste ao seu jeito.")
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Descrever uma automação", systemImage: "text.bubble", action: onDescribe)
                    Button("Minha biblioteca", systemImage: "books.vertical", action: onOpenLibrary)
                }
                Picker("Objetivo", selection: $category) {
                    ForEach(RecipeCategory.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.menu)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), alignment: .top)], spacing: 18) {
                    ForEach(AutomationRecipeCatalog.recipes.filter { $0.category == category }) { recipe in
                        RecipeCardView(recipe: recipe, applications: applications,
                                       onChoose: onChoose, onPractice: onPractice)
                    }
                }
                Label("As receitas são salvas desativadas. Revise o gatilho e os conflitos antes de ativar.",
                      systemImage: "checkmark.shield")
                    .font(.callout).foregroundStyle(.secondary)
            }.padding(28)
        }.navigationTitle("Explorar")
    }
}

private struct RecipeCardView: View {
    let recipe: AutomationRecipe
    let applications: [ApplicationChoice]
    let onChoose: (ShortcutRule) -> Void
    let onPractice: (ShortcutRule) -> Void

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                GestureIllustrationView(trigger: recipe.trigger)
                    .frame(maxWidth: .infinity)
                Label(recipe.name, systemImage: recipe.symbol).font(.headline)
                Text(recipe.summary).foregroundStyle(.secondary)
                Text(recipe.trigger.displayName).font(.callout)
                if let appName = recipe.applicationName {
                    Label(appName, systemImage: "app")
                    if !applications.contains(where: { $0.bundleIdentifier == recipe.applicationID }) {
                        Text("Este aplicativo precisa estar instalado para executar a receita.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                HStack {
                    Button("Experimentar") { onPractice(recipe.makeRule()) }
                    Spacer()
                    Button("Usar receita") { onChoose(recipe.makeRule()) }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("tico.recipe.\(recipe.id)")
                }
            }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
