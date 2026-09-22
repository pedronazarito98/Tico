import SwiftUI

/// Grade compartilhada por ações e escopo. O clique entrega o bundle ID ao owner;
/// seleção simples ou múltipla é responsabilidade do Binding de cada consumidor.
struct ApplicationChoiceGrid: View {
    let applications: [ApplicationChoice]
    var selectedIDs: Set<String> = []
    var opensApplication = false
    let onSelect: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 6)], spacing: 6) {
            ForEach(applications) { application in
                let selected = selectedIDs.contains(application.id)
                Button { onSelect(application.id) } label: {
                    VStack(spacing: 5) {
                        ApplicationIconView(application: application, size: 36)
                        Text(application.name).font(.caption).lineLimit(2)
                            .multilineTextAlignment(.center).frame(height: 28, alignment: .top)
                    }
                    .padding(8).frame(maxWidth: .infinity)
                    .background(selected ? TicoBrand.Palette.primary.opacity(0.12) : .clear,
                                in: .rect(cornerRadius: 9))
                    .overlay(alignment: .topTrailing) {
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(TicoBrand.Palette.primary).padding(4)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(opensApplication ? "Abrir \(application.name)" : application.name)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
                .help(application.isRunning ? "\(application.name) · em execução" : application.name)
            }
        }
    }
}
