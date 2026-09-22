import Foundation

/// Filtro de apresentação; não altera gatilhos nem a participação das regras.
enum RuleInputFilter: String, CaseIterable, Identifiable {
    case all = "Todos"
    case trackpad = "Trackpad"
    case keyboard = "Teclado"
    case mouse = "Mouse"

    var id: String { rawValue }

    func includes(_ trigger: TriggerDefinition) -> Bool {
        if self == .all { return true }
        if case let .sequence(sequence) = trigger {
            return sequence.steps.contains { includes($0.triggerDefinition) }
        }
        return switch (self, trigger) {
        case (.all, _), (.keyboard, .keyboard), (.mouse, .mouseButton),
             (.trackpad, .trackpad), (.trackpad, .customTrackpad): true
        default: false
        }
    }
}
