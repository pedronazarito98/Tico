import Foundation

/// A fronteira possui o cancelamento de efeitos e a aceitação de novas entradas;
/// AppKit não precisa conhecer stores, workflows ou detalhes da captura.
@MainActor
protocol ApplicationTerminationPreparing: AnyObject {
    func suspendForTermination() -> Bool
    func drainForTermination() async throws
    func restoreAfterFailedTermination(wasAccepting: Bool)
    func presentTerminationFailure(_ error: Error)
}

enum ApplicationTerminationError: LocalizedError {
    case timedOut
    var errorDescription: String? {
        "Não foi possível concluir as operações em 2 segundos. O Tico permaneceu aberto; tente sair novamente."
    }
}

/// Um watchdog independente responde uma única vez mesmo se IO/cleanup não
/// cooperar com cancelamento. Nenhum task group aguarda a dependência retida
/// além do prazo. O token revoga somente a resposta tardia, nunca os ACKs de IO.
/// Paralelo com React: token de efeito invalida uma resposta antiga; a main
/// continua executando UI enquanto a fila de plataforma conclui seu trabalho.
@MainActor
final class ApplicationTerminationCoordinator {
    private let target: any ApplicationTerminationPreparing
    private var attempt: UUID?
    private var operation: Task<Void, Never>?
    private var watchdog: Task<Void, Never>?

    init(target: any ApplicationTerminationPreparing) { self.target = target }

    func request(onFailure: ((Error) -> Void)? = nil, reply: @escaping (Bool) -> Void) {
        guard attempt == nil else { return }
        let token = UUID()
        attempt = token
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(2))
        let wasAccepting = target.suspendForTermination()
        watchdog = Task { [weak self] in
            try? await clock.sleep(until: deadline)
            guard !Task.isCancelled else { return }
            self?.finish(token, error: ApplicationTerminationError.timedOut, wasAccepting: wasAccepting, onFailure: onFailure, reply: reply)
        }
        operation = Task { [weak self] in
            guard let self else { return }
            do {
                try await target.drainForTermination()
                finish(token, error: nil, wasAccepting: wasAccepting, onFailure: onFailure, reply: reply)
            } catch { finish(token, error: error, wasAccepting: wasAccepting, onFailure: onFailure, reply: reply) }
        }
    }

    private func finish(_ token: UUID, error: Error?, wasAccepting: Bool,
                        onFailure: ((Error) -> Void)?, reply: (Bool) -> Void) {
        guard attempt == token else { return }
        attempt = nil
        watchdog?.cancel(); watchdog = nil
        if error != nil {
            operation?.cancel()
            target.restoreAfterFailedTermination(wasAccepting: wasAccepting)
        }
        operation = nil
        reply(error == nil)
        // Primeiro libera o pedido AppKit pendente; apresentar UI não integra
        // o orçamento de cleanup/flush nem duplica o alert observável do target.
        if let error {
            if let onFailure { onFailure(error) }
            else { target.presentTerminationFailure(error) }
        }
    }
}
