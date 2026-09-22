import Foundation

enum RecipeCategory: String, CaseIterable, Identifiable {
    case windows = "Organizar meu espaço"
    case browsing = "Navegar com menos esforço"
    case development = "Programar"
    case comfort = "Movimentos confortáveis"
    var id: String { rawValue }
}

/// Conteúdo curado e local. A instalação sempre cria uma cópia desativada para revisão.
struct AutomationRecipe: Identifiable {
    let id: String
    let name: String
    let summary: String
    let category: RecipeCategory
    let symbol: String
    let trigger: TriggerDefinition
    let action: ShortcutAction
    var applicationID: String? = nil
    var applicationName: String? = nil

    func makeRule() -> ShortcutRule {
        ShortcutRule(
            name: name, isEnabled: false, trigger: trigger, action: action,
            scope: applicationID.map { .applications(bundleIdentifiers: [$0]) } ?? .global,
            notes: summary
        )
    }
}

enum AutomationRecipeCatalog {
    static let recipes: [AutomationRecipe] = [
        AutomationRecipe(id: "window-left", name: "Janela à esquerda",
            summary: "Reserve metade da tela para a janela atual.", category: .windows,
            symbol: "rectangle.lefthalf.inset.filled", trigger: .trackpad(gesture: .swipeLeft),
            action: .window(target: .frontmost, operation: .leftHalf)),
        AutomationRecipe(id: "window-right", name: "Janela à direita",
            summary: "Coloque duas janelas lado a lado.", category: .windows,
            symbol: "rectangle.righthalf.inset.filled", trigger: .trackpad(gesture: .swipeRight),
            action: .window(target: .frontmost, operation: .rightHalf)),
        AutomationRecipe(id: "window-maximize", name: "Mais espaço para trabalhar",
            summary: "Amplie a janela atual para a área útil da tela.", category: .windows,
            symbol: "arrow.up.left.and.arrow.down.right", trigger: .trackpad(gesture: .swipeUp),
            action: .window(target: .frontmost, operation: .maximize)),
        AutomationRecipe(id: "safari-reopen", name: "Recuperar a última aba",
            summary: "Reabra uma aba fechada no Safari.", category: .browsing,
            symbol: "arrow.uturn.backward", trigger: .trackpad(gesture: .tap, fingerCount: 4),
            action: .keyboardShortcut(keyCode: 17, modifiers: [.command, .shift]),
            applicationID: "com.apple.Safari", applicationName: "Safari"),
        AutomationRecipe(id: "safari-next", name: "Próxima aba",
            summary: "Avance entre as abas do Safari.", category: .browsing,
            symbol: "arrow.right.square", trigger: .trackpad(gesture: .swipeRight, fingerCount: 4),
            action: .keyboardShortcut(keyCode: 48, modifiers: [.control]),
            applicationID: "com.apple.Safari", applicationName: "Safari"),
        AutomationRecipe(id: "terminal", name: "Terminal à mão",
            summary: "Abra o Terminal com um movimento curto.", category: .development,
            symbol: "terminal", trigger: .trackpad(gesture: .tap, fingerCount: 4),
            action: .openApplication(bundleIdentifier: "com.apple.Terminal")),
        AutomationRecipe(id: "finder", name: "Arquivos à mão",
            summary: "Use o teclado quando preferir descansar a mão do trackpad.", category: .comfort,
            symbol: "folder", trigger: .keyboard(keyCode: 3, modifiers: [.control, .option]),
            action: .openApplication(bundleIdentifier: "com.apple.finder"))
    ]
}
