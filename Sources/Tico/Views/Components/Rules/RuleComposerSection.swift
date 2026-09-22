import SwiftUI

/// Mantém o resumo visível enquanto revela somente a escolha que está sendo editada.
/// O conteúdo permanece montado para preservar rascunhos locais ao recolher o bloco.
struct RuleComposerSection<Content: View>: View {
    let number: String
    let title: String
    let summary: String
    let symbol: String
    let isExpanded: Bool
    let onToggle: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 14) {
                    Image(systemName: symbol)
                        .font(.title3)
                        .foregroundStyle(TicoBrand.Palette.primary)
                        .frame(width: 40, height: 40)
                        .background(TicoBrand.Palette.primary.opacity(0.1), in: .rect(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(number) · \(title)").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        Text(summary).font(.body.weight(.medium)).foregroundStyle(.primary)
                            .lineLimit(2).multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 8)
                    Text(isExpanded ? "Recolher" : "Editar").font(.caption).foregroundStyle(.secondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }.padding(18).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title): \(summary)")
            .accessibilityValue(isExpanded ? "Expandido" : "Recolhido")
            .accessibilityIdentifier("tico.composer.section.\(number)")

            VStack(alignment: .leading, spacing: 16) {
                Divider()
                content
            }
            .padding(.horizontal, 18).padding(.bottom, isExpanded ? 18 : 0)
            .frame(height: isExpanded ? nil : 0, alignment: .top)
            .clipped().disabled(!isExpanded)
            .accessibilityElement(children: isExpanded ? .contain : .ignore)
            .accessibilityHidden(!isExpanded)
        }
        .background(.quaternary.opacity(isExpanded ? 0.45 : 0.22), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(isExpanded ? TicoBrand.Palette.primary.opacity(0.45) : Color.primary.opacity(0.08), lineWidth: 1)
                .allowsHitTesting(false)
        }
    }
}
