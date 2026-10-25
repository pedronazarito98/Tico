import SwiftUI

/// Treino explícito de três trajetórias. As amostras permanecem na sessão do
/// criador; um desenho de demonstração nunca é usado como entrada reconhecida.
struct CustomGestureCaptureView: View {
    @ObservedObject var capture: TriggerCaptureSession
    let snapshot: TrackpadLaboratorySnapshot?
    let isRecording: Bool
    let canCaptureGlobalInput: Bool
    let onRecord: () -> Void
    let onStop: () -> Void
    let onOpenPermissions: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Desenhe o mesmo gesto três vezes").font(.headline)
            Text("Use a mesma quantidade de dedos em cada gravação.")
                .font(.callout).foregroundStyle(.secondary)
            TrackpadCaptureVisual(spec: capture.trackpad, snapshot: snapshot, isRecording: isRecording,
                customPath: capture.samples.last?.trackpadPath ?? capture.existingTemplate?.representativePath ?? [],
                isCustom: true)
            HStack(spacing: 12) {
                ForEach(0..<3) { index in
                    sample(index)
                }
            }
            if !canCaptureGlobalInput {
                Button("Autorizar trackpad nos Ajustes", action: onOpenPermissions)
            } else {
                Button(isRecording ? "Concluir gravação" : "Gravar gesto",
                       systemImage: isRecording ? "stop.circle" : "record.circle") {
                    isRecording ? onStop() : onRecord()
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .accessibilityIdentifier("tico.composer.record")
            }
            DisclosureGroup("Nome do gesto") {
                TextField("Nome do gesto", text: $capture.customName)
                    .textFieldStyle(.roundedBorder).disabled(isRecording)
                    .padding(.top, 8)
            }.frame(maxWidth: 460).font(.callout)
        }
    }

    private func sample(_ index: Int) -> some View {
        let path: [TrackpadPoint]? = capture.samples.indices.contains(index)
            ? capture.samples[index].trackpadPath
            : capture.existingTemplate.flatMap { $0.samplePaths.indices.contains(index) ? $0.samplePaths[index] : nil }
        return VStack(spacing: 7) {
            if let path { GesturePathPreview(path: path).frame(width: 120, height: 50) }
            else {
                Image(systemName: "scribble.variable").font(.title)
                    .foregroundStyle(.tertiary).frame(width: 120, height: 50)
            }
            Label("Amostra \(index + 1)", systemImage: path == nil ? "circle.dashed" : "checkmark.circle.fill")
                .font(.caption).foregroundStyle(path == nil ? Color.secondary : Color.green)
            Button("Regravar") {
                capture.repeatSample(index)
                if !isRecording { onRecord() }
            }
            .buttonStyle(.borderless).font(.caption)
            .disabled(path == nil || !canCaptureGlobalInput)
            .accessibilityLabel("Regravar amostra \(index + 1)")
        }
        .padding(8).background(TicoBrand.Palette.surface, in: .rect(cornerRadius: 10))
    }
}
