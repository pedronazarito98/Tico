import SwiftUI

/// Demonstração ilustrativa; não representa contatos reais nem lê a captura.
struct GestureIllustrationView: View {
    let trigger: TriggerDefinition
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(.quaternary.opacity(0.5))
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.secondary.opacity(0.25))
            Image(systemName: symbol)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(TicoBrand.Palette.primary)
                .phaseAnimator([false, true]) { content, phase in
                    content.offset(x: reduceMotion ? 0 : (phase ? displacement.width : 0),
                                   y: reduceMotion ? 0 : (phase ? displacement.height : 0))
                        .opacity(reduceMotion ? 1 : (phase ? 1 : 0.6))
                } animation: { _ in .easeInOut(duration: 1.2) }
        }
        .frame(width: 150, height: 94)
        .accessibilityLabel(trigger.displayName)
    }

    private var symbol: String {
        switch trigger {
        case let .trackpad(spec):
            switch spec.gesture {
            case .swipeLeft: "arrow.left"
            case .swipeRight: "arrow.right"
            case .swipeUp: "arrow.up"
            case .swipeDown: "arrow.down"
            case .pinchIn: "arrow.down.right.and.arrow.up.left"
            case .pinchOut: "arrow.up.left.and.arrow.down.right"
            default: "hand.tap"
            }
        case .keyboard: "keyboard"
        case .mouseButton: "computermouse"
        case .customTrackpad: "scribble.variable"
        case .sequence: "point.3.connected.trianglepath.dotted"
        }
    }

    private var displacement: CGSize {
        guard case let .trackpad(spec) = trigger else { return .zero }
        switch spec.gesture {
        case .swipeLeft: return CGSize(width: -18, height: 0)
        case .swipeRight: return CGSize(width: 18, height: 0)
        case .swipeUp: return CGSize(width: 0, height: -14)
        case .swipeDown: return CGSize(width: 0, height: 14)
        default: return .zero
        }
    }
}
