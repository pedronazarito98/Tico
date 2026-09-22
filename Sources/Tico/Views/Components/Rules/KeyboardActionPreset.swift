import Foundation

/// Mesmas combinações na galeria e no editor. São rascunhos de ações de teclado;
/// escolher uma opção não envia eventos ao sistema.
enum KeyboardActionPreset: String, CaseIterable, Identifiable {
    case copy, paste, undo, selectAll
    var id: Self { self }

    var title: String {
        switch self {
        case .copy: "Copiar seleção"
        case .paste: "Colar"
        case .undo: "Desfazer"
        case .selectAll: "Selecionar tudo"
        }
    }
    var keyCode: UInt16 {
        switch self {
        case .copy: 8
        case .paste: 9
        case .undo: 6
        case .selectAll: 0
        }
    }
    var symbol: String {
        switch self {
        case .copy: "doc.on.doc"
        case .paste: "doc.on.clipboard"
        case .undo: "arrow.uturn.backward"
        case .selectAll: "selection.pin.in.out"
        }
    }
    var action: ShortcutAction { .keyboardShortcut(keyCode: keyCode, modifiers: [.command]) }
}
