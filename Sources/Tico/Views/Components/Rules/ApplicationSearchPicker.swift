import SwiftUI

/// App atual e alternativas ficam visíveis juntos. Paralelo com React: componente
/// controlado; clicar atualiza o Binding, sem copiar a seleção para outro estado.
struct ApplicationSearchPicker: View {
    @Binding var selection: String
    let applications: [ApplicationChoice]

    private var selectedApplication: ApplicationChoice? {
        applications.first { $0.id == selection }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !selection.isEmpty {
                HStack(spacing: 10) {
                    ApplicationIconView(application: selectedApplication, size: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(RuleEditorSummary.appName(selection, applications: applications))
                            .font(.body.weight(.semibold)).lineLimit(2)
                        Text(selectedApplication == nil ? "App não encontrado neste Mac" : "Aplicativo selecionado")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
            ApplicationBrowserView(applications: applications, selectedIDs: [selection]) {
                selection = $0
            }
        }
    }
}
