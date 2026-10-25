import SwiftUI

/// Uma apresentação estável abriga entrada e edição. A mudança de etapa não
/// fecha o NSPanel nem reinicia o prazo do conteúdo pessoal. O presenter oferece
/// o tamanho; a view rola o conteúdo e mantém os comandos de saída visíveis.
/// Paralelo com React: o painel é um container flexível com footer fora do overflow.
struct ContentInteractionPanelView: View {
    @ObservedObject var coordinator: ContentInteractionCoordinator

    var body: some View {
        VStack(spacing: 0) {
            if let draft = coordinator.recipeDraft {
                ContentRecipeEditorView(recipe: draft, macOSShortcuts: coordinator.availableMacOSShortcuts,
                    onSave: coordinator.saveRecipe, onCancel: coordinator.cancelRecipeEditing)
                    .id(draft.id)
            } else {
                ScrollView {
                    ContentActionPanelView(session: coordinator.session, actions: coordinator.choices,
                        canManageRecipes: coordinator.canManageRecipes,
                        onCreateRecipe: coordinator.createRecipe,
                        onEditRecipe: coordinator.editRecipe,
                        onDeleteRecipe: coordinator.removeRecipe)
                    if let issue = coordinator.executionIssue ?? coordinator.recipeError {
                        Label(issue, systemImage: "exclamationmark.circle")
                            .font(.callout).foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24).padding(.bottom, 16)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("tico.content.execution-issue")
                    }
                }
                Divider()
                ContentPanelFooterView(session: coordinator.session,
                    canManageRecipes: coordinator.canManageRecipes,
                    onCreateRecipe: coordinator.createAction, onClose: coordinator.close)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityIdentifier("tico.content.panel")
    }
}
