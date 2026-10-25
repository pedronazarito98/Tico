import SwiftUI

struct TriggerSequenceTimeline: View {
    @ObservedObject var capture: TriggerCaptureSession
    @State private var showsTiming = false
    let isRecording: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Na ordem, um depois do outro", systemImage: "list.number").font(.callout.weight(.medium))
                Spacer()
                Button { showsTiming.toggle() } label: {
                    Label("\(capture.sequence.maximumInterval, specifier: "%.2g") s entre etapas", systemImage: "timer")
                }.buttonStyle(.borderless).disabled(isRecording).popover(isPresented: $showsTiming) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Tempo entre etapas").font(.headline)
                        Text("A próxima entrada deve acontecer dentro deste intervalo.").font(.callout).foregroundStyle(.secondary)
                        Slider(value: $capture.sequence.maximumInterval, in: 0.15...5, step: 0.05)
                        Text("\(capture.sequence.maximumInterval, specifier: "%.2f") segundos").monospacedDigit()
                        Picker("Ao compartilhar o início de outro atalho", selection: $capture.sequence.ambiguityPolicy) {
                            Text("Aguardar próximo passo").tag(SequenceAmbiguityPolicy.waitForTimeout)
                            Text("Executar imediatamente").tag(SequenceAmbiguityPolicy.acceptImmediately)
                            Text("Cancelar se divergir").tag(SequenceAmbiguityPolicy.cancelOnMismatch)
                        }
                    }.padding(20).frame(width: 340)
                }
            }
            ForEach(Array(capture.sequence.steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 10) {
                    Text("\(index + 1)").font(.caption.bold()).frame(width: 24, height: 24)
                        .background(TicoBrand.Palette.primary.opacity(0.12), in: .circle)
                    TriggerKeycaps(trigger: step.triggerDefinition)
                    Spacer()
                    Button("Editar etapa \(index + 1)", systemImage: "pencil") { capture.editStep(index) }
                    Button("Mover etapa \(index + 1) para cima", systemImage: "chevron.up") { capture.moveStep(index, by: -1) }.disabled(index == 0)
                    Button("Mover etapa \(index + 1) para baixo", systemImage: "chevron.down") { capture.moveStep(index, by: 1) }.disabled(index == capture.sequence.steps.count - 1)
                    Button("Remover etapa \(index + 1)", systemImage: "trash", role: .destructive) { capture.removeStep(index) }
                }.labelStyle(.iconOnly).buttonStyle(.borderless).disabled(isRecording)
                    .padding(10).background(TicoBrand.Palette.surface, in: .rect(cornerRadius: 10))
                    .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(capture.replacingStep == index ? TicoBrand.Palette.primary : .clear) }
            }
            if capture.sequence.steps.isEmpty {
                Text("Escolha ou grave uma entrada abaixo e adicione a primeira etapa.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}
