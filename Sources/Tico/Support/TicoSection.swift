import Foundation

enum TicoSection: String, CaseIterable, Identifiable {
    case explore
    case scenes
    case gestureMap
    case activity
    case permissions
    case rules
    case library
    case laboratory
    case log

    /// Preserva a restauração de janelas e comandos das duas telas substituídas.
    /// A seção removida de perfis volta para a biblioteca de atalhos.
    static func restored(from value: String) -> Self {
        if value == "overview" || value == "metrics" { return .activity }
        return Self(rawValue: value) ?? .rules
    }

    var id: Self { self }

    var title: String {
        switch self {
        case .explore: "Explorar"
        case .scenes: "Cenas"
        case .gestureMap: "Mapa de gestos"
        case .activity: "Atividade"
        case .permissions: "Permissões"
        case .rules: "Meus atalhos"
        case .library: "Modelos e gestos"
        case .laboratory: "Laboratório"
        case .log: "Log"
        }
    }

    var systemImage: String {
        switch self {
        case .explore: "sparkles"
        case .scenes: "rectangle.3.group"
        case .gestureMap: "hand.draw"
        case .activity: "clock.arrow.circlepath"
        case .permissions: "lock.shield"
        case .rules: "bolt.badge.clock"
        case .library: "square.stack.3d.up"
        case .laboratory: "waveform.path.ecg.rectangle"
        case .log: "list.bullet.rectangle"
        }
    }
}
