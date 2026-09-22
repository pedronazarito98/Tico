import SwiftUI

/// Miniatura espacial: a área colorida representa o resultado da operação.
/// Coordenadas normalizadas mantêm a prévia legível em diferentes larguras.
struct WindowPlacementPreview: View {
    let operation: WindowOperation

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            RoundedRectangle(cornerRadius: 4).strokeBorder(.secondary.opacity(0.5))
            if let region {
                RoundedRectangle(cornerRadius: 2)
                    .fill(TicoBrand.Palette.primary.opacity(0.7))
                    .frame(width: (width - 8) * region.width, height: (height - 8) * region.height)
                    .offset(x: 4 + (width - 8) * region.minX, y: 4 + (height - 8) * region.minY)
            } else {
                Image(systemName: symbol).font(.system(size: 16))
                    .frame(width: width, height: height)
            }
        }.frame(width: 46, height: 31).accessibilityHidden(true)
    }

    private var region: CGRect? {
        switch operation {
        case .leftHalf: CGRect(x: 0, y: 0, width: 0.5, height: 1)
        case .rightHalf: CGRect(x: 0.5, y: 0, width: 0.5, height: 1)
        case .topHalf: CGRect(x: 0, y: 0, width: 1, height: 0.5)
        case .bottomHalf: CGRect(x: 0, y: 0.5, width: 1, height: 0.5)
        case .leftThird: CGRect(x: 0, y: 0, width: 1.0 / 3, height: 1)
        case .centerThird: CGRect(x: 1.0 / 3, y: 0, width: 1.0 / 3, height: 1)
        case .rightThird: CGRect(x: 2.0 / 3, y: 0, width: 1.0 / 3, height: 1)
        case .topLeftQuarter: CGRect(x: 0, y: 0, width: 0.5, height: 0.5)
        case .topRightQuarter: CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5)
        case .bottomLeftQuarter: CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5)
        case .bottomRightQuarter: CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
        case .maximize: CGRect(x: 0, y: 0, width: 1, height: 1)
        case .center: CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
        default: nil
        }
    }

    private var symbol: String {
        switch operation {
        case .close: "xmark"
        case .minimize: "minus"
        case .restore: "arrow.uturn.backward"
        case .nextDisplay: "arrow.right"
        case .tileAll: "square.grid.2x2"
        default: "macwindow"
        }
    }
}
