import SwiftUI

/// Escolha pelo resultado visual. As operações menos comuns expandem no mesmo
/// contexto, preservando todas as operações existentes sem um menu de texto.
struct WindowActionChoices: View {
    let operation: WindowOperation
    let onSelect: (WindowOperation) -> Void
    static let common: [WindowOperation] = [.leftHalf, .rightHalf, .maximize, .center, .topHalf, .bottomHalf]
    @State private var showsAll = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            choices(Self.common)
            if !Self.common.contains(operation) && !showsAll {
                Label(operation.displayName, systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(TicoBrand.Palette.primary)
            }
            DisclosureGroup("Mais posições e operações", isExpanded: $showsAll) {
                choices(WindowOperation.allCases.filter { !Self.common.contains($0) }).padding(.top, 8)
            }.font(.callout)
        }
    }

    private func choices(_ values: [WindowOperation]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 6)], spacing: 6) {
            ForEach(values, id: \.self) { value in
                Button { onSelect(value) } label: {
                    VStack(spacing: 6) {
                        WindowPlacementPreview(operation: value)
                        Text(Self.title(value)).font(.caption).lineLimit(2)
                            .multilineTextAlignment(.center).frame(height: 28)
                    }
                    .padding(8).frame(maxWidth: .infinity)
                    .background(operation == value ? TicoBrand.Palette.primary.opacity(0.12) : Color.primary.opacity(0.035),
                                in: .rect(cornerRadius: 8))
                    .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(operation == value ? TicoBrand.Palette.primary : .clear) }
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain).accessibilityLabel(value.displayName)
                .accessibilityAddTraits(operation == value ? [.isSelected] : [])
            }
        }
    }

    static func title(_ value: WindowOperation) -> String {
        switch value {
        case .leftHalf: "Metade esquerda"
        case .rightHalf: "Metade direita"
        case .topHalf: "Metade superior"
        case .bottomHalf: "Metade inferior"
        case .maximize: "Maximizar"
        case .center: "Centralizar"
        case .leftThird: "Terço esquerdo"
        case .centerThird: "Terço central"
        case .rightThird: "Terço direito"
        case .topLeftQuarter: "Superior esquerdo"
        case .topRightQuarter: "Superior direito"
        case .bottomLeftQuarter: "Inferior esquerdo"
        case .bottomRightQuarter: "Inferior direito"
        case .close: "Fechar"
        case .minimize: "Minimizar"
        case .restore: "Restaurar"
        case .nextDisplay: "Próxima tela"
        case .tileAll: "Organizar todas"
        }
    }
}
