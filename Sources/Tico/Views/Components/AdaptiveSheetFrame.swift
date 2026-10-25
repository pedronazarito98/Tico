import SwiftUI

private struct PresentationAvailableSizeKey: EnvironmentKey {
    static let defaultValue = CGSize(width: 900, height: 640)
}

extension EnvironmentValues {
    /// Área útil oferecida pela janela que apresenta a sheet, sem consultar AppKit.
    var presentationAvailableSize: CGSize {
        get { self[PresentationAvailableSizeKey.self] }
        set { self[PresentationAvailableSizeKey.self] = newValue }
    }
}

/// O tamanho ideal organiza a apresentação, mas nunca supera a área da janela.
/// O conteúdo mantém seu próprio ScrollView e rodapé; não é reduzido por escala.
/// Paralelo com React: equivale a limitar um modal pelo container, com overflow
/// no conteúdo, mantendo o mesmo formulário montado ao redimensionar.
private struct AdaptiveSheetFrame: ViewModifier {
    @Environment(\.presentationAvailableSize) private var availableSize
    let idealWidth: CGFloat
    let idealHeight: CGFloat

    func body(content: Content) -> some View {
        content.frame(
            width: max(1, min(idealWidth, availableSize.width)),
            height: max(1, min(idealHeight, availableSize.height))
        )
    }
}

extension View {
    func adaptiveSheetFrame(idealWidth: CGFloat, idealHeight: CGFloat) -> some View {
        modifier(AdaptiveSheetFrame(idealWidth: idealWidth, idealHeight: idealHeight))
    }
}
