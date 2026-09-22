import SwiftUI

/// Representação do gesto escolhido, sem consultar hardware ou simular reconhecimento.
struct ShortcutGesturePreview: View {
    let trigger: TriggerDefinition?
    var height: CGFloat = 135

    private var fingers: Int {
        guard case let .trackpad(spec) = trigger else { return trigger == nil ? 3 : 0 }
        return max(0, min(spec.fingerCount.lowerBound, 5))
    }

    private var symbol: String {
        guard let trigger else { return "" }
        guard case let .trackpad(spec) = trigger else { return RuleEditorSummary.symbol(trigger) }
        switch spec.gesture {
        case .swipeLeft: return "arrow.left"
        case .swipeRight: return "arrow.right"
        case .swipeUp: return "arrow.up"
        case .swipeDown: return "arrow.down"
        case .pinchIn: return "arrow.down.right.and.arrow.up.left"
        case .pinchOut: return "arrow.up.left.and.arrow.down.right"
        default: return "hand.tap"
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            if !symbol.isEmpty {
                Image(systemName: symbol).font(.system(size: height * 0.27, weight: .medium))
                    .foregroundStyle(TicoBrand.Palette.primary)
            }
            if fingers > 0 {
                HStack(spacing: 9) {
                    ForEach(0..<fingers, id: \.self) { _ in
                        Circle().fill(trigger == nil ? Color.secondary.opacity(0.35) : TicoBrand.Palette.primary)
                            .frame(width: height * 0.13, height: height * 0.13)
                            .overlay { Circle().strokeBorder(.white.opacity(0.8)) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity).frame(height: height)
        .background(.linearGradient(colors: [.primary.opacity(0.04), .secondary.opacity(0.23)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing), in: .rect(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.secondary.opacity(0.35), lineWidth: 1.5) }
        .shadow(color: .black.opacity(0.08), radius: 6, y: 4)
        .accessibilityLabel(trigger.map { RuleEditorSummary.trigger($0) } ?? "Gesto ainda não escolhido")
    }
}
