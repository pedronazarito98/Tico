import Carbon
import Foundation

protocol KeyboardLabelProviding {
    func label(for keyCode: UInt16) -> String?
}

/// Traduz apenas a apresentação da tecla usando o layout atual do macOS.
/// Não captura eventos. A fonte copiada e o CFData permanecem vivos durante a
/// tradução síncrona; nenhum ponteiro ou estado de dead key escapa desta chamada.
struct KeyboardLabelService: KeyboardLabelProviding {
    func label(for keyCode: UInt16) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else { return nil }
        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        var deadKeyState: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 8)
        let status = withExtendedLifetime((source, data)) {
            UCKeyTranslate(layout, keyCode, UInt16(kUCKeyActionDisplay), 0,
                UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeyState,
                characters.count, &length, &characters)
        }
        guard status == noErr, length > 0 else { return nil }
        let label = String(utf16CodeUnits: characters, count: length)
        guard !label.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { return nil }
        return label.uppercased()
    }
}
