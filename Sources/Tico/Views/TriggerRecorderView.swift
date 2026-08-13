import SwiftUI

enum TriggerRecordingMode: String, Identifiable {
    case standard
    case customTrackpad

    var id: Self { self }
}

struct TriggerRecorderView: View {
    let mode: TriggerRecordingMode
    let suggestedName: String
    let isRecording: Bool
    let latestEvent: InputEventDescriptor?
    let captureMode: TrackpadCaptureMode
    let startupError: String?
    let snapshot: TrackpadLaboratorySnapshot?
    let onCancel: () -> Void
    let onUseTrigger: (TriggerDefinition) -> Void

    @State private var samples: [InputEventDescriptor] = []
    @State private var trainingError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            captureStatus

            if mode == .customTrackpad {
                customTraining
            } else {
                standardRecording
            }

            HStack {
                Button("Cancelar", action: onCancel)
                Spacer()
                Button(primaryButtonTitle, action: useRecordedTrigger)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canUseRecording)
            }
        }
        .padding(28)
        .frame(width: 560)
        .onChange(of: latestEvent) { _, event in
            guard mode == .customTrackpad, let event else { return }
            collectSample(event)
        }
        .alert("Não foi possível ensinar o gesto", isPresented: trainingErrorIsPresented) {
            Button("OK", role: .cancel) { trainingError = nil }
        } message: {
            Text(trainingError ?? "Erro desconhecido")
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: mode == .customTrackpad ? "scribble.variable" : "record.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(isRecording ? .red : .secondary)
                .symbolEffect(.pulse, isActive: isRecording)

            VStack(alignment: .leading, spacing: 3) {
                Text(mode == .customTrackpad ? "Ensinar gesto personalizado" : "Gravar gatilho")
                    .font(.title2.weight(.semibold))
                Text(instruction)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var captureStatus: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: captureStatusIcon)
                .foregroundStyle(captureStatusColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(captureMode.displayName)
                    .font(.subheadline.weight(.medium))
                Text(captureStatusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let snapshot, snapshot.phase != .ended, snapshot.phase != .cancelled {
                Label(
                    "\(snapshot.features.maximumFingerCount) dedos",
                    systemImage: "hand.point.up.left.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
    }

    private var standardRecording: some View {
        GroupBox("Evento detectado") {
            if let latestEvent {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(latestEvent.displayName)
                            .font(.headline)
                        Text(latestEvent.timestamp, format: .dateTime.hour().minute().second())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !latestEvent.trackpadPath.isEmpty {
                        GesturePathPreview(path: latestEvent.trackpadPath)
                            .frame(width: 92, height: 64)
                    }
                }
                .padding(8)
            } else {
                ProgressView("Aguardando próximo evento…")
                    .frame(maxWidth: .infinity, minHeight: 70)
            }
        }
    }

    private var customTraining: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Amostras")
                    .font(.headline)
                Spacer()
                Text("\(samples.count) · mínimo \(CustomGestureTemplate.minimumSampleCount)")
                    .monospacedDigit()
                    .foregroundStyle(samples.count >= CustomGestureTemplate.minimumSampleCount ? .green : .secondary)
            }

            GesturePathPreview(path: currentPreviewPath)
                .frame(height: 180)
                .overlay(alignment: .bottomLeading) {
                    if currentPreviewPath.isEmpty {
                        Text("Desenhe a trajetória no trackpad")
                            .foregroundStyle(.secondary)
                            .padding(14)
                    }
                }

            HStack(spacing: 8) {
                ForEach(0..<CustomGestureTemplate.maximumSampleCount, id: \.self) { index in
                    Label(
                        index < samples.count ? "Amostra \(index + 1)" : "Pendente",
                        systemImage: index < samples.count ? "checkmark.circle.fill" : "circle"
                    )
                    .font(.caption)
                    .foregroundStyle(index < samples.count ? .green : .secondary)
                }
                Spacer()
                Button("Limpar") {
                    samples.removeAll()
                }
                .disabled(samples.isEmpty)
            }

            Text("Repita a mesma trajetória três vezes, com a mesma quantidade de dedos. O processamento é local e normaliza posição e tamanho.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var instruction: String {
        switch mode {
        case .standard:
            "Pressione uma tecla, clique um botão extra ou faça um gesto no trackpad."
        case .customTrackpad:
            "Repita uma trajetória livre três vezes para criar um modelo confiável."
        }
    }

    private var primaryButtonTitle: String {
        mode == .customTrackpad ? "Criar gesto" : "Usar gatilho"
    }

    private var canUseRecording: Bool {
        switch mode {
        case .standard:
            latestEvent?.triggerDefinition != nil
        case .customTrackpad:
            samples.count >= CustomGestureTemplate.minimumSampleCount
        }
    }

    private var currentPreviewPath: [TrackpadPoint] {
        if let path = samples.last?.trackpadPath, !path.isEmpty {
            return path
        }
        if let path = latestEvent?.trackpadPath, !path.isEmpty {
            return path
        }
        return snapshot?.features.centroidPath ?? []
    }

    private var captureStatusIcon: String {
        return switch captureMode {
        case .advancedGlobal: "dot.radiowaves.left.and.right"
        case .systemGestureFallback: "exclamationmark.triangle.fill"
        case .stopped: "pause.circle"
        }
    }

    private var captureStatusColor: Color {
        switch captureMode {
        case .advancedGlobal: .green
        case .systemGestureFallback: .orange
        case .stopped: .secondary
        }
    }

    private var captureStatusDetail: String {
        if let startupError, !startupError.isEmpty {
            return startupError
        }
        return switch captureMode {
        case .advancedGlobal:
            "Contatos brutos ativos; toques, regiões e trajetórias livres podem ser gravados."
        case .systemGestureFallback:
            "O fallback reconhece apenas swipe, pinça e rotação fornecidos pelo macOS."
        case .stopped:
            "Inicializando a captura do trackpad…"
        }
    }

    private var trainingErrorIsPresented: Binding<Bool> {
        Binding(
            get: { trainingError != nil },
            set: { if !$0 { trainingError = nil } }
        )
    }

    private func collectSample(_ event: InputEventDescriptor) {
        guard event.kind == .trackpadGesture,
              CustomGesturePath.normalized(
                  event.trackpadPath,
                  pointCount: CustomGestureTemplate.defaultPointCount
              ) != nil,
              !samples.contains(where: { $0.timestamp == event.timestamp }) else {
            return
        }

        if let expected = samples.first?.fingerCount,
           event.fingerCount != expected {
            trainingError = CustomGestureTrainingError.inconsistentFingerCount.localizedDescription
            return
        }
        if samples.count == CustomGestureTemplate.maximumSampleCount {
            samples.removeFirst()
        }
        samples.append(event)
    }

    private func useRecordedTrigger() {
        switch mode {
        case .standard:
            guard let trigger = latestEvent?.triggerDefinition else { return }
            onUseTrigger(trigger)
        case .customTrackpad:
            do {
                let template = try CustomGesturePath.train(
                    name: suggestedName,
                    from: samples
                )
                onUseTrigger(.customTrackpad(template: template))
            } catch {
                trainingError = error.localizedDescription
            }
        }
    }
}

struct GesturePathPreview: View {
    let path: [TrackpadPoint]

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 10, dy: 10)
            context.fill(
                Path(roundedRect: rect, cornerRadius: 10),
                with: .color(.secondary.opacity(0.08))
            )
            guard path.count >= 2 else { return }
            let fitted = fittedPoints(in: rect)
            var line = Path()
            line.move(to: fitted[0])
            fitted.dropFirst().forEach { line.addLine(to: $0) }
            context.stroke(
                line,
                with: .linearGradient(
                    Gradient(colors: [.blue, .purple]),
                    startPoint: fitted[0],
                    endPoint: fitted.last ?? fitted[0]
                ),
                style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
            )
            context.fill(
                Path(ellipseIn: CGRect(
                    x: fitted[0].x - 4,
                    y: fitted[0].y - 4,
                    width: 8,
                    height: 8
                )),
                with: .color(.green)
            )
        }
        .accessibilityLabel("Prévia da trajetória do gesto")
    }

    private func fittedPoints(in rect: CGRect) -> [CGPoint] {
        let minX = path.map(\.x).min() ?? 0
        let maxX = path.map(\.x).max() ?? 1
        let minY = path.map(\.y).min() ?? 0
        let maxY = path.map(\.y).max() ?? 1
        let width = max(maxX - minX, 0.001)
        let height = max(maxY - minY, 0.001)
        let scale = min(rect.width / width, rect.height / height)
        let drawnWidth = width * scale
        let drawnHeight = height * scale
        let originX = rect.midX - drawnWidth / 2
        let originY = rect.midY - drawnHeight / 2
        return path.map {
            CGPoint(
                x: originX + ($0.x - minX) * scale,
                y: originY + (maxY - $0.y) * scale
            )
        }
    }
}
