import SwiftUI

/// Escopo com escolha visual inline. O conjunto de bundle IDs continua sendo a
/// fonte de verdade do matcher; busca e expansão são apenas estado de apresentação.
struct RuleScopeComposerView: View {
    @Binding var scope: RuleScope
    let applications: [ApplicationChoice]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Disponível em", selection: applicationSpecific) {
                Text("Todos os apps").tag(false)
                Text("Escolher apps").tag(true)
            }.pickerStyle(.segmented).labelsHidden()

            if !isGlobal {
                ForEach(scope.bundleIdentifiers.sorted(), id: \.self) { id in
                    HStack(spacing: 8) {
                        ApplicationIconView(application: applications.first { $0.id == id }, size: 24)
                        Text(RuleEditorSummary.appName(id, applications: applications)).lineLimit(1)
                        Spacer()
                        Button("Remover aplicativo", systemImage: "xmark.circle.fill") { toggle(id) }
                            .labelStyle(.iconOnly).buttonStyle(.borderless)
                            .accessibilityLabel("Remover \(RuleEditorSummary.appName(id, applications: applications))")
                    }
                }
                ApplicationBrowserView(applications: applications, selectedIDs: scope.bundleIdentifiers,
                                       onSelect: toggle)
                Text(scope.bundleIdentifiers.isEmpty
                     ? "Escolha os apps em que este atalho vai funcionar."
                     : "Funciona quando um destes apps estiver em primeiro plano.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var isGlobal: Bool { if case .global = scope { return true }; return false }
    private var applicationSpecific: Binding<Bool> {
        Binding(get: { !isGlobal }, set: {
            scope = $0 ? .applications(bundleIdentifiers: []) : .global
        })
    }
    private func toggle(_ id: String) {
        var ids = scope.bundleIdentifiers
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        scope = .applications(bundleIdentifiers: ids)
    }
}
