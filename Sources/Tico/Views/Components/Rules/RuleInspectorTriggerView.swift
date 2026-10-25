import SwiftUI

/// Resumo compacto no inspetor; ajustes técnicos ficam no popover nativo.
/// Gravação reutiliza a mesma sessão e o mesmo serviço de captura do editor anterior.
struct RuleInspectorTriggerView: View {
    @Binding var trigger: TriggerDefinition
    @Binding var advancedTrackpadOptionsAreExpanded: Bool
    let captureMode: TrackpadCaptureMode
    let detectedTrackpads: [TrackpadHardwareInfo]
    let deviceCapabilities: [String: TrackpadDeviceCapability]
    let onRecord: (TriggerRecordingMode) -> Void
    @State private var showsSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Acionamento").font(.headline)
            HStack(spacing: 8) {
                Button { showsSettings = true } label: {
                    Label(RuleEditorSummary.trigger(trigger), systemImage: RuleEditorSummary.symbol(trigger))
                        .lineLimit(2).multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .help("Alterar acionamento")
                .accessibilityIdentifier("tico.rule.edit-trigger")
                Button("Gravar…") { onRecord(.standard) }
                    .accessibilityLabel("Gravar gatilho")
            }
            Menu("Mais opções de gesto") {
                Button("Escolher acionamento…") { showsSettings = true }
                Button("Desenhar meu gesto…") { onRecord(.customTrackpad) }
            }.menuStyle(.borderlessButton).fixedSize()
        }
        .popover(isPresented: $showsSettings) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Acionamento").font(.headline)
                    Spacer()
                    Button("Concluído") { showsSettings = false }
                }
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        RuleTriggerEditorView(trigger: $trigger,
                            advancedTrackpadOptionsAreExpanded: $advancedTrackpadOptionsAreExpanded,
                            captureMode: captureMode, detectedTrackpads: detectedTrackpads,
                            deviceCapabilities: deviceCapabilities)
                    }.padding(2)
                }
            }
            .padding(16).adaptiveSheetFrame(idealWidth: 450, idealHeight: 440)
            .controlSize(.small)
        }
    }
}
