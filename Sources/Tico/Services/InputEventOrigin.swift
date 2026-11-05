import CoreGraphics

/// Marca funcional imutável compartilhada pelo emissor e pelas capturas.
/// Vale somente nesta vida do processo; não é credencial, autenticação ou log.
enum InputEventOrigin {
    private static let marker = Int64.random(in: 1...Int64.max)

    static func mark(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: marker)
    }

    static func isOwn(_ event: CGEvent) -> Bool {
        event.getIntegerValueField(.eventSourceUserData) == marker
    }
}
