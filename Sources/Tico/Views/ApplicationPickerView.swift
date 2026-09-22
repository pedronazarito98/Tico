import SwiftUI

struct RuleScopePicker: View {
    @Binding var scope: RuleScope
    let applications: [ApplicationChoice]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Aplicar quando", selection: isApplicationSpecific) {
                Text("Qualquer app estiver ativo").tag(false)
                Text("Um app específico estiver ativo").tag(true)
            }
            if isApplicationSpecific.wrappedValue {
                Picker("Aplicativo", selection: selectedBundleIdentifier) {
                    ForEach(applications) { application in
                        HStack {
                            Text(application.name)
                            if application.isRunning {
                                Text("Em execução")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(application.bundleIdentifier)
                    }
                }
                Text("A regra só participa da disputa enquanto este app estiver em primeiro plano.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var isApplicationSpecific: Binding<Bool> {
        Binding(
            get: {
                if case .applications = scope { return true }
                return false
            },
            set: { enabled in
                if enabled {
                    let identifier = applications.first?.bundleIdentifier ?? ""
                    scope = .applications(bundleIdentifiers: [identifier])
                } else {
                    scope = .global
                }
            }
        )
    }

    private var selectedBundleIdentifier: Binding<String> {
        Binding(
            get: { scope.bundleIdentifiers.first ?? applications.first?.bundleIdentifier ?? "" },
            set: { scope = .applications(bundleIdentifiers: [$0]) }
        )
    }
}

/// Define o alvo sem misturar o app atual com uma lista de aplicativos instalados.
/// Uma seleção específica vazia permanece inválida até o usuário escolher um app.
struct ApplicationTargetPicker: View {
    @Binding var target: ApplicationTarget
    let applications: [ApplicationChoice]
    var allowsFrontmost = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if allowsFrontmost {
                Picker("Aplicar a", selection: usesSpecificApplication) {
                    Text("App em uso").tag(false)
                    Text("Escolher app").tag(true)
                }.pickerStyle(.segmented)
            }
            if usesSpecificApplication.wrappedValue || !allowsFrontmost {
                ApplicationSearchPicker(selection: selectedIdentifier, applications: applications)
            } else {
                Label("Usa o aplicativo que estiver em primeiro plano.", systemImage: "macwindow")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var usesSpecificApplication: Binding<Bool> {
        Binding(get: {
            if case .bundleIdentifier = target { return true }
            return false
        }, set: { target = $0 ? .bundleIdentifier("") : .frontmost })
    }

    private var selectedIdentifier: Binding<String> {
        Binding(get: {
            if case let .bundleIdentifier(id) = target { return id }
            return ""
        }, set: { target = .bundleIdentifier($0) })
    }
}
