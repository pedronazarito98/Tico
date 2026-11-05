import Foundation
import XCTest
@testable import Tico

/// Casos CAP-07.F/G com destinos temporários; nunca leem o histórico da instalação.
@MainActor
final class PersistencePipelineTests: XCTestCase {
    func testHistoryWritesOffMainAndPublishesOnlyDurableEntries() async throws {
        let files = PersistenceFileManager()
        let url = temporaryURL("events.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = EventLogStore(fileURL: url, fileManager: files)
        let entry = entry("primeiro")
        try await store.record(entry)
        XCTAssertEqual(files.writeThreads, [false], "Encode/write deve executar fora da main.")
        XCTAssertEqual(store.entries, [entry])
        XCTAssertEqual(EventLogStore(fileURL: url).entries, [entry])
    }

    func testHistoryRecordClearAndLimitSurviveReload() async throws {
        let url = temporaryURL("events.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = EventLogStore(fileURL: url, maximumEntryCount: 2)
        let first = entry("one"), second = entry("two"), third = entry("three")
        try await store.record(first)
        try await store.record(second)
        try await store.record(third)
        XCTAssertEqual(EventLogStore(fileURL: url, maximumEntryCount: 2).entries, [third, second])
        try await store.clear()
        try await store.record(first)
        XCTAssertEqual(EventLogStore(fileURL: url).entries, [first])
        let document = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual(document["version"] as? Int, 2)
    }

    func testHistoryWriteAndClearFailuresPreserveLastDurableCollection() async throws {
        let files = PersistenceFileManager()
        let url = temporaryURL("events.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = EventLogStore(fileURL: url, fileManager: files)
        let first = entry("durável"), failed = entry("pendente")
        try await store.record(first)
        files.failWrites = true
        do { try await store.record(failed); XCTFail("A escrita deveria falhar") } catch {}
        XCTAssertEqual(store.entries, [first])
        XCTAssertNotNil(store.lastError)
        do { try await store.clear(); XCTFail("A limpeza deveria falhar") } catch {}
        XCTAssertEqual(store.entries, [first])
        XCTAssertEqual(EventLogStore(fileURL: url).entries, [first])
        XCTAssertNotNil(store.lastError)
    }

    func testConcurrentHistoryMutationsUseLastDurableCollection() async throws {
        let files = PersistenceFileManager()
        let url = temporaryURL("events.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = EventLogStore(fileURL: url, fileManager: files)
        let first = entry("first"), second = entry("second"), last = entry("last")
        files.blockNextWrite = true
        let a = Task { try await store.record(first) }
        await waitUntil { files.blocked }
        XCTAssertTrue(store.entries.isEmpty, "Enfileirar não confirma durabilidade")
        var mainResponded = false
        Task { @MainActor in mainResponded = true }
        await waitUntil { mainResponded }
        let b = Task { try await store.record(second) }
        await Task.yield()
        files.release()
        try await a.value; try await b.value
        XCTAssertEqual(store.entries, [second, first])
        let clear = Task { try await store.clear() }
        await Task.yield()
        let c = Task { try await store.record(last) }
        try await clear.value; try await c.value
        XCTAssertEqual(EventLogStore(fileURL: url).entries, [last])
        XCTAssertEqual(Set(files.writeThreads), [false])
    }

    func testFailedHistoryRecordIsRetriedByFlushWithoutRetryingFailedClear() async throws {
        let files = PersistenceFileManager()
        let url = temporaryURL("events.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = EventLogStore(fileURL: url, fileManager: files)
        let first = entry("old"), second = entry("pending")
        try await store.record(first)
        files.failWrites = true
        do { try await store.record(second); XCTFail("Falha esperada") } catch {}
        do { try await store.clear(); XCTFail("Falha esperada") } catch {}
        files.failWrites = false
        try await store.flush()
        XCTAssertEqual(store.entries, [second, first])
        XCTAssertEqual(EventLogStore(fileURL: url).entries, [second, first])
        XCTAssertNil(store.lastError)
    }

    func testHistoryLateAcknowledgementCannotReplaceNewerStateOrClearNewerError() async throws {
        let repository = ReorderedHistoryRepository()
        let store = EventLogStore(repository: repository)
        let first = entry("first"), second = entry("second")
        let a = Task { try await store.record(first) }
        await waitUntil { repository.count == 1 }
        let b = Task { try await store.record(second) }
        await waitUntil { repository.count == 2 }
        repository.succeed(1, entries: [second, first])
        try await b.value
        repository.succeed(0, entries: [first])
        try await a.value
        XCTAssertEqual(store.entries, [second, first])
        let c = Task { try await store.record(first) }
        await waitUntil { repository.count == 3 }
        let d = Task { try await store.clear() }
        await waitUntil { repository.count == 4 }
        repository.fail(3)
        do { try await d.value; XCTFail("Falha esperada") } catch {}
        repository.succeed(2, entries: [first, second])
        try await c.value
        XCTAssertEqual(store.entries, [first, second])
        XCTAssertNotNil(store.lastError, "Sucesso antigo não apaga erro recente")
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<500 where !condition() { try? await Task.sleep(for: .milliseconds(1)) }
        XCTAssertTrue(condition(), "A fronteira controlada não progrediu")
    }

    func testMetricsBurstIsGroupedAndWriteRunsOffMain() async throws {
        let files = PersistenceFileManager()
        let url = temporaryURL("metrics.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = MetricsStore(fileURL: url, maximumEventCount: 10, fileManager: files)
        for index in 0..<100 { store.record(GestureMetricEvent(occurredAt: Date(timeIntervalSince1970: 123), ruleName: "Item \(index)", outcome: .success)) }
        XCTAssertTrue(files.writeThreads.isEmpty, "Uma rajada deve permanecer pending até a janela de agrupamento")
        try await store.exportCSV(to: url.deletingLastPathComponent().appendingPathComponent("export.csv"))
        XCTAssertEqual(files.writeThreads, [false])
        XCTAssertEqual(MetricsStore(fileURL: url).events.map(\.ruleName), (90..<100).reversed().map { "Item \($0)" })
    }

    func testMetricsTimerStartsAtFirstPendingAndBurstKeepsOnlyLatestSnapshot() async throws {
        let files = PersistenceFileManager(), scheduler = ManualMetricsScheduler()
        let url = temporaryURL("metrics.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = MetricsStore(fileURL: url, maximumEventCount: 10, fileManager: files, scheduler: scheduler)
        files.blockNextWrite = true
        store.record(GestureMetricEvent(occurredAt: Date(timeIntervalSince1970: 123), ruleName: "before", outcome: .success))
        for index in 0..<20 { store.record(GestureMetricEvent(occurredAt: Date(timeIntervalSince1970: 123), ruleName: "early \(index)", outcome: .success)) }
        XCTAssertEqual(scheduler.delays, [0.250], "O timer não reinicia com cada evento")
        scheduler.fire()
        await waitUntil { files.blocked }
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), "Agendar não é persistir")
        for index in 0..<1_000 { store.record(GestureMetricEvent(occurredAt: Date(timeIntervalSince1970: 123), ruleName: "late \(index)", outcome: .failure)) }
        XCTAssertEqual(files.writeThreads, [false])
        XCTAssertEqual(scheduler.delays, [0.250])
        files.release()
        try await store.flush()
        XCTAssertEqual(files.writeThreads, [false, false], "A rajada durante IO vira uma única escrita posterior")
        XCTAssertEqual(MetricsStore(fileURL: url).events.map(\.ruleName), (990..<1_000).reversed().map { "late \($0)" })
    }

    func testMetricsClearBarrierCannotBeUndoneByOlderWrite() async throws {
        let files = PersistenceFileManager(), scheduler = ManualMetricsScheduler()
        let url = temporaryURL("metrics.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = MetricsStore(fileURL: url, fileManager: files, scheduler: scheduler)
        files.blockNextWrite = true
        store.record(GestureMetricEvent(occurredAt: Date(timeIntervalSince1970: 123), ruleName: "old", outcome: .success))
        scheduler.fire()
        await waitUntil { files.blocked }
        let clear = Task { try await store.clear() }
        await waitUntil { store.events.isEmpty }
        let new = GestureMetricEvent(occurredAt: Date(timeIntervalSince1970: 123), ruleName: "new", outcome: .failure)
        store.record(new)
        let flush = Task { try await store.flush() }
        await Task.yield()
        files.release()
        try await clear.value; try await flush.value
        XCTAssertEqual(store.events, [new])
        XCTAssertEqual(MetricsStore(fileURL: url).events, [new])
        XCTAssertNil(store.lastError)
    }

    func testFailedMetricsClearRebasesNewRecordsAndAlreadyQueuedFlush() async throws {
        let files = PersistenceFileManager()
        let url = temporaryURL("metrics.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = MetricsStore(fileURL: url, fileManager: files)
        let old = GestureMetricEvent(occurredAt: Date(timeIntervalSince1970: 123), ruleName: "old", outcome: .success)
        let new = GestureMetricEvent(occurredAt: Date(timeIntervalSince1970: 123), ruleName: "new", outcome: .failure)
        store.record(old); try await store.flush()
        files.blockNextWrite = true; files.failWrites = true
        let clear = Task { try await store.clear() }
        await waitUntil { files.blocked }
        store.record(new)
        let flush = Task { try await store.flush() }
        await Task.yield()
        files.failWrites = false; files.release()
        do { try await clear.value; XCTFail("A limpeza deveria falhar") } catch {}
        try await flush.value
        XCTAssertEqual(store.events, [new, old])
        XCTAssertEqual(MetricsStore(fileURL: url).events, [new, old], "O snapshot posterior precisa incluir o rollback")
    }

    func testFailedMetricsClearCanFlushRestoredEventsAndPreservesErrorUntilRetry() async throws {
        let files = PersistenceFileManager()
        let url = temporaryURL("metrics.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = MetricsStore(fileURL: url, fileManager: files)
        let old = GestureMetricEvent(occurredAt: Date(timeIntervalSince1970: 123), ruleName: "old", outcome: .success)
        store.record(old)
        files.failWrites = true
        do { try await store.clear(); XCTFail("Falha esperada") } catch {}
        XCTAssertEqual(store.events, [old])
        XCTAssertNotNil(store.lastError)
        files.failWrites = false
        try await store.flush()
        XCTAssertEqual(MetricsStore(fileURL: url).events, [old])
        XCTAssertNil(store.lastError)
    }

    func testMetricsFailedWriteKeepsLatestEventsAndExportUsesImmutableSelection() async throws {
        let files = PersistenceFileManager()
        let url = temporaryURL("metrics.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = MetricsStore(fileURL: url, fileManager: files)
        let old = GestureMetricEvent(occurredAt: Date(timeIntervalSince1970: 123), ruleName: "selected", outcome: .success)
        store.record(old); files.failWrites = true
        do { try await store.flush(); XCTFail("Falha esperada") } catch {}
        XCTAssertEqual(store.events, [old]); XCTAssertNotNil(store.lastError)
        files.failWrites = false; files.blockNextWrite = true
        let csv = url.deletingLastPathComponent().appendingPathComponent("selection.csv")
        let export = Task { try await store.exportCSV(to: csv, events: [old]) }
        await waitUntil { files.blocked }
        let new = GestureMetricEvent(occurredAt: Date(timeIntervalSince1970: 123), ruleName: "after", outcome: .failure)
        store.record(new)
        files.release(); try await export.value; try await store.flush()
        XCTAssertEqual(MetricsStore(fileURL: url).events, [new, old])
        let text = try String(contentsOf: csv, encoding: .utf8)
        XCTAssertTrue(text.contains("selected")); XCTAssertFalse(text.contains("after"))
        XCTAssertEqual(text.split(separator: "\n").count, 2)
    }

    func testExportFailureDoesNotBlockFlushOfAlreadyDurableMetrics() async throws {
        let url = temporaryURL("metrics.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = MetricsStore(fileURL: url)
        let event = GestureMetricEvent(occurredAt: Date(timeIntervalSince1970: 123), ruleName: "durable", outcome: .success)
        store.record(event); try await store.flush()
        do {
            try await store.exportCSV(to: url.appendingPathComponent("cannot-export.csv"))
            XCTFail("Destino inválido deve falhar")
        } catch {}
        XCTAssertNotNil(store.lastError)
        try await store.flush()
        XCTAssertEqual(MetricsStore(fileURL: url).events, [event])
        XCTAssertNotNil(store.lastError, "Flush não apaga o erro distinto de exportação")
    }

    func testFailedClearOfDurableMetricsDoesNotRepeatClearOnFlush() async throws {
        let files = PersistenceFileManager()
        let url = temporaryURL("metrics.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = MetricsStore(fileURL: url, fileManager: files)
        let event = GestureMetricEvent(occurredAt: Date(timeIntervalSince1970: 123), ruleName: "durable", outcome: .success)
        store.record(event); try await store.flush()
        files.failWrites = true
        do { try await store.clear(); XCTFail("Falha esperada") } catch {}
        XCTAssertEqual(store.events, [event])
        try await store.flush()
        XCTAssertEqual(MetricsStore(fileURL: url).events, [event])
        XCTAssertEqual(files.writeThreads.count, 2, "Flush não precisa regravar uma coleção já durável")
        XCTAssertNotNil(store.lastError)
    }

    func testMetricsNewRevisionAfterFailureAndSuccessfulBarrierKeepsDrainingWithoutAnotherIngress() async throws {
        let files = PersistenceFileManager(), scheduler = ManualMetricsScheduler()
        let url = temporaryURL("metrics.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = MetricsStore(fileURL: url, fileManager: files, scheduler: scheduler)
        let a = GestureMetricEvent(occurredAt: Date(timeIntervalSince1970: 123), ruleName: "A", outcome: .success)
        let b = GestureMetricEvent(occurredAt: Date(timeIntervalSince1970: 124), ruleName: "B", outcome: .success)
        let c = GestureMetricEvent(occurredAt: Date(timeIntervalSince1970: 125), ruleName: "C", outcome: .success)
        files.failWrites = true; files.blockNextWrite = true
        store.record(a); scheduler.fire()
        await waitUntil { files.blocked }
        store.record(b)
        let barrier = Task { try await store.flush() }
        await Task.yield()
        files.failWrites = false; files.blockNextWrite = true; files.release()
        await waitUntil { files.writeThreads.count == 2 && files.blocked }
        store.record(c)
        files.release()
        try await barrier.value
        await waitUntil { files.writeThreads.count == 3 }
        // Sem um novo flush/record: a revisão C deve progredir por si mesma.
        await waitUntil { MetricsStore(fileURL: url).events.count == 3 }
        XCTAssertEqual(MetricsStore(fileURL: url).events, [c, b, a])
        XCTAssertNil(store.lastError)
    }

    func testMetricsNewPendingRevisionGetsOneAttemptAfterOlderWriteFails() async throws {
        let files = PersistenceFileManager(), scheduler = ManualMetricsScheduler()
        let url = temporaryURL("metrics.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = MetricsStore(fileURL: url, fileManager: files, scheduler: scheduler)
        let a = GestureMetricEvent(occurredAt: Date(timeIntervalSince1970: 123), ruleName: "A", outcome: .success)
        let b = GestureMetricEvent(occurredAt: Date(timeIntervalSince1970: 124), ruleName: "B", outcome: .success)
        files.failWrites = true; files.blockNextWrite = true
        store.record(a); scheduler.fire()
        await waitUntil { files.blocked }
        store.record(b)
        files.failWrites = false; files.release()
        await waitUntil { files.writeThreads.count == 2 }
        await waitUntil { MetricsStore(fileURL: url).events.count == 2 }
        XCTAssertEqual(MetricsStore(fileURL: url).events, [b, a])
        XCTAssertNil(store.lastError)
    }

    fileprivate func entry(_ message: String) -> ExecutionLogEntry {
        ExecutionLogEntry(ruleName: "Ensaio", action: .openURL(url: URL(string: "https://example.com")!),
                          result: .succeeded(message, executedAt: Date(timeIntervalSince1970: 123)))
    }
    fileprivate func temporaryURL(_ name: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("Tico-persistence-\(UUID())").appendingPathComponent(name)
    }
}

/// O lock protege controles de falha/observações entre o teste main e o writer.
private final class PersistenceFileManager: FileManager, @unchecked Sendable {
    private let lock = NSLock()
    private var shouldFail = false
    private var threads: [Bool] = []
    private var shouldBlock = false
    private var isBlocked = false
    private let gate = DispatchSemaphore(value: 0)
    var blockNextWrite: Bool {
        get { lock.withLock { shouldBlock } }
        set { lock.withLock { shouldBlock = newValue } }
    }
    var blocked: Bool { lock.withLock { isBlocked } }
    func release() { gate.signal() }

    var failWrites: Bool {
        get { lock.withLock { shouldFail } }
        set { lock.withLock { shouldFail = newValue } }
    }
    var writeThreads: [Bool] { lock.withLock { threads } }
    override func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool,
                                  attributes: [FileAttributeKey: Any]? = nil) throws {
        let fail = lock.withLock { threads.append(Thread.isMainThread); return shouldFail }
        let block = lock.withLock { let value = shouldBlock; shouldBlock = false; isBlocked = value; return value }
        if block { _ = gate.wait(timeout: .now() + 3); lock.withLock { isBlocked = false } }
        if fail { throw CocoaError(.fileWriteNoPermission) }
        try super.createDirectory(at: url, withIntermediateDirectories: createIntermediates, attributes: attributes)
    }
}

/// Somente callbacks de ACK são reordenados; nenhuma operação toca disco real.
private final class ReorderedHistoryRepository: EventLogPersisting, @unchecked Sendable {
    let initialEntries: [ExecutionLogEntry] = []
    let initialError: String? = nil
    private let lock = NSLock()
    private var callbacks: [(UInt64, @Sendable (Result<EventLogRevision, Error>) -> Void)] = []
    var count: Int { lock.withLock { callbacks.count } }
    func submit(_ mutation: EventLogMutation, revision: UInt64,
                completion: @escaping @Sendable (Result<EventLogRevision, Error>) -> Void) {
        lock.withLock { callbacks.append((revision, completion)) }
    }
    func succeed(_ index: Int, entries: [ExecutionLogEntry]) {
        let callback = lock.withLock { callbacks[index] }
        callback.1(.success(EventLogRevision(revision: callback.0, entries: entries)))
    }
    func fail(_ index: Int) {
        let callback = lock.withLock { callbacks[index] }
        callback.1(.failure(CocoaError(.fileWriteNoPermission)))
    }
}

@MainActor
private final class ManualMetricsScheduler: MetricsWriteScheduling {
    var delays: [TimeInterval] = []
    private var action: (() -> Void)?
    func schedule(after seconds: TimeInterval, action: @escaping @MainActor () -> Void) -> () -> Void {
        delays.append(seconds); self.action = action
        return { [weak self] in self?.action = nil }
    }
    func fire() { let action = self.action; self.action = nil; action?() }
}
