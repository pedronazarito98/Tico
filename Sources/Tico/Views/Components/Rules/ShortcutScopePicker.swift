import SwiftUI

/// Seleção transacional: fechar o popover descarta escolhas; Aplicar altera o Binding.
struct ShortcutScopePicker: View {
    @Binding var scope: RuleScope
    let applications: [ApplicationChoice]
    @Environment(\.dismiss) private var dismiss
    @State private var draft: RuleScope
    @State private var search = ""

    init(scope: Binding<RuleScope>, applications: [ApplicationChoice]) {
        _scope = scope
        self.applications = applications
        _draft = State(initialValue: scope.wrappedValue)
    }

    private var specific: Binding<Bool> {
        Binding(get: { if case .applications = draft { return true }; return false },
                set: { draft = $0 ? .applications(bundleIdentifiers: scope.bundleIdentifiers) : .global })
    }
    private var canApply: Bool { !specific.wrappedValue || !draft.bundleIdentifiers.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Onde este atalho funciona").font(.headline)
            Picker("Disponível em", selection: specific) {
                Text("Todos os apps").tag(false)
                Text("Escolher apps").tag(true)
            }.pickerStyle(.segmented)
            if specific.wrappedValue {
                Text("Selecione um ou mais aplicativos.").font(.callout).foregroundStyle(.secondary)
                TextField("Buscar aplicativos", text: $search).textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("tico.composer.scope-search")
                ScrollView {
                    ApplicationChoiceGrid(applications: applications.filter {
                        search.isEmpty || $0.name.localizedStandardContains(search)
                    }, selectedIDs: draft.bundleIdentifiers, onSelect: toggle)
                }.frame(height: 230)
                if !draft.bundleIdentifiers.isEmpty {
                    Divider()
                    Text(draft.bundleIdentifiers.sorted().map { RuleEditorSummary.appName($0, applications: applications) }.joined(separator: ", "))
                        .font(.callout).lineLimit(3)
                }
            } else {
                Label("Funciona em qualquer aplicativo.", systemImage: "globe")
                    .foregroundStyle(.secondary).padding(.vertical, 16)
            }
            Divider()
            HStack {
                Text(specific.wrappedValue ? "\(draft.bundleIdentifiers.count) apps selecionados" : "Todos os apps")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Aplicar") { scope = draft; dismiss() }
                    .buttonStyle(.borderedProminent).disabled(!canApply)
                    .keyboardShortcut(.defaultAction).accessibilityIdentifier("tico.composer.apply-scope")
            }
        }.padding(18).frame(width: 380)
    }

    private func toggle(_ id: String) {
        var ids = draft.bundleIdentifiers
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        draft = .applications(bundleIdentifiers: ids)
    }
}
