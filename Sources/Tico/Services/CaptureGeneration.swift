import Foundation

/// Token revogável compartilhado pelo MainActor, callback C e worker serial.
/// O lock protege somente validade e a seção curta de ingresso/gravação; motor
/// e UI conservam seus próprios owners. Invalidação precede stop/restart.
final class CaptureGeneration: @unchecked Sendable {
    private let lock = NSLock()
    private var active = true

    var isValid: Bool {
        lock.lock()
        defer { lock.unlock() }
        return active
    }

    func invalidate() {
        lock.lock()
        active = false
        lock.unlock()
    }

    /// Serializa append com a revogação: um callback já retirado não pode
    /// acrescentar frame à gravação iniciada pela geração seguinte.
    func whileValid<Value>(_ body: () -> Value) -> Value? {
        lock.lock()
        defer { lock.unlock() }
        guard active else { return nil }
        return body()
    }
}

