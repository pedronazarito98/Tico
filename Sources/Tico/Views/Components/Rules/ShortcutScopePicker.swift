import SwiftUI

/// O popover edita o rascunho do formulário imediatamente. Fechar com Esc ou
/// clicar fora conserva a seleção; a persistência acontece apenas ao salvar o atalho.
struct ShortcutScopePicker: View {
    @Binding var scope: RuleScope
    let applications: [ApplicationChoice]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedIDs: Set<String>
    @State private var search = ""

    init(scope: Binding<RuleScope>, applications: [ApplicationChoice]) {
        _scope = scope
        self.applications = applications
        _selectedIDs = State(initialValue: scope.wrappedValue.bundleIdentifiers)
    }
    private var specific: Binding<Bool> {
        Binding(get: { if case .applications = scope { return true }; return false },
                set: { scope = $0 ? .applications(bundleIdentifiers: selectedIDs) : .global })
    }
    private var filteredApps: [ApplicationChoice] {
        applications.filter { search.isEmpty || $0.name.localizedStandardContains(search) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Onde este atalho funciona").font(.headline)
            Picker("Disponível em", selection: specific) {
                Text("Todos os apps").tag(false); Text("Escolher apps").tag(true)
            }.pickerStyle(.segmented)
            if specific.wrappedValue {
                TextField("Buscar aplicativos", text: $search).textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("tico.composer.scope-search")
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(filteredApps) { app in
                            Toggle(isOn: selection(app.id)) {
                                HStack {
                                    ApplicationIconView(application: app, size: 24)
                                    Text(app.name); Spacer()
                                }
                            }.toggleStyle(.checkbox)
                        }
                        ForEach(selectedIDs.filter { id in !applications.contains { $0.id == id } }.sorted(), id: \.self) { id in
                            Toggle(id, isOn: selection(id)).toggleStyle(.checkbox)
                        }
                        if filteredApps.isEmpty { Text("Nenhum aplicativo encontrado.").foregroundStyle(.secondary) }
                    }.padding(4)
                }.frame(height: 230)
                if selectedIDs.isEmpty {
                    Label("Selecione pelo menos um aplicativo.", systemImage: "info.circle").font(.caption).foregroundStyle(.orange)
                }
            } else {
                Label("Funciona em qualquer aplicativo.", systemImage: "globe").foregroundStyle(.secondary).padding(.vertical, 16)
            }
            Divider()
            HStack {
                Text(specific.wrappedValue ? "\(selectedIDs.count) apps selecionados" : "Todos os apps")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Concluir") { dismiss() }.buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction).accessibilityIdentifier("tico.composer.apply-scope")
            }
        }.padding(18).frame(width: 380)
    }
    private func selection(_ id: String) -> Binding<Bool> {
        Binding(get: { selectedIDs.contains(id) }, set: {
            if $0 { selectedIDs.insert(id) } else { selectedIDs.remove(id) }
            scope = .applications(bundleIdentifiers: selectedIDs)
        })
    }
}
