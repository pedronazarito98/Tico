import ApplicationServices
import Foundation

/// Orçamento monotônico contado no ingresso, incluindo espera na fila. O lock
/// protege a revogação pelo watchdog; somente o owner AX chama configure().
/// Cancelar não interrompe IPC já iniciado, mas impede chamadas e resultados
/// posteriores. O timeout é reaplicado ao elemento usado em cada mensagem.
final class AXOperationBudget: @unchecked Sendable {
    private let lock = NSLock()
    private var revoked = false
    private let now: () -> TimeInterval
    private let deadline: TimeInterval

    init(now: (() -> TimeInterval)? = nil) {
        let origin = ContinuousClock.now
        let clock: () -> TimeInterval = now ?? {
            let value = origin.duration(to: .now).components
            return Double(value.seconds) + Double(value.attoseconds) / 1e18
        }
        self.now = clock
        deadline = clock() + 0.150
    }

    var remaining: TimeInterval {
        lock.lock(); defer { lock.unlock() }
        return revoked ? 0 : max(0, deadline - now())
    }
    var messageTimeout: Float? {
        let remaining = remaining
        return remaining > 0 ? Float(min(0.050, remaining)) : nil
    }
    func invalidate() { lock.lock(); revoked = true; lock.unlock() }

    func configure(_ element: AXUIElement) throws {
        guard let timeout = messageTimeout else { throw WindowControlError.operationFailed("tempo limite de Acessibilidade") }
        let result = AXUIElementSetMessagingTimeout(element, timeout)
        guard result == .success else { throw WindowControlError.operationFailed("AXError \(result.rawValue)") }
    }
}
