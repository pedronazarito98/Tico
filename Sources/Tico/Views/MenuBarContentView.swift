import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var controller: AppController
    @ObservedObject var companion: CompanionCoordinator
    @ObservedObject var shortcutStore: ShortcutStore
    let lifecycle: any ApplicationLifecycleControlling
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Abrir \(TicoBrand.displayName)") {
            lifecycle.activateAndOpenMainWindow {
                openWindow(id: "main")
            }
        }

        Divider()
        Button("Painel de ações ⌃⌥⌘Espaço", action: companion.showActions)
        Button("Fazer com conteúdo…") { controller.contentInteraction.show() }
        Button("Usar texto selecionado…") { controller.contentInteraction.show(useSelection: true) }
        Button("Mapa de gestos", action: companion.showMap)
        if !shortcutStore.reusableWorkflows.isEmpty {
            Menu("Preparar cena") {
                ForEach(shortcutStore.reusableWorkflows) { workflow in
                    Button(workflow.name.isEmpty ? "Cena sem nome" : workflow.name) { companion.runScene(workflow) }
                }
            }
        }
        Divider()
        if controller.captureIsRunning {
            Button("Pausar por 15 minutos", action: controller.pauseCaptureTemporarily)
        }
        if let resumesAt = controller.captureResumesAt {
            Text("Retoma às \(resumesAt.formatted(date: .omitted, time: .shortened))")
        }

        Button(controller.captureIsRunning ? "Pausar captura" : "Iniciar captura") {
            controller.toggleCapture()
        }

        Text("\(shortcutStore.rules.filter(\.isEnabled).count) regras ativas")


        if let event = controller.lastEvent {
            Text(shortMenuTitle("Último: \(event.displayName)"))
        }

        Divider()

        SettingsLink {
            Text("Ajustes…")
        }

        Button("Encerrar \(TicoBrand.displayName)") {
            lifecycle.terminate()
        }
    }

    private func shortMenuTitle(_ title: String) -> String {
        guard title.count > 30 else { return title }
        return String(title.prefix(27)) + "…"
    }
}
