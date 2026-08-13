import Foundation

enum TicoSection: String, CaseIterable, Identifiable {
    case overview
    case permissions
    case rules
    case profiles
    case library
    case laboratory
    case metrics
    case log

    var id: Self { self }

    var title: String {
        switch self {
        case .overview: "Visão geral"
        case .permissions: "Permissões"
        case .rules: "Regras"
        case .profiles: "Perfis"
        case .library: "Biblioteca"
        case .laboratory: "Laboratório"
        case .metrics: "Métricas"
        case .log: "Log"
        }
    }

    var systemImage: String {
        switch self {
        case .overview: "rectangle.grid.2x2"
        case .permissions: "lock.shield"
        case .rules: "bolt.badge.clock"
        case .profiles: "person.2.circle"
        case .library: "square.stack.3d.up"
        case .laboratory: "waveform.path.ecg.rectangle"
        case .metrics: "chart.xyaxis.line"
        case .log: "list.bullet.rectangle"
        }
    }
}
