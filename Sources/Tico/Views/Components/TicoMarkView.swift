import SwiftUI

struct TicoMarkView: View {
    enum Style {
        case symbol
        case wordmark
    }

    let style: Style

    @Environment(\.colorScheme) private var colorScheme

    init(_ style: Style = .symbol) {
        self.style = style
    }

    var body: some View {
        Image(assetName, bundle: TicoBrand.Assets.bundle)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .scaledToFit()
            .accessibilityLabel(TicoBrand.displayName)
    }

    private var assetName: String {
        let appearance: TicoBrand.Appearance = colorScheme == .dark ? .dark : .light
        return switch style {
        case .symbol:
            TicoBrand.Assets.symbolName(for: appearance)
        case .wordmark:
            TicoBrand.Assets.wordmarkName(for: appearance)
        }
    }
}
