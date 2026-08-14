import SwiftUI

struct TrackpadLiveView: View {
    let snapshot: TrackpadLaboratorySnapshot?
    let startupError: String?
    @Binding var highlightedRegion: TrackpadRegion

    var body: some View {
        ZStack {
            TrackpadCanvasView(
                snapshot: snapshot,
                highlightedRegion: highlightedRegion,
                presentation: .immersive
            )

            GlassEffectContainer(spacing: 18) {
                VStack(spacing: 18) {
                    HStack {
                        Spacer(minLength: 320)

                        metrics
                            .frame(width: 286)
                            .glassEffect(
                                .regular,
                                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                            )
                    }

                    Spacer(minLength: 0)

                    diagnosticPanel
                        .frame(maxWidth: 760)
                        .glassEffect(
                            .regular,
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                        )
                }
                .padding(.horizontal, 22)
                .padding(.top, 94)
                .padding(.bottom, 18)
            }
        }
    }

    private var metrics: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Destacar região", selection: $highlightedRegion) {
                ForEach(TrackpadRegion.allCases, id: \.self) { region in
                    Text(region.displayName).tag(region)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Características")
                    .font(.headline)

                if let features = snapshot?.features {
                    Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                        metricRow("Fase", features.phase.displayName)
                        metricRow("Dedos", "\(features.maximumFingerCount)")
                        metricRow("Duração", features.duration.decimalText + " s")
                        metricRow("Distância", features.distance.decimalText)
                        metricRow("Centroide/s", features.velocity.decimalText)
                        metricRow("Movimento/s", features.motionVelocity.decimalText)
                        metricRow("Abertura", features.relativeSpanChange.percentText)
                        metricRow("Rotação", features.rotation.decimalText + " rad")
                        metricRow("Pressão", features.pressure?.decimalText ?? "—")
                        metricRow("Início", features.startRegion.displayName)
                        metricRow("Final", features.currentRegion.displayName)
                    }
                } else {
                    Text("As métricas aparecem durante uma sessão de contatos.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
    }

    private var diagnosticPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Diagnóstico")
                .font(.headline)

            if let diagnostic = snapshot?.diagnostic {
                HStack(alignment: .top, spacing: 12) {
                    DiagnosticStatusIcon(outcome: diagnostic.outcome)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(diagnostic.summary)
                            .font(.headline)
                        ForEach(Array(diagnostic.reasons.enumerated()), id: \.offset) { _, reason in
                            Text("• \(reason)")
                                .foregroundStyle(.secondary)
                        }
                        if let candidate = snapshot?.acceptedCandidate {
                            Text("Reconhecedor: \(candidate.recognizer.rawValue)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                }
            } else {
                Label(
                    startupError ?? "Faça um gesto para receber uma explicação.",
                    systemImage: "waveform.path"
                )
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value)
                .monospacedDigit()
                .gridColumnAlignment(.trailing)
        }
    }

}

struct TrackpadCanvasView: View {
    let snapshot: TrackpadLaboratorySnapshot?
    let highlightedRegion: TrackpadRegion
    var presentation = TrackpadCanvasPresentation.contained

    @ViewBuilder
    var body: some View {
        switch presentation {
        case .contained:
            GroupBox("Superfície normalizada") {
                canvas
                    .padding(6)
            }
        case .immersive:
            canvas
                .background(immersiveBackground)
                .overlay(alignment: .bottomLeading) {
                    Label("Superfície normalizada", systemImage: "rectangle.inset.filled")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(18)
                }
        }
    }

    private var canvas: some View {
        Canvas { context, size in
                let inset: CGFloat = presentation == .immersive ? 28 : 12
                let bounds = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
                let background = Path(roundedRect: bounds, cornerRadius: 18)
                context.fill(
                    background,
                    with: .color(.secondary.opacity(presentation == .immersive ? 0.05 : 0.08))
                )
                context.stroke(background, with: .color(.secondary.opacity(0.28)), lineWidth: 1)
                drawRegion(highlightedRegion, in: bounds, context: &context)
                drawGrid(in: bounds, context: &context)

                guard let snapshot else { return }
                drawCentroidPath(snapshot.features.centroidPath, in: bounds, context: &context)
                for contact in snapshot.contacts {
                    drawContactTrail(contact, in: bounds, context: &context)
                    let point = CGPoint(
                        x: bounds.minX + bounds.width * contact.position.x,
                        y: bounds.maxY - bounds.height * contact.position.y
                    )
                    let radius: CGFloat = 13 + min(max(contact.pressure, 0), 1) * 10
                    let circle = Path(
                        ellipseIn: CGRect(
                            x: point.x - radius,
                            y: point.y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )
                    )
                    context.fill(circle, with: .color(color(for: contact.transition).opacity(0.72)))
                    context.stroke(circle, with: .color(color(for: contact.transition)), lineWidth: 2)
                    context.draw(
                        Text("\(contact.identifier)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.white),
                        at: point
                    )
                }
            }
            .overlay {
                if snapshot == nil {
                    ContentUnavailableView(
                        "Aguardando contatos",
                        systemImage: "hand.tap",
                        description: Text("Toque no trackpad ou reproduza uma sessão.")
                    )
                    .allowsHitTesting(false)
                }
            }
    }

    private var immersiveBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    TicoBrand.Palette.background.opacity(0.72),
                    TicoBrand.Palette.primary.opacity(0.08),
                    TicoBrand.Palette.accent.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [TicoBrand.Palette.primary.opacity(0.12), .clear],
                center: .center,
                startRadius: 30,
                endRadius: 420
            )
        }
        .accessibilityHidden(true)
    }

    private func drawGrid(in bounds: CGRect, context: inout GraphicsContext) {
        for fraction in [1.0 / 3, 0.5, 2.0 / 3] {
            var vertical = Path()
            vertical.move(to: CGPoint(x: bounds.minX + bounds.width * fraction, y: bounds.minY))
            vertical.addLine(to: CGPoint(x: bounds.minX + bounds.width * fraction, y: bounds.maxY))
            context.stroke(vertical, with: .color(.secondary.opacity(0.12)), lineWidth: 1)

            var horizontal = Path()
            horizontal.move(to: CGPoint(x: bounds.minX, y: bounds.minY + bounds.height * fraction))
            horizontal.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY + bounds.height * fraction))
            context.stroke(horizontal, with: .color(.secondary.opacity(0.12)), lineWidth: 1)
        }
    }

    private func drawRegion(
        _ region: TrackpadRegion,
        in bounds: CGRect,
        context: inout GraphicsContext
    ) {
        guard region != .any else { return }
        let columns = 24
        let rows = 16
        let cellWidth = bounds.width / Double(columns)
        let cellHeight = bounds.height / Double(rows)
        for row in 0..<rows {
            for column in 0..<columns {
                let normalized = TrackpadPoint(
                    x: (Double(column) + 0.5) / Double(columns),
                    y: 1 - (Double(row) + 0.5) / Double(rows)
                )
                guard region.contains(normalized) else { continue }
                let rect = CGRect(
                    x: bounds.minX + Double(column) * cellWidth,
                    y: bounds.minY + Double(row) * cellHeight,
                    width: cellWidth + 0.5,
                    height: cellHeight + 0.5
                )
                context.fill(Path(rect), with: .color(.accentColor.opacity(0.13)))
            }
        }
    }

    private func drawCentroidPath(
        _ points: [TrackpadPoint],
        in bounds: CGRect,
        context: inout GraphicsContext
    ) {
        guard points.count > 1 else { return }
        var path = Path()
        for (index, point) in points.enumerated() {
            let canvasPoint = CGPoint(
                x: bounds.minX + bounds.width * point.x,
                y: bounds.maxY - bounds.height * point.y
            )
            if index == 0 {
                path.move(to: canvasPoint)
            } else {
                path.addLine(to: canvasPoint)
            }
        }
        context.stroke(
            path,
            with: .color(TicoBrand.Palette.primary.opacity(0.72)),
            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
        )
    }

    private func drawContactTrail(
        _ contact: ContactState,
        in bounds: CGRect,
        context: inout GraphicsContext
    ) {
        var path = Path()
        path.move(
            to: CGPoint(
                x: bounds.minX + bounds.width * contact.startPosition.x,
                y: bounds.maxY - bounds.height * contact.startPosition.y
            )
        )
        path.addLine(
            to: CGPoint(
                x: bounds.minX + bounds.width * contact.position.x,
                y: bounds.maxY - bounds.height * contact.position.y
            )
        )
        context.stroke(
            path,
            with: .color(color(for: contact.transition).opacity(0.30)),
            style: StrokeStyle(lineWidth: 2, lineCap: .round)
        )
    }

    private func color(for transition: ContactTransition) -> Color {
        switch transition {
        case .down: .green
        case .move: .blue
        case .up: .orange
        case .cancel: .red
        }
    }
}

enum TrackpadCanvasPresentation {
    case contained
    case immersive
}

private extension GesturePhase {
    var displayName: String {
        switch self {
        case .began: "Início"
        case .changed: "Em andamento"
        case .ended: "Finalizada"
        case .cancelled: "Cancelada"
        }
    }
}

private extension Double {
    var decimalText: String {
        formatted(.number.precision(.fractionLength(3)))
    }

    var percentText: String {
        formatted(.percent.precision(.fractionLength(1)))
    }
}
