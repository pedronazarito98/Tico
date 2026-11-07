import SwiftUI

/// Apresenta o acionamento sem observar hardware ou executar o atalho.
/// Paralelo com React: o desenho é derivado da propriedade recebida, sem estado próprio.
struct ShortcutLibraryTriggerView: View {
    let trigger: TriggerDefinition

    var body: some View {
        switch trigger {
        case let .keyboard(code, modifiers):
            keyboard(code: code, modifiers: modifiers)
        case let .trackpad(spec):
            if let direction = SwipeDirection(spec.gesture),
               spec.fingerCount.lowerBound == spec.fingerCount.upperBound,
               (1...5).contains(spec.fingerCount.lowerBound),
               let center = SwipeStartPosition(spec.startRegion) {
                swipe(spec: spec, direction: direction, center: center)
            } else {
                neutralSummary
            }
        case let .sequence(sequence):
            sequenceSummary(sequence)
        case .mouseButton, .customTrackpad:
            neutralSummary
        }
    }

    private func keyboard(code: UInt16, modifiers: Set<InputModifier>) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(InputModifier.allCases.filter(modifiers.contains), id: \.self) { modifier in
                    keycap(modifier.symbol)
                }
                keycap(InputPresentation.label(code))
            }.padding(.vertical, 5)
        }
        .scrollIndicators(.automatic)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(RuleEditorSummary.trigger(trigger))
    }

    private func keycap(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 23, weight: .medium))
            .padding(.horizontal, 15)
            .frame(minWidth: 50, minHeight: 48)
            .background(TicoBrand.Palette.surface, in: .rect(cornerRadius: 10))
            .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(.primary.opacity(0.13)) }
            .shadow(color: .black.opacity(0.08), radius: 2, y: 2)
            .fixedSize()
    }

    /// Os pontos são uma ilustração da região inicial, não contatos observados.
    /// Apenas gestos com direção e quantidade exatas recebem este desenho.
    private func swipe(spec: TrackpadTriggerSpec, direction: SwipeDirection,
                       center: SwipeStartPosition) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 18) {
                swipeVisual(spec: spec, direction: direction, center: center)
                swipeText(spec).frame(minWidth: 165, maxWidth: .infinity, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 12) {
                swipeVisual(spec: spec, direction: direction, center: center)
                swipeText(spec)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trackpadAccessibilityLabel(spec))
    }

    private func swipeVisual(spec: TrackpadTriggerSpec, direction: SwipeDirection,
                             center: SwipeStartPosition) -> some View {
        HStack(spacing: 8) {
            let modifiers = spec.requiredModifiers ?? []
            if !modifiers.isEmpty {
                VStack(spacing: 5) {
                    ForEach(InputModifier.allCases.filter(modifiers.contains), id: \.self) { modifier in
                        Text(modifier.symbol).font(.system(size: 17, weight: .medium))
                            .frame(minWidth: 34, minHeight: 32)
                            .background(TicoBrand.Palette.surface, in: .rect(cornerRadius: 7))
                            .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(.primary.opacity(0.12)) }
                    }
                }
                Image(systemName: "plus").font(.caption).foregroundStyle(.secondary)
            }
            SwipeTrackpadView(fingers: spec.fingerCount.lowerBound, direction: direction, center: center)
                .frame(width: 190, height: 108)
        }.accessibilityHidden(true)
    }

    private func swipeText(_ spec: TrackpadTriggerSpec) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(RuleEditorSummary.trigger(trigger))
                .font(.callout.weight(.medium)).fixedSize(horizontal: false, vertical: true)
            Text("Início: \(spec.startRegion.displayName)")
                .font(.caption).foregroundStyle(.secondary)
            if let end = spec.endRegion, end != .any {
                Text("Fim: \(end.displayName)").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var neutralSummary: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: RuleEditorSummary.symbol(trigger))
                .font(.title3).foregroundStyle(TicoBrand.Palette.primary)
                .frame(width: 30, height: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(RuleEditorSummary.trigger(trigger)).font(.callout.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                if case let .trackpad(spec) = trigger {
                    Text("Início: \(spec.startRegion.displayName)")
                        .font(.caption).foregroundStyle(.secondary)
                    if let end = spec.endRegion, end != .any {
                        Text("Fim: \(end.displayName)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func sequenceSummary(_ sequence: TriggerSequence) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(sequence.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(index + 1).")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    Text(sequenceStepDescription(step))
                        .font(.callout.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Sequência: \(sequence.steps.map(sequenceStepDescription).joined(separator: ", depois "))")
    }

    /// Uma etapa de sequência pode restringir a região final além do resumo comum.
    private func sequenceStepDescription(_ step: TriggerStep) -> String {
        var description = RuleEditorSummary.trigger(step.triggerDefinition)
        if case let .trackpad(spec) = step, let end = spec.endRegion, end != .any {
            description += " · Fim: \(end.displayName)"
        }
        return description
    }

    private func trackpadAccessibilityLabel(_ spec: TrackpadTriggerSpec) -> String {
        var label = "\(RuleEditorSummary.trigger(trigger)). Início: \(spec.startRegion.displayName)."
        if let end = spec.endRegion, end != .any { label += " Fim: \(end.displayName)." }
        return label
    }
}

private enum SwipeDirection {
    case left, right, up, down

    init?(_ gesture: TrackpadGesture) {
        switch gesture {
        case .swipeLeft: self = .left
        case .swipeRight: self = .right
        case .swipeUp: self = .up
        case .swipeDown: self = .down
        default: return nil
        }
    }

    var symbol: String {
        switch self {
        case .left: "arrow.left"
        case .right: "arrow.right"
        case .up: "arrow.up"
        case .down: "arrow.down"
        }
    }
}

/// Coordenadas são frações da superfície desenhada, com origem no canto superior
/// esquerdo. Bordas e cantos usam fallback textual para não sugerir precisão falsa.
private struct SwipeStartPosition {
    let x: CGFloat
    let y: CGFloat

    init?(_ region: TrackpadRegion) {
        switch region {
        case .any, .gridCenter: (x, y) = (0.5, 0.5)
        case .topLeft: (x, y) = (0.25, 0.25)
        case .topRight: (x, y) = (0.75, 0.25)
        case .bottomLeft: (x, y) = (0.25, 0.75)
        case .bottomRight: (x, y) = (0.75, 0.75)
        case .gridTopLeft: (x, y) = (1 / 6, 1 / 6)
        case .gridTopCenter: (x, y) = (0.5, 1 / 6)
        case .gridTopRight: (x, y) = (5 / 6, 1 / 6)
        case .gridMiddleLeft: (x, y) = (1 / 6, 0.5)
        case .gridMiddleRight: (x, y) = (5 / 6, 0.5)
        case .gridBottomLeft: (x, y) = (1 / 6, 5 / 6)
        case .gridBottomCenter: (x, y) = (0.5, 5 / 6)
        case .gridBottomRight: (x, y) = (5 / 6, 5 / 6)
        case .topEdge, .bottomEdge, .leftEdge, .rightEdge,
             .cornerTopLeft, .cornerTopRight, .cornerBottomLeft, .cornerBottomRight:
            return nil
        }
    }
}

/// Superfície estática: a seta informa direção, enquanto os pontos indicam
/// somente a posição inicial ilustrativa; não há animação ou captura ativa.
private struct SwipeTrackpadView: View {
    let fingers: Int
    let direction: SwipeDirection
    let center: SwipeStartPosition

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.primary.opacity(0.035))
                    .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.14)) }
                ForEach(0..<fingers, id: \.self) { index in
                    Circle().fill(TicoBrand.Palette.primary.opacity(0.8))
                        .frame(width: 11, height: 11)
                        .position(x: geometry.size.width * (center.x + (CGFloat(index) - CGFloat(fingers - 1) / 2) * 0.055),
                                  y: geometry.size.height * center.y)
                }
                Image(systemName: direction.symbol)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(TicoBrand.Palette.primary)
                    .position(x: geometry.size.width * 0.5,
                              y: geometry.size.height * (center.y >= 0.5 ? 0.22 : 0.78))
            }
        }
    }
}
