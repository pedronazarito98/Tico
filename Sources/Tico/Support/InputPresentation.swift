import Foundation

/// Nomes e geometria lógica compartilhados pelo teclado visual e pelos resumos.
/// Códigos continuam sendo os valores macOS persistidos; rótulos seguem o layout ativo.
enum InputPresentation {
    static let modifierKeys: [UInt16: InputModifier] = [
        55: .command, 54: .command, 58: .option, 61: .option, 59: .control,
        62: .control, 56: .shift, 60: .shift, 57: .capsLock, 63: .function
    ]
    static let rows: [[UInt16]] = [
        [53,122,120,99,118,96,97,98,100,101,109,103,111],
        [50,18,19,20,21,23,22,26,28,25,29,27,24,51],
        [48,12,13,14,15,17,16,32,34,31,35,33,30,42],
        [57,0,1,2,3,5,4,38,40,37,41,39,36],
        [56,6,7,8,9,11,45,46,43,47,44,60],
        [63,59,58,55,49,54,61,123,125,124]
    ]
    static func label(_ code: UInt16, provider: any KeyboardLabelProviding = KeyboardLabelService()) -> String {
        if let modifier = modifierKeys[code] { return modifier.symbol }
        let special: [UInt16: String] = [49: "Espaço",36: "↩",48: "⇥",53: "esc",51: "⌫",
            123: "←",124: "→",125: "↓",126: "↑",117: "⌦",115: "Home",119: "End",116: "PgUp",121: "PgDn"]
        if let value = special[code] { return value }
        let functionKeys: [UInt16] = [122,120,99,118,96,97,98,100,101,109,103,111]
        if let index = functionKeys.firstIndex(of: code) { return "F\(index + 1)" }
        return provider.label(for: code) ?? "Tecla \(code)"
    }
    static func width(_ code: UInt16) -> Double {
        switch code {
        case 49: 5
        case 56,60: 2
        case 36,51,57: 1.7
        case 48,55,54: 1.4
        default: 1
        }
    }
    static func mouseLabel(_ button: Int) -> String {
        switch button {
        case 0: "Clique esquerdo"
        case 1: "Clique direito"
        case 2: "Clique do meio"
        default: "Botão lateral \(button - 2)"
        }
    }
}

extension TriggerDefinition {
    var requiresTrackpadCapture: Bool {
        switch self {
        case .keyboard, .mouseButton: false
        case .trackpad, .customTrackpad: true
        case let .sequence(sequence): sequence.steps.contains { $0.triggerDefinition.requiresTrackpadCapture }
        }
    }
}
