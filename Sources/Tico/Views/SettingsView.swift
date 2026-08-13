import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettingsStore
    @State private var loginItemError: String?

    var body: some View {
        TabView {
            Tab("Geral", systemImage: "gearshape") {
                generalSettings
            }

            Tab("Segurança", systemImage: "lock.shield") {
                securitySettings
            }
        }
        .frame(width: 520, height: 310)
        .scenePadding()
    }

    private var generalSettings: some View {
        Form {
            Section("Inicialização") {
                Toggle("Abrir \(TicoBrand.displayName) ao iniciar sessão", isOn: launchAtLoginBinding)
                Toggle("Iniciar captura de eventos ao abrir", isOn: $settings.startEventCaptureOnLaunch)
            }

            Section("Acesso rápido") {
                Toggle("Mostrar \(TicoBrand.displayName) na barra de menus", isOn: $settings.showMenuBarExtra)
            }

            if let loginItemError {
                Text(loginItemError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
    }

    private var securitySettings: some View {
        Form {
            Section("Scripts locais") {
                Label("Confirmação obrigatória em toda execução", systemImage: "checkmark.shield")
                Text("Scripts podem modificar arquivos e executar outros programas com sua conta. O \(TicoBrand.displayName) sempre mostra o comando antes de executá-lo.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { settings.launchAtLogin },
            set: { shouldLaunch in
                do {
                    if shouldLaunch {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                    settings.launchAtLogin = shouldLaunch
                    loginItemError = nil
                } catch {
                    settings.launchAtLogin = SMAppService.mainApp.status == .enabled
                    loginItemError = "Não foi possível atualizar o início de sessão: \(error.localizedDescription)"
                }
            }
        )
    }
}
