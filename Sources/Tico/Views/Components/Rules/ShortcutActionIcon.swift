import SwiftUI

/// A mesma miniatura identifica a ação na busca, na biblioteca e no resumo.
struct ShortcutActionIcon: View {
    let action: ShortcutAction
    let applications: [ApplicationChoice]
    var size: CGFloat = 40

    var body: some View {
        Group {
            switch action {
            case let .openApplication(id), let .application(.bundleIdentifier(id), _):
                ApplicationIconView(application: applications.first { $0.id == id }, size: size)
            case let .window(_, operation):
                WindowPlacementPreview(operation: operation)
            default:
                Image(systemName: RuleActionKind(action: action).systemImage)
                    .font(.system(size: size * 0.6)).foregroundStyle(TicoBrand.Palette.primary)
            }
        }
        .frame(width: size + 16, height: size + 8)
        .background(TicoBrand.Palette.surface.opacity(0.7), in: .rect(cornerRadius: 9))
        .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(.quaternary) }
        .accessibilityHidden(true)
    }
}
