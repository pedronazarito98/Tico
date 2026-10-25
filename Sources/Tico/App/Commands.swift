import SwiftUI

@MainActor
struct TicoCommands: Commands {
    let commandRouter: AppCommandRouter

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Novo atalho") {
                commandRouter.send(.createRule)
            }
            .keyboardShortcut("n", modifiers: [.command])
        }

        CommandGroup(after: .importExport) {
            Button("Importar regras…") {
                commandRouter.send(.importRules)
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            Button("Exportar regras…") {
                commandRouter.send(.exportRules)
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])
        }

        CommandMenu("Atalhos") {
            Button("Painel de ações") { commandRouter.send(.showContextualActions) }
                .keyboardShortcut(.space, modifiers: [.command, .option, .control])
            Button("Fazer com conteúdo…") { commandRouter.send(.showContentActions) }
            Button("Usar texto selecionado…") { commandRouter.send(.useSelectedContent) }
            Button("Mapa de gestos") { commandRouter.send(.showGestureMap) }
                .keyboardShortcut("m", modifiers: [.command, .option])
            Button("Descrever automação…") { commandRouter.send(.describeAutomation) }
            Divider()

            Button("Iniciar captura") {
                commandRouter.send(.startCapture)
            }
            .keyboardShortcut("r", modifiers: [.command, .option])

            Button("Parar captura") {
                commandRouter.send(.stopCapture)
            }
            .keyboardShortcut(".", modifiers: [.command, .option])

            Divider()

            Button("Excluir regra selecionada") {
                commandRouter.send(.deleteSelectedRule)
            }
            .keyboardShortcut(.delete, modifiers: [.command])

            Divider()

            Button("Atividade") {
                commandRouter.send(.selectSection(.activity))
            }
            .keyboardShortcut("1", modifiers: [.command])

            Button("Permissões") {
                commandRouter.send(.selectSection(.permissions))
            }
            .keyboardShortcut("2", modifiers: [.command])

            Button("Meus atalhos") {
                commandRouter.send(.selectSection(.rules))
            }
            .keyboardShortcut("3", modifiers: [.command])

            Button("Modelos e gestos") {
                commandRouter.send(.selectSection(.library))
            }
            .keyboardShortcut("5", modifiers: [.command])

            Button("Laboratório") {
                commandRouter.send(.selectSection(.laboratory))
            }
            .keyboardShortcut("6", modifiers: [.command])

            Button("Log") {
                commandRouter.send(.selectSection(.log))
            }
            .keyboardShortcut("8", modifiers: [.command])
        }
    }
}
