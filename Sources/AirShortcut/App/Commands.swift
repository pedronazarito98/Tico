import SwiftUI

@MainActor
struct AirShortcutCommands: Commands {
    let commandRouter: AppCommandRouter

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Nova regra") {
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

            Button("Visão geral") {
                commandRouter.send(.selectSection(.overview))
            }
            .keyboardShortcut("1", modifiers: [.command])

            Button("Permissões") {
                commandRouter.send(.selectSection(.permissions))
            }
            .keyboardShortcut("2", modifiers: [.command])

            Button("Regras") {
                commandRouter.send(.selectSection(.rules))
            }
            .keyboardShortcut("3", modifiers: [.command])

            Button("Perfis") {
                commandRouter.send(.selectSection(.profiles))
            }
            .keyboardShortcut("4", modifiers: [.command])

            Button("Biblioteca") {
                commandRouter.send(.selectSection(.library))
            }
            .keyboardShortcut("5", modifiers: [.command])

            Button("Laboratório") {
                commandRouter.send(.selectSection(.laboratory))
            }
            .keyboardShortcut("6", modifiers: [.command])

            Button("Métricas") {
                commandRouter.send(.selectSection(.metrics))
            }
            .keyboardShortcut("7", modifiers: [.command])

            Button("Log") {
                commandRouter.send(.selectSection(.log))
            }
            .keyboardShortcut("8", modifiers: [.command])
        }
    }
}
