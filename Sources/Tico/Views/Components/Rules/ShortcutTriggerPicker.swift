import SwiftUI

/// O editor completo de gatilhos continua disponível, com confirmação explícita
/// para não considerar um valor padrão como gesto gravado.
struct ShortcutTriggerPicker: View {
    let captureMode: TrackpadCaptureMode
    let detectedTrackpads: [TrackpadHardwareInfo]
    let deviceCapabilities: [String: TrackpadDeviceCapability]
    let onChoose: (TriggerDefinition) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var trigger: TriggerDefinition
    @State private var advanced = false

    init(trigger: TriggerDefinition, captureMode: TrackpadCaptureMode,
         detectedTrackpads: [TrackpadHardwareInfo], deviceCapabilities: [String: TrackpadDeviceCapability],
         onChoose: @escaping (TriggerDefinition) -> Void) {
        _trigger = State(initialValue: trigger)
        self.captureMode = captureMode
        self.detectedTrackpads = detectedTrackpads
        self.deviceCapabilities = deviceCapabilities
        self.onChoose = onChoose
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Escolher acionamento").font(.title3.bold())
            ScrollView {
                RuleTriggerEditorView(trigger: $trigger, advancedTrackpadOptionsAreExpanded: $advanced,
                    captureMode: captureMode, detectedTrackpads: detectedTrackpads, deviceCapabilities: deviceCapabilities)
            }
            Divider()
            HStack {
                Button("Cancelar") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Usar acionamento") { onChoose(trigger); dismiss() }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("tico.composer.use-trigger")
            }
        }.padding(20).adaptiveSheetFrame(idealWidth: 650, idealHeight: 580)
    }
}
