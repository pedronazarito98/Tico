import SwiftUI

/// O resultado orienta a edição; detalhes do motor aparecem somente quando
/// mudam o comportamento. Mantém o contrato de configuração das regras existentes.
struct ContentActionEditorView: View {
    @Binding var configuration: ContentActionConfiguration
    let macOSShortcuts: [String]
    var showsSelectionTiming = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ContentDestinationEditorView(destination: $configuration.destination, macOSShortcuts: macOSShortcuts)
            VStack(alignment: .leading, spacing: 8) {
                Text("Com qual conteúdo?").font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 8)], spacing: 8) {
                    ForEach(ContentInputSource.allCases, id: \.self) { source in
                        EditorChoiceButton(title: source.title,
                            symbol: source == .provided ? "text.alignleft" : "text.cursor",
                            isSelected: configuration.source == source) { configuration.source = source }
                    }
                }.accessibilityLabel("Origem do conteúdo")
                Text(configuration.source == .selection
                     ? "O Tico lê a seleção somente quando você executa a ação."
                     : "Você fornece o conteúdo no painel, antes de executar.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if configuration.source == .selection,
               showsSelectionTiming || configuration.selectionTiming != .workflowStart {
                DisclosureGroup("Momento da seleção") {
                    Picker("Ler a seleção", selection: $configuration.selectionTiming) {
                        ForEach(ContentSelectionTiming.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.pickerStyle(.radioGroup).padding(.top, 8)
                    Text("No início, o texto é preservado mesmo se outra ação trocar de aplicativo. Ao executar esta ação, vale a seleção disponível naquele momento.")
                        .font(.caption).foregroundStyle(.secondary)
                }.font(.callout)
            }
        }
    }
}
