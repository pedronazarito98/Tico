import SwiftUI

struct PermissionPresentation: Identifiable {
    let id: String
    let title: String
    let explanation: String
    let systemImage: String
    let isGranted: Bool
    let statusText: String
    let requestTitle: String
    let request: () -> Void
    let settingsTitle: String?
    let openSettings: (() -> Void)?
}

struct PermissionsView: View {
    let permissions: [PermissionPresentation]
    let onRefresh: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Permissões do sistema")
                        .font(.title2.weight(.semibold))
                    Text("O \(TicoBrand.displayName) solicita apenas o necessário para reconhecer e executar suas regras.")
                        .foregroundStyle(.secondary)
                }

                ForEach(permissions) { permission in
                    PermissionCard(permission: permission)
                }

                HStack {
                    Button("Atualizar estados", action: onRefresh)
                    Text("Depois de conceder uma permissão, atualize. Se a captura ainda não iniciar, encerre e reabra o \(TicoBrand.displayName).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .navigationTitle("Permissões")
    }
}

private struct PermissionCard: View {
    let permission: PermissionPresentation

    var body: some View {
        GroupBox {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: permission.systemImage)
                    .font(.title2)
                    .foregroundStyle(permission.isGranted ? .green : .orange)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(permission.title)
                            .font(.headline)
                        Text(permission.statusText)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                permission.isGranted ? Color.green.opacity(0.14) : Color.orange.opacity(0.14),
                                in: Capsule()
                            )
                    }
                    Text(permission.explanation)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if permission.id == "input-monitoring", permission.statusText == "Negada" {
                        Text("Se o \(TicoBrand.displayName) não estiver na lista, clique em + nos Ajustes e selecione o app mostrado no Finder.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if !permission.isGranted {
                    VStack(alignment: .trailing, spacing: 8) {
                        Button(permission.requestTitle, action: permission.request)
                            .buttonStyle(.borderedProminent)
                        if let settingsTitle = permission.settingsTitle,
                           let openSettings = permission.openSettings {
                            Button(settingsTitle, action: openSettings)
                                .buttonStyle(.link)
                        }
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }
}
