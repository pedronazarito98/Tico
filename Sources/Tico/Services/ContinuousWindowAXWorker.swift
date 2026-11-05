import Foundation

/// Somente o worker serial invoca esta fronteira. A implementação nativa retém
/// AXUIElement; testes substituem IPC por valores, sem tocar em apps do usuário.
protocol ContinuousWindowAXOperating: AnyObject, Sendable {
    func begin(sessionID: UUID, target: ContinuousWindowTarget, operation: ContinuousWindowOperation, budget: AXOperationBudget) throws
    func update(sessionID: UUID, progress: Double, curve: ContinuousResponseCurve, budget: AXOperationBudget) throws
    func finish(sessionID: UUID, restoring: Bool, budget: AXOperationBudget) throws
}

/// Mailbox por sessão: um dreno executa AX, enquanto o lock protege somente
/// comandos/valores. Changed substitui um único pending; terminais têm lugar
/// reservado. A fila nunca transporta um bloco ou uma Task por frame.
/// Paralelo com React: o valor pendente lembra uma ref com o valor mais recente;
/// a exclusão serial e a confirmação de IPC são contratos próprios de Swift.
final class ContinuousWindowAXWorker: @unchecked Sendable {
    private struct Update {
        let progress: Double
        let curve: ContinuousResponseCurve
        let budget: AXOperationBudget
    }
    private final class Session {
        let target: ContinuousWindowTarget
        let operation: ContinuousWindowOperation
        let completion = ContinuousWindowCompletion()
        var started = false
        var finishing = false
        var pending: Update?
        var terminal: ContinuousWindowOutcome?
        var failure: Error?
        init(target: ContinuousWindowTarget, operation: ContinuousWindowOperation) {
            self.target = target; self.operation = operation
        }
    }
    private enum Work {
        case begin(UUID, Session)
        case update(UUID, Session, Update)
        case finish(UUID, Session, ContinuousWindowOutcome)
    }
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "com.pedronazarito.Tico.continuous-window", qos: .userInitiated)
    private let backend: any ContinuousWindowAXOperating
    private let budgetFactory: @Sendable () -> AXOperationBudget
    private var sessions: [UUID: Session] = [:]
    private var order: [UUID] = []
    private var recent: [UUID: ContinuousWindowCompletion] = [:]
    private var recentOrder: [UUID] = []
    private var scheduled = false

    init(backend: any ContinuousWindowAXOperating, budgetFactory: @escaping @Sendable () -> AXOperationBudget) {
        self.backend = backend; self.budgetFactory = budgetFactory
    }

    func begin(sessionID: UUID, target: ContinuousWindowTarget, operation: ContinuousWindowOperation) throws {
        lock.lock(); defer { lock.unlock() }
        guard sessions[sessionID] == nil, recent[sessionID] == nil else { throw unavailable() }
        // Uma sessão ociosa no mesmo PID ainda possui o frame original. Encerrá-la
        // antes do novo begin impede que uma restauração tardia desfaça a nova.
        // Terminais já aceitos conservam sua ordem e conclusão no dreno.
        for prior in sessions.values where prior.target.processIdentifier == target.processIdentifier
            && prior.terminal == nil && !prior.finishing {
            prior.terminal = .cancelled
            prior.pending = nil
        }
        sessions[sessionID] = Session(target: target, operation: operation)
        order.append(sessionID)
        scheduleLocked()
    }

    func update(sessionID: UUID, progress: Double, curve: ContinuousResponseCurve) throws {
        let budget = budgetFactory()
        lock.lock(); defer { lock.unlock() }
        guard let session = sessions[sessionID], session.terminal == nil, session.failure == nil,
              !session.finishing else { throw unavailable() }
        session.pending = Update(progress: progress, curve: curve, budget: budget)
        scheduleLocked()
    }

    func finish(sessionID: UUID, outcome: ContinuousWindowOutcome) -> ContinuousWindowCompletion {
        lock.lock(); defer { lock.unlock() }
        guard let session = sessions[sessionID] else {
            if let completion = recent[sessionID] { return completion }
            let completion = ContinuousWindowCompletion()
            completion.finish(outcome == .cancelled ? .success(.cancelled) : .failure(unavailable()))
            return completion
        }
        // Depois de retirar o terminal, a sessão já não aceita novos comandos.
        // Cancelamento anterior a esse ponto vence commit e elimina o pending.
        if !session.finishing {
            if outcome == .cancelled { session.terminal = .cancelled; session.pending = nil }
            else if session.terminal == nil { session.terminal = .committed }
            scheduleLocked()
        }
        return session.completion
    }

    private func scheduleLocked() {
        guard !scheduled else { return }
        scheduled = true
        queue.async { [self] in drain() }
    }

    private func next() -> Work? {
        lock.lock(); defer { lock.unlock() }
        for id in order {
            guard let session = sessions[id] else { continue }
            if !session.started, session.terminal != .cancelled {
                session.started = true
                return .begin(id, session)
            }
            if session.terminal != .cancelled, let update = session.pending {
                session.pending = nil
                return .update(id, session, update)
            }
            if let terminal = session.terminal {
                session.finishing = true
                return .finish(id, session, terminal)
            }
        }
        scheduled = false
        return nil
    }

    private func drain() {
        while let work = next() {
            switch work {
            case let .begin(id, session):
                perform(session: session, budget: session.target.budget) {
                    try backend.begin(sessionID: id, target: session.target, operation: session.operation, budget: session.target.budget)
                }
            case let .update(id, session, update):
                perform(session: session, budget: update.budget) {
                    try backend.update(sessionID: id, progress: update.progress, curve: update.curve, budget: update.budget)
                }
            case let .finish(id, session, outcome):
                // Restaurar é uma operação de controle nova com seu próprio
                // prazo. O prazo do update vencido não pode suprimir a tentativa.
                let budget = budgetFactory()
                var failure = session.failure
                do {
                    try backend.finish(sessionID: id, restoring: outcome == .cancelled || failure != nil, budget: budget)
                    if budget.remaining <= 0 { throw unavailable() }
                } catch { if failure == nil { failure = error } }
                lock.lock()
                sessions[id] = nil
                order.removeAll { $0 == id }
                recent[id] = session.completion
                recentOrder.append(id)
                if recentOrder.count > 128 { recent.removeValue(forKey: recentOrder.removeFirst()) }
                lock.unlock()
                session.completion.finish(failure.map { .failure($0) } ?? .success(outcome))
            }
        }
    }

    private func perform(session: Session, budget: AXOperationBudget, _ operation: () throws -> Void) {
        do {
            guard budget.remaining > 0, session.target.isValid else { throw unavailable() }
            try operation()
            guard budget.remaining > 0, session.target.isValid else { throw unavailable() }
        } catch {
            lock.lock()
            if session.failure == nil { session.failure = error }
            session.pending = nil
            session.terminal = .cancelled
            lock.unlock()
        }
    }

    private func unavailable() -> WindowControlError {
        .operationFailed("sessão contínua encerrada, obsoleta ou fora do prazo")
    }
}
