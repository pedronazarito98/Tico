import SwiftUI

/// A superfície de captura mostra um único próximo passo. Toda gravação continua
/// explícita e pertence ao controller; trocar a apresentação não inicia monitores.
struct TriggerRecordingSurface: View {
    @ObservedObject var capture: TriggerCaptureSession
    let snapshot: TrackpadLaboratorySnapshot?
    let isRecording: Bool
    let canCaptureGlobalInput: Bool
    let onRecord: () -> Void
    let onStop: () -> Void
    let onOpenPermissions: () -> Void

    private var instruction: String {
        switch capture.device {
        case .keyboard: "Pressione a combinação que você quer usar."
        case .mouse: "Pressione um botão extra do mouse."
        case .trackpad:
            capture.mode == .combination ? "Segure uma tecla modificadora e faça o gesto." : "Faça o gesto no seu trackpad."
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            if capture.requiresTrackpad {
                TrackpadCaptureVisual(spec: capture.trackpad, snapshot: snapshot, isRecording: isRecording,
                                      showsSelection: capture.hasChosenInput)
            } else {
                Image(systemName: capture.device.symbol)
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(TicoBrand.Palette.primary)
                    .accessibilityHidden(true)
                if capture.hasChosenInput, let input = capture.input {
                    TriggerKeycaps(trigger: input)
                } else {
                    Text("Sua entrada aparecerá aqui").foregroundStyle(.secondary)
                }
            }
            if isRecording {
                Text(instruction).font(.headline)
                Text("Esc encerra a gravação. As automações do Tico estão suspensas.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if capture.hasRecordedInput {
                Label("Entrada reconhecida. Confira e use quando estiver pronto.", systemImage: "checkmark.circle")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                Text("Clique em Gravar para começar.").font(.callout).foregroundStyle(.secondary)
            }
            if capture.requiresTrackpad && !canCaptureGlobalInput {
                VStack(spacing: 10) {
                    Text("Autorize o trackpad para gravar. Você também pode escolher um gesto na lista.")
                        .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Abrir Ajustes", action: onOpenPermissions).buttonStyle(.bordered)
                }
            } else {
                Button(isRecording ? "Concluir gravação" : "Gravar acionamento",
                       systemImage: isRecording ? "stop.circle" : "record.circle") {
                    isRecording ? onStop() : onRecord()
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .accessibilityIdentifier("tico.composer.record")
            }
        }
        .padding(.vertical, 18).frame(maxWidth: .infinity)
    }
}
