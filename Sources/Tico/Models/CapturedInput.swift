import Foundation

/// Entrada transitória: manutenção de flags não é uma nova pressão de tecla.
/// Não é Codable; regras e eventos persistidos mantêm o formato atual.
/// Paralelo com React: união discriminada antes do reducer de sequências.
enum CapturedInput: Equatable, Sendable {
    case activation(InputEventDescriptor)
    case modifierChange(ModifierChange)

    var event: InputEventDescriptor? {
        switch self {
        case let .activation(event): event
        case let .modifierChange(change): change.event
        }
    }

    var modifiers: Set<InputModifier> {
        switch self {
        case let .activation(event): event.modifiers
        case let .modifierChange(change): change.modifiers
        }
    }

    var isModifierChange: Bool {
        if case .modifierChange = self { return true }
        return false
    }
}

/// keyCode ausente representa ressincronização, sem intenção de acionar regra.
struct ModifierChange: Equatable, Sendable {
    var keyCode: UInt16?
    var modifiers: Set<InputModifier>
    var timestamp: Date

    var event: InputEventDescriptor? {
        keyCode.map { .keyboard(keyCode: $0, modifiers: modifiers, timestamp: timestamp) }
    }
}
