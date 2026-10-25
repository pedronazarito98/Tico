import SwiftUI

/// Áreas clicáveis representam os botões aceitos pelo monitor. Os cliques
/// primários continuam sem ação de configuração para não sugerir suporte inexistente.
struct MouseCaptureVisual: View {
    let selectedButton: Int
    let onSelect: (Int) -> Void
    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 65).fill(TicoBrand.Palette.surface)
                .overlay { RoundedRectangle(cornerRadius: 65).strokeBorder(.primary.opacity(0.16)) }
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Spacer()
                    Rectangle().fill(.primary.opacity(0.12)).frame(width: 1, height: 35)
                    Spacer()
                }
                control(2, symbol: "line.3.horizontal", width: 25, height: 46)
                Spacer()
                Text(InputPresentation.mouseLabel(selectedButton)).font(.caption.weight(.medium))
                    .multilineTextAlignment(.center).padding(.horizontal, 24).padding(.bottom, 28)
            }
            VStack(spacing: 12) {
                control(3, symbol: "chevron.left", width: 22, height: 34)
                control(4, symbol: "chevron.right", width: 22, height: 34)
            }.offset(x: -74, y: 70)
        }.frame(width: 170, height: 220)
            .accessibilityElement(children: .contain).accessibilityLabel("Mouse visual")
    }
    private func control(_ button: Int, symbol: String, width: CGFloat, height: CGFloat) -> some View {
        Button { onSelect(button) } label: {
            Image(systemName: symbol).font(.system(size: 11, weight: .semibold))
                .foregroundStyle(selectedButton == button ? .white : TicoBrand.Palette.primary)
                .frame(width: width, height: height)
                .background(selectedButton == button ? TicoBrand.Palette.primary : TicoBrand.Palette.background, in: .rect(cornerRadius: 7))
                .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(TicoBrand.Palette.primary.opacity(0.25)) }
        }.buttonStyle(.plain).help(InputPresentation.mouseLabel(button))
            .accessibilityLabel(InputPresentation.mouseLabel(button))
            .accessibilityValue(selectedButton == button ? "Selecionado" : "")
    }
}
