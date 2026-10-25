import SwiftUI

/// Lista e detalhe conservam a identidade enquanto o espaço muda de colunas
/// para linhas. A seleção pertence ao consumidor; o ajuste da coluna é local.
/// Paralelo com React: muda a direção do layout sem remontar seus filhos.
struct AdaptiveSplitView<Primary: View, Detail: View>: View {
    let breakpoint: CGFloat
    let minPrimaryWidth: CGFloat
    let maxPrimaryWidth: CGFloat
    private let primary: Primary
    private let detail: Detail
    @State private var preferredWidth: CGFloat
    @State private var dragStart: CGFloat?

    init(
        breakpoint: CGFloat = 720,
        minPrimaryWidth: CGFloat = 240,
        idealPrimaryWidth: CGFloat = 280,
        maxPrimaryWidth: CGFloat = 360,
        @ViewBuilder primary: () -> Primary,
        @ViewBuilder detail: () -> Detail
    ) {
        self.breakpoint = breakpoint
        self.minPrimaryWidth = minPrimaryWidth
        self.maxPrimaryWidth = maxPrimaryWidth
        self.primary = primary()
        self.detail = detail()
        _preferredWidth = State(initialValue: idealPrimaryWidth)
    }

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < breakpoint
            let upperWidth = max(minPrimaryWidth, min(maxPrimaryWidth, geometry.size.width * 0.48))
            let columnWidth = min(max(preferredWidth, minPrimaryWidth), upperWidth)
            let layout = compact
                ? AnyLayout(VStackLayout(spacing: 0))
                : AnyLayout(HStackLayout(spacing: 0))
            layout {
                primary
                    .frame(width: compact ? nil : columnWidth,
                           height: compact ? min(180, max(100, geometry.size.height * 0.32)) : nil)
                    .frame(maxWidth: compact ? .infinity : nil, maxHeight: compact ? nil : .infinity)
                Rectangle().fill(.separator)
                    .frame(width: compact ? nil : 1, height: compact ? 1 : nil)
                    .overlay {
                        if !compact {
                            Color.clear.frame(width: 12).contentShape(Rectangle())
                                .gesture(DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        if dragStart == nil { dragStart = columnWidth }
                                        preferredWidth = min(upperWidth, max(minPrimaryWidth,
                                            (dragStart ?? columnWidth) + value.translation.width))
                                    }
                                    .onEnded { _ in dragStart = nil })
                                .accessibilityElement()
                                .accessibilityLabel("Largura da lista")
                                .accessibilityValue("\(Int(columnWidth)) pontos")
                                .accessibilityAdjustableAction { direction in
                                    switch direction {
                                    case .increment: preferredWidth = min(upperWidth, columnWidth + 24)
                                    case .decrement: preferredWidth = max(minPrimaryWidth, columnWidth - 24)
                                    @unknown default: break
                                    }
                                }
                        }
                    }
                detail.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
