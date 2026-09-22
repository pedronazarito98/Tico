import SwiftUI

/// Carrega somente o ícone visível. A identidade da URL acompanha a troca de app;
/// o estado pertence à apresentação e nunca entra na regra persistida.
struct ApplicationIconView: View {
    let application: ApplicationChoice?
    var size: CGFloat = 36
    @State private var icon: Image?

    var body: some View {
        Group {
            if let icon {
                icon.resizable().interpolation(.high).scaledToFit()
            } else {
                Image(systemName: "app.dashed").resizable().scaledToFit()
                    .foregroundStyle(.secondary).padding(size * 0.15)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
        .task(id: application?.applicationURL) {
            icon = ApplicationIconService.image(for: application?.applicationURL)
        }
    }
}
