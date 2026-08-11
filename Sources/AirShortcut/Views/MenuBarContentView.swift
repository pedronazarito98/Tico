import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var controller: AppController
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

        Button(controller.captureIsRunning ? "Pausar captura" : "Iniciar captura") {
            controller.toggleCapture()
        }

        Text("\(shortcutStore.rules.filter(\.isEnabled).count) regras ativas")

        if !shortcutStore.profiles.isEmpty {
            Menu("Perfis") {
                ForEach(shortcutStore.profiles) { profile in
                    Button {
                        try? shortcutStore.setProfileEnabled(!profile.isEnabled, id: profile.id)
                    } label: {
                        Label(
                            shortMenuTitle(profile.name),
                            systemImage: profile.isEnabled ? "checkmark.circle.fill" : "circle"
                        )
                    }
                }
            }
        }

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
