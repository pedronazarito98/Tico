import SwiftUI

/// Busca e escolha acontecem no próprio contexto, sem um segundo seletor.
/// Apps em execução vêm primeiro; digitar pesquisa todo o catálogo instalado.
struct ApplicationBrowserView: View {
    let applications: [ApplicationChoice]
    var selectedIDs: Set<String> = []
    let onSelect: (String) -> Void
    @State private var search = ""
    @State private var showsAll = false

    private var filtered: [ApplicationChoice] {
        applications.filter { search.isEmpty || $0.name.localizedStandardContains(search) }
            .sorted {
                if $0.isRunning != $1.isRunning { return $0.isRunning }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Buscar aplicativo…", text: $search)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("tico.application.search")
            if filtered.isEmpty {
                Text("Nenhum aplicativo encontrado. Tente outro nome.")
                    .font(.caption).foregroundStyle(.secondary).padding(.vertical, 8)
            } else {
                ApplicationChoiceGrid(applications: Array(filtered.prefix(showsAll ? filtered.count : 6)),
                                      selectedIDs: selectedIDs, onSelect: onSelect)
                if filtered.count > 6 {
                    Button(showsAll ? "Mostrar menos" : "Ver todos os \(filtered.count) aplicativos") {
                        showsAll.toggle()
                    }.buttonStyle(.borderless).font(.caption)
                }
            }
        }
        .onChange(of: search) { showsAll = false }
    }
}
