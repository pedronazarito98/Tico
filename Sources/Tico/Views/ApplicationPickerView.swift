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

struct ApplicationTargetPicker: View {
    @Binding var target: ApplicationTarget
    let applications: [ApplicationChoice]
    var allowsFrontmost = true

    var body: some View {
        Picker("Aplicativo", selection: selection) {
            if allowsFrontmost {
                Text("App em primeiro plano").tag(Self.frontmostTag)
                Divider()
            }
            ForEach(applications) { application in
                Text(application.name).tag(application.bundleIdentifier)
            }
        }
    }

    private static let frontmostTag = "__frontmost__"

    private var selection: Binding<String> {
        Binding(
            get: {
                switch target {
                case .frontmost:
                    Self.frontmostTag
                case let .bundleIdentifier(identifier):
                    identifier
                }
            },
            set: { value in
                target = value == Self.frontmostTag
                    ? .frontmost
                    : .bundleIdentifier(value)
            }
        )
    }
}
