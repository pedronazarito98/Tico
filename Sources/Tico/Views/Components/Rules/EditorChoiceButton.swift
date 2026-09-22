import SwiftUI

/// Escolha explícita e acessível, compartilhada entre gestos, ações e contexto.
struct EditorChoiceButton: View {
    let title: String
    let symbol: String
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol).frame(width: 18)
                Text(title).font(.callout.weight(.medium)).lineLimit(2)
                Spacer(minLength: 0)
                if isSelected { Image(systemName: "checkmark").font(.caption.weight(.bold)) }
            }
            .padding(.horizontal, 12).padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? TicoBrand.Palette.primary.opacity(0.14) : Color.primary.opacity(0.04), in: .rect(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? TicoBrand.Palette.primary.opacity(0.65) : Color.primary.opacity(0.08))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? TicoBrand.Palette.primary : .primary)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
