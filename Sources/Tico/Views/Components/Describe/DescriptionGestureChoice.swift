import Foundation

/// Movimentos disponíveis na frase guiada, além da gravação explícita.
enum DescriptionGestureChoice: String, CaseIterable, Identifiable {
    case left, right, up, down, tap, recorded
    var id: Self { self }
    var title: String {
        switch self {
        case .left: "Deslizar para a esquerda"
        case .right: "Deslizar para a direita"
        case .up: "Deslizar para cima"
        case .down: "Deslizar para baixo"
        case .tap: "Tocar"
        case .recorded: "Usar um gesto gravado"
        }
    }
    var symbol: String {
        switch self {
        case .left: "arrow.left"
        case .right: "arrow.right"
        case .up: "arrow.up"
        case .down: "arrow.down"
        case .tap: "hand.tap"
        case .recorded: "record.circle"
        }
    }
    var trackpadGesture: TrackpadGesture? {
        switch self {
        case .left: .swipeLeft
        case .right: .swipeRight
        case .up: .swipeUp
        case .down: .swipeDown
        case .tap: .tap
        case .recorded: nil
        }
    }
}
