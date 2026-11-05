import Foundation

enum ContinuousWindowOutcome: Sendable { case committed, cancelled }

/// Confirmação de um comando terminal já aceito, separada do agendamento.
/// O lock protege resultado/continuations; não há AX nem Task por atualização.
/// Cancelar a espera não confirma cleanup: o owner continua aguardando o IPC
/// em voo antes de publicar um único resultado e liberar seus handles.
final class ContinuousWindowCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<ContinuousWindowOutcome, Error>?
    private var waiters: [CheckedContinuation<ContinuousWindowOutcome, Error>] = []

    static func resolved(_ outcome: ContinuousWindowOutcome) -> ContinuousWindowCompletion {
        let completion = ContinuousWindowCompletion()
        completion.finish(.success(outcome))
        return completion
    }

    func wait() async throws -> ContinuousWindowOutcome {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if let result { lock.unlock(); continuation.resume(with: result) }
            else { waiters.append(continuation); lock.unlock() }
        }
    }

    func finish(_ result: Result<ContinuousWindowOutcome, Error>) {
        lock.lock()
        guard self.result == nil else { lock.unlock(); return }
        self.result = result
        let waiters = waiters
        self.waiters.removeAll()
        lock.unlock()
        for waiter in waiters { waiter.resume(with: result) }
    }
}
