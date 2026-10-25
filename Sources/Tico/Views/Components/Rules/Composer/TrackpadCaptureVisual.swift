import SwiftUI

/// Mostra contatos observados durante a gravação. A demonstração é identificada
/// e usa pontos sintéticos somente no desenho, sem alimentar o reconhecimento.
struct TrackpadCaptureVisual: View {
    let spec: TrackpadTriggerSpec
    let snapshot: TrackpadLaboratorySnapshot?
    let isRecording: Bool
    var customPath: [TrackpadPoint] = []
    var isCustom = false
    var showsSelection = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var demonstrating = false

    var body: some View {
        VStack(spacing: 12) {
            TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !demonstrating || reduceMotion)) { timeline in
                let phase = reduceMotion ? 0.5 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2) / 2
                Canvas { context, size in
                    let rect = CGRect(origin: .zero, size: size).insetBy(dx: 18, dy: 18)
                    let points = isRecording ? (snapshot?.contacts.filter { $0.transition != .up && $0.transition != .cancel }.map(\.position) ?? [])
                        : (isCustom || !showsSelection ? [] : demonstrationPoints(progress: demonstrating ? phase : 0.5))
                    let path = isRecording ? (snapshot?.features.centroidPath ?? []) : fittedCustomPath
                    if path.count > 1 {
                        var line = Path()
                        for (index, point) in path.enumerated() {
                            let position = position(point, in: rect)
                            if index == 0 { line.move(to: position) } else { line.addLine(to: position) }
                        }
                        context.stroke(line, with: .color(TicoBrand.Palette.primary.opacity(0.55)),
                                       style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    }
                    for point in points {
                        let center = position(point, in: rect)
                        context.fill(Path(ellipseIn: CGRect(x: center.x - 19, y: center.y - 19, width: 38, height: 38)),
                                     with: .color(TicoBrand.Palette.primary.opacity(0.1)))
                        context.fill(Path(ellipseIn: CGRect(x: center.x - 10, y: center.y - 10, width: 20, height: 20)),
                                     with: .color(TicoBrand.Palette.primary))
                    }
                }
            }
            .frame(width: 350, height: 190)
            .background(LinearGradient(colors: [TicoBrand.Palette.surface, TicoBrand.Palette.background], startPoint: .top, endPoint: .bottom), in: .rect(cornerRadius: 22))
            .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(.primary.opacity(0.16), lineWidth: 1.5) }
            .overlay {
                if !isRecording && ((isCustom && customPath.isEmpty) || !showsSelection) {
                    Image(systemName: isCustom ? "scribble.variable" : "hand.draw").font(.system(size: 54, weight: .light))
                        .foregroundStyle(TicoBrand.Palette.primary.opacity(0.4)).accessibilityHidden(true)
                }
            }
            .shadow(color: .black.opacity(0.06), radius: 10, y: 8)
            .accessibilityLabel(isRecording ? "Trackpad: \(snapshot?.contacts.count ?? 0) contatos observados" : isCustom ? "Prévia da sua trajetória" : showsSelection ? "Prévia: \(spec.gesture.displayName), \(spec.fingerCount.displayText) dedos" : "Trackpad pronto para gravar")
            HStack(spacing: 12) {
                Label(isRecording ? "Contatos ao vivo" : isCustom ? "Sua trajetória" : !showsSelection ? "Seu gesto aparecerá aqui" : demonstrating ? "Demonstração" : spec.gesture.displayName,
                      systemImage: isRecording ? "record.circle" : "hand.draw")
                    .font(.caption).foregroundStyle(.secondary)
                if !isRecording && !isCustom && showsSelection {
                    Button(demonstrating ? "Pausar" : "Ver movimento", systemImage: demonstrating ? "pause.fill" : "play.fill") {
                        demonstrating.toggle()
                    }.buttonStyle(.borderless).font(.caption)
                        .help("Mostra um exemplo do movimento escolhido.")
                }
            }
        }.onChange(of: isRecording) { if isRecording { demonstrating = false } }
    }
    // Amostras persistidas são relativas à origem, podendo conter coordenadas
    // negativas. Ajustar apenas o desenho preserva a geometria do reconhecimento.
    private var fittedCustomPath: [TrackpadPoint] {
        guard !customPath.isEmpty else { return [] }
        let minX = customPath.map(\.x).min() ?? 0
        let maxX = customPath.map(\.x).max() ?? 1
        let minY = customPath.map(\.y).min() ?? 0
        let maxY = customPath.map(\.y).max() ?? 1
        let scale = max(maxX - minX, maxY - minY, 0.001)
        return customPath.map {
            TrackpadPoint(x: 0.5 + ($0.x - (minX + maxX) / 2) / scale * 0.75,
                          y: 0.5 + ($0.y - (minY + maxY) / 2) / scale * 0.75)
        }
    }
    private func position(_ point: TrackpadPoint, in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + min(max(point.x, 0), 1) * rect.width,
                y: rect.maxY - min(max(point.y, 0), 1) * rect.height)
    }
    private func demonstrationPoints(progress: Double) -> [TrackpadPoint] {
        let movement = (min(progress / 0.75, 1) - 0.5) * 0.36
        if spec.gesture == .tap, demonstrating, !reduceMotion, progress > 0.35 && progress < 0.85 { return [] }
        let count = min(spec.fingerCount.lowerBound, 5)
        return (0..<count).map { index in
            var x = 0.5 + (Double(index) - Double(count - 1) / 2) * 0.12
            var y = 0.5
            switch spec.gesture {
            case .swipeUp: y += movement
            case .swipeDown: y -= movement
            case .swipeLeft: x -= movement
            case .swipeRight: x += movement
            case .pinchIn, .pinchOut:
                let radius = 0.15 + movement * (spec.gesture == .pinchIn ? -1 : 1)
                x = 0.5 + (index % 2 == 0 ? -radius : radius)
            case .rotateClockwise, .rotateCounterclockwise:
                let angle = Double(index) / Double(max(count, 1)) * .pi * 2 + movement * (spec.gesture == .rotateClockwise ? -5 : 5)
                x = 0.5 + cos(angle) * 0.2; y = 0.5 + sin(angle) * 0.25
            default: break
            }
            return TrackpadPoint(x: x, y: y)
        }
    }
}
