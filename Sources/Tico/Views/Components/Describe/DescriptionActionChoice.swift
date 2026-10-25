import Foundation

/// Resultados da frase guiada; detalhes permanecem no rascunho efêmero.
enum DescriptionActionChoice: String, CaseIterable, Identifiable {
    case left, right, maximize, center, reopenTab, openApplication, openURL
    var id: Self { self }
    var title: String {
        switch self {
        case .left: "Colocar a janela à esquerda"
        case .right: "Colocar a janela à direita"
        case .maximize: "Ampliar a janela"
        case .center: "Centralizar a janela"
        case .reopenTab: "Reabrir a última aba"
        case .openApplication: "Abrir um aplicativo"
        case .openURL: "Abrir um site"
        }
    }
    var symbol: String {
        switch self {
        case .left: "rectangle.lefthalf.inset.filled"
        case .right: "rectangle.righthalf.inset.filled"
        case .maximize: "arrow.up.left.and.arrow.down.right"
        case .center: "rectangle.center.inset.filled"
        case .reopenTab: "arrow.uturn.backward"
        case .openApplication: "app"
        case .openURL: "link"
        }
    }
}
