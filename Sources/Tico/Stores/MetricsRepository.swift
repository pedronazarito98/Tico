import Foundation

@MainActor
protocol MetricsWriteScheduling {
    func schedule(after seconds: TimeInterval, action: @escaping @MainActor () -> Void) -> () -> Void
}

@MainActor
struct MetricsWriteScheduler: MetricsWriteScheduling {
    func schedule(after seconds: TimeInterval, action: @escaping @MainActor () -> Void) -> () -> Void {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(seconds))
        let task = Task {
            try? await clock.sleep(until: deadline)
            guard !Task.isCancelled else { return }
            action()
        }
        return { task.cancel() }
    }
}

/// Coordena o ingresso síncrono e a confirmação do writer; não executa IO.
/// Um record substitui a única pendência sem criar Task. Barreiras explícitas
/// selam a revisão anterior; somente elas podem reservar snapshots adicionais.
/// Paralelo com React: a pendência se aproxima de uma ref com o valor recente,
/// mas a durabilidade depende do ACK serial, não de uma atualização de estado.
@MainActor
final class MetricsRepository {
    private struct Snapshot {
        var revision: UInt64
        var clearGeneration: UInt64
        var events: [GestureMetricEvent]
    }
    private enum Work {
        case write(Snapshot)
        case clear(empty: Snapshot, previous: Snapshot, CheckedContinuation<Void, Error>)
        case flush(CheckedContinuation<Void, Error>)
        case export(URL, [GestureMetricEvent], CheckedContinuation<Void, Error>)
    }
    private let storage: MetricsFileStorage
    private let scheduler: any MetricsWriteScheduling
    private let maximumEventCount: Int
    private var current: Snapshot
    private var pending: Snapshot?
    private var work: [Work] = []
    private var writer: Task<Void, Never>?
    private var cancelTimer: (() -> Void)?
    private var lastFailure: Error?
    private var persistenceFailure: Error?
    private var durableEvents: [GestureMetricEvent] = []
    private var revision: UInt64 = 0
    private(set) var durableRevision: UInt64 = 0
    var onChange: (() -> Void)?
    var events: [GestureMetricEvent] { current.events }
    var lastError: String? { lastFailure?.localizedDescription }
    var hasPendingSnapshot: Bool { pending != nil }

    init(fileURL: URL, maximumEventCount: Int, fileManager: FileManager = .default,
         scheduler: (any MetricsWriteScheduling)? = nil) {
        self.maximumEventCount = maximumEventCount
        self.scheduler = scheduler ?? MetricsWriteScheduler()
        storage = MetricsFileStorage(fileURL: fileURL, fileManager: fileManager)
        do {
            current = Snapshot(revision: 0, clearGeneration: 0,
                events: Array(try storage.load().prefix(maximumEventCount)))
        } catch {
            current = Snapshot(revision: 0, clearGeneration: 0, events: [])
            lastFailure = error
        }
        durableEvents = current.events
    }

    func record(_ event: GestureMetricEvent) {
        revision &+= 1
        current.revision = revision
        current.events.insert(event, at: 0)
        current.events = Array(current.events.prefix(maximumEventCount))
        pending = current
        // A janela começa na primeira pendência e nunca é adiada pela rajada.
        if writer == nil, cancelTimer == nil {
            cancelTimer = scheduler.schedule(after: 0.250) { [weak self] in
                self?.cancelTimer = nil
                self?.startWriter()
            }
        }
    }

    func clear() async throws {
        sealPending()
        let previous = current
        revision &+= 1
        current = Snapshot(revision: revision, clearGeneration: revision, events: [])
        onChange?()
        try await withCheckedThrowingContinuation { continuation in
            work.append(.clear(empty: current, previous: previous, continuation))
            startWriter()
        }
    }

    func flush() async throws {
        sealPending()
        try await withCheckedThrowingContinuation { continuation in
            work.append(.flush(continuation))
            startWriter()
        }
    }

    func export(to url: URL, selection: [GestureMetricEvent]) async throws {
        sealPending()
        try await withCheckedThrowingContinuation { continuation in
            work.append(.export(url, selection, continuation))
            startWriter()
        }
    }

    private func sealPending() {
        cancelTimer?(); cancelTimer = nil
        if let pending { work.append(.write(pending)); self.pending = nil }
    }

    private func startWriter() {
        guard writer == nil else { return }
        cancelTimer?(); cancelTimer = nil
        writer = Task { [self] in
            var canWritePending = true
            while true {
                let next: Work
                if !work.isEmpty { next = work.removeFirst() }
                else if canWritePending, let snapshot = pending {
                    pending = nil; next = .write(snapshot)
                } else { break }
                switch next {
                case let .write(snapshot):
                    do {
                        try await storage.write(snapshot.events)
                        durableRevision = snapshot.revision
                        durableEvents = snapshot.events
                        if let pending, pending.revision <= snapshot.revision { self.pending = nil }
                        canWritePending = true
                        persistenceFailure = nil
                        lastFailure = nil
                    } catch {
                        lastFailure = error
                        persistenceFailure = error
                        // Não faz retry infinito. A revisão recente já contém os
                        // eventos antigos; clear posterior é uma intenção distinta.
                        if pending == nil, current.clearGeneration == snapshot.clearGeneration { pending = current }
                        canWritePending = pending.map { $0.revision > snapshot.revision } ?? false
                    }
                case let .clear(empty, previous, continuation):
                    do {
                        try await storage.write([])
                        durableRevision = empty.revision
                        durableEvents = []
                        canWritePending = true
                        persistenceFailure = nil
                        lastFailure = nil
                        continuation.resume()
                    } catch {
                        restoreFailedClear(empty, previous: previous)
                        lastFailure = error
                        canWritePending = pending.map { $0.revision > empty.revision } ?? false
                        continuation.resume(throwing: error)
                    }
                case let .flush(continuation):
                    if let persistenceFailure { continuation.resume(throwing: persistenceFailure) }
                    else { continuation.resume() }
                case let .export(url, selection, continuation):
                    do {
                        if let persistenceFailure { throw persistenceFailure }
                        try await storage.export(to: url, events: selection)
                        continuation.resume()
                    } catch { lastFailure = error; continuation.resume(throwing: error) }
                }
                onChange?()
            }
            writer = nil
        }
    }

    /// Rebase também as revisões já seladas depois do clear. Restaurar só a UI
    /// permitiria que a próxima gravação eliminasse os eventos recuperados.
    private func restoreFailedClear(_ empty: Snapshot, previous: Snapshot) {
        func restored(_ snapshot: Snapshot) -> Snapshot {
            guard snapshot.clearGeneration == empty.clearGeneration else { return snapshot }
            let ids = Set(snapshot.events.map(\.id))
            return Snapshot(revision: snapshot.revision, clearGeneration: previous.clearGeneration,
                events: Array((snapshot.events + previous.events.filter { !ids.contains($0.id) }).prefix(maximumEventCount)))
        }
        current = restored(current)
        pending = pending.map(restored)
        if current.events == durableEvents {
            persistenceFailure = nil
        } else if pending == nil, current.clearGeneration == previous.clearGeneration {
            pending = current
        }
        work = work.map { item in
            switch item {
            case let .write(snapshot): return .write(restored(snapshot))
            case let .clear(next, rollback, continuation): return .clear(empty: next, previous: restored(rollback), continuation)
            default: return item
            }
        }
    }
}
