import AppKit
import CoreGraphics
import Foundation

protocol InputActionPerforming {
    func sendKeyboardShortcut(keyCode: UInt16, modifiers: Set<InputModifier>) throws
    func setClipboard(_ text: String) throws
}

enum InputActionError: LocalizedError {
    case eventCreationFailed
    case clipboardFailed

    var errorDescription: String? {
        switch self {
        case .eventCreationFailed:
            "Não foi possível criar o atalho de teclado."
        case .clipboardFailed:
            "Não foi possível atualizar o clipboard."
        }
    }
}

final class InputActionService: InputActionPerforming {
    func sendKeyboardShortcut(keyCode: UInt16, modifiers: Set<InputModifier>) throws {
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else {
            throw InputActionError.eventCreationFailed
        }
        let flags = modifiers.cgEventFlags
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    func setClipboard(_ text: String) throws {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            throw InputActionError.clipboardFailed
        }
    }
}

private extension Set where Element == InputModifier {
    var cgEventFlags: CGEventFlags {
        reduce(into: CGEventFlags()) { flags, modifier in
            switch modifier {
            case .command: flags.insert(.maskCommand)
            case .option: flags.insert(.maskAlternate)
            case .control: flags.insert(.maskControl)
            case .shift: flags.insert(.maskShift)
            case .capsLock: flags.insert(.maskAlphaShift)
            case .function: flags.insert(.maskSecondaryFn)
            }
        }
    }
}

