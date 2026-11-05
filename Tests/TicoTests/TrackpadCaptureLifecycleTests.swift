import AppKit
import XCTest
@testable import Tico

@MainActor
final class TrackpadCaptureLifecycleTests: XCTestCase {
    private var defaultsNames: [String] = []

    override func tearDown() {
        MainActor.assumeIsolated {
            for name in defaultsNames { UserDefaults.standard.removePersistentDomain(forName: name) }
        }
        super.tearDown()
    }

    func testFrameBufferAccepts128AndCancels129ExactlyOnce() async throws {
        for count in [127, 128, 129] {
            let queue = DispatchQueue(label: "tico.test.buffer-capacity")
            let clock = BufferTestClock()
            let metrics = InputPipelineMetrics(isEnabled: true, now: { clock.now })
            let worker = GestureProcessingWorker(queue: queue, pipelineMetrics: metrics)
            let result = BufferTestResults()
            let generation = CaptureGeneration()
            queue.suspend()
            worker.prepareForCapture(generation: generation, onInterruption: { result.interrupt() })
            for index in 0..<count {
                worker.process(frame(Int32(index), offset: 0), generation: generation) { output in
                    result.append(output)
                }
            }
            queue.resume()
            let drained = expectation(description: "Dreno concluído")
            queue.async { drained.fulfill() }
            await fulfillment(of: [drained], timeout: 1)
            XCTAssertEqual(result.outputs.count, count <= 128 ? count : 0)
            XCTAssertEqual(result.interruptions, count <= 128 ? 0 : 1)
            XCTAssertEqual(metrics.snapshot().maximumQueueDepth, min(count, 128))
            if count <= 128 {
                XCTAssertEqual(result.outputs.compactMap { $0.laboratorySnapshot?.features.occurredAt },
                    (0..<count).map { frame(Int32($0), offset: 0).receivedAt })
            }
        }
    }

    func testFrameAgeAllows100MillisecondsAndRejects101() async throws {
        for milliseconds in [99, 100, 101] {
            let queue = DispatchQueue(label: "tico.test.buffer-age")
            let clock = BufferTestClock()
            let worker = GestureProcessingWorker(queue: queue,
                pipelineMetrics: InputPipelineMetrics(isEnabled: true, now: { clock.now }))
            let result = BufferTestResults()
            let generation = CaptureGeneration()
            queue.suspend()
            worker.prepareForCapture(generation: generation, onInterruption: { result.interrupt() })
            worker.process(frame(1, offset: 0), generation: generation) { result.append($0) }
            clock.advance(to: UInt64(milliseconds) * 1_000_000)
            queue.resume()
            let drained = expectation(description: "Limite de idade")
            queue.async { drained.fulfill() }
            await fulfillment(of: [drained], timeout: 1)
            XCTAssertEqual(result.outputs.count, milliseconds <= 100 ? 1 : 0)
            XCTAssertEqual(result.interruptions, milliseconds <= 100 ? 0 : 1)
            XCTAssertTrue(generation.isValid, "Sobrecarga não revoga o callback que observa liberação")
        }
    }

    func testServiceOverloadDiscardsCalculatedOutputsAndRearmsAfterZeroContacts() async throws {
        let queue = DispatchQueue(label: "tico.test.overload-service")
        let clock = BufferTestClock()
        let worker = GestureProcessingWorker(queue: queue,
            pipelineMetrics: InputPipelineMetrics(isEnabled: true, now: { clock.now }))
        let provider = RetainingFrameProvider()
        let service = makeService(provider, worker: worker)
        var received: [InputEventDescriptor] = []
        var interrupted = 0
        var starts = 0
        service.onCaptureInterrupted = { interrupted += 1 }
        service.onCaptureWillStart = { starts += 1 }
        service.start { received.append($0) }
        provider.emit(frame(1, offset: 0), start: 0)
        provider.emit(frame(2, offset: nil), start: 0)
        queue.sync {} // Resultado calculado, entrega main ainda pendente.
        queue.suspend()
        for index in 3...131 { provider.emit(frame(Int32(index), offset: 0), start: 0) }
        queue.resume()
        try await waitUntil { interrupted == 1 }
        XCTAssertTrue(received.isEmpty)
        XCTAssertNil(service.latestEvent)
        XCTAssertEqual(service.activeTouchCount, 0)
        provider.emit(frame(132, offset: 0.3), start: 0)
        queue.sync {}
        for _ in 0..<5 { await Task.yield() }
        XCTAssertTrue(received.isEmpty)
        XCTAssertEqual(starts, 1)
        provider.emit(frame(133, offset: nil), start: 0)
        provider.emit(frame(134, offset: 0), start: 0)
        provider.emit(frame(135, offset: nil), start: 0)
        try await waitUntil { received.count == 1 }
        XCTAssertEqual(received.map(\.gesture), [.tap])
        XCTAssertEqual(starts, 2)
        XCTAssertEqual(interrupted, 1)
        XCTAssertEqual(provider.startCount, 1)
        service.stop()
    }

    func testExpiredFramePreservesQueuedReleaseAndFirstCompleteNewGesture() async throws {
        let queue = DispatchQueue(label: "tico.test.expired-release")
        let clock = BufferTestClock()
        let worker = GestureProcessingWorker(queue: queue,
            pipelineMetrics: InputPipelineMetrics(isEnabled: true, now: { clock.now }))
        let provider = RetainingFrameProvider()
        let service = makeService(provider, worker: worker)
        var received: [InputEventDescriptor] = []
        var interruptions = 0
        var starts = 0
        service.onCaptureInterrupted = { interruptions += 1 }
        service.onCaptureWillStart = { starts += 1 }
        queue.suspend()
        service.start { received.append($0) }
        provider.emit(frame(1, offset: 0), start: 0)
        clock.advance(to: 101_000_000)
        provider.emit(frame(2, offset: nil), start: 0)
        provider.emit(frame(3, offset: 0), start: 0)
        provider.emit(frame(4, offset: nil), start: 0)
        queue.resume()
        try await waitUntil { received.count == 1 }
        XCTAssertEqual(received.map(\.gesture), [.tap])
        XCTAssertEqual(received.map(\.timestamp), [frame(4, offset: nil).receivedAt])
        XCTAssertEqual(interruptions, 1)
        XCTAssertEqual(starts, 2)
        XCTAssertEqual(service.activeTouchCount, 0)
        service.stop()
    }

    func testOldDeliveryAcknowledgementCannotResumeNewGeneration() async {
        let queue = DispatchQueue(label: "tico.test.old-delivery-ack")
        let worker = GestureProcessingWorker(queue: queue, pipelineMetrics: InputPipelineMetrics(now: { 0 }))
        let old = CaptureGeneration()
        let current = CaptureGeneration()
        let oldSchedule = DeliveryTestSchedule()
        let newSchedule = DeliveryTestSchedule()
        let result = BufferTestResults()
        worker.prepareForCapture(generation: old)
        let oldDelivery = GestureOutputDelivery(worker: worker, generation: old,
            schedule: { oldSchedule.append($0) }, consume: { _ in })
        oldDelivery.append(GestureProcessingOutput(event: nil, laboratorySnapshot: nil))
        old.invalidate()
        worker.prepareForCapture(generation: current)
        let newDelivery = GestureOutputDelivery(worker: worker, generation: current,
            schedule: { newSchedule.append($0) }, consume: { _ in })
        for _ in 0..<64 { newDelivery.append(GestureProcessingOutput(event: nil, laboratorySnapshot: nil)) }
        worker.process(frame(1, offset: 0), generation: current) { result.append($0) }
        queue.sync {}
        oldSchedule.runNext()
        queue.sync {}
        XCTAssertTrue(result.outputs.isEmpty)
        newSchedule.runNext()
        queue.sync {}
        XCTAssertEqual(result.outputs.first?.activeTouchCount, 3)
    }

    func testDeliveryAcknowledgementDoesNotResumeWhenProducerFilledNextBatch() async {
        let queue = DispatchQueue(label: "tico.test.same-delivery-ack")
        let worker = GestureProcessingWorker(queue: queue, pipelineMetrics: InputPipelineMetrics(now: { 0 }))
        let generation = CaptureGeneration()
        worker.prepareForCapture(generation: generation)
        let schedule = DeliveryTestSchedule()
        let result = BufferTestResults()
        var filled = false
        var delivery: GestureOutputDelivery!
        delivery = GestureOutputDelivery(worker: worker, generation: generation,
            schedule: { schedule.append($0) }, consume: { _ in
                guard !filled else { return }
                filled = true
                for _ in 0..<64 { delivery.append(GestureProcessingOutput(event: nil, laboratorySnapshot: nil)) }
            })
        delivery.append(GestureProcessingOutput(event: nil, laboratorySnapshot: nil))
        schedule.runNext()
        worker.process(frame(1, offset: 0), generation: generation) { result.append($0) }
        queue.sync {}
        XCTAssertTrue(result.outputs.isEmpty)
        schedule.runNext()
        queue.sync {}
        XCTAssertEqual(result.outputs.first?.activeTouchCount, 3)
    }

    func testReservedControlPrecedesFreshOutputInPreviouslyScheduledMainDrain() async throws {
        let queue = DispatchQueue(label: "tico.test.control-delivery-order")
        let clock = BufferTestClock()
        let worker = GestureProcessingWorker(queue: queue, pipelineMetrics: InputPipelineMetrics(now: { clock.now }))
        let provider = RetainingFrameProvider()
        let service = makeService(provider, worker: worker)
        var order: [String] = []
        service.onCaptureInterrupted = { order.append("cleanup") }
        service.onCaptureWillStart = { order.append("rearm") }
        service.start { _ in order.append("event") }
        order.removeAll()
        provider.emit(frame(1, offset: 0), start: 0)
        queue.sync {} // Dreno main antigo agendado antes dos controles.
        queue.suspend()
        provider.emit(frame(2, offset: 0.3), start: 0)
        clock.advance(to: 101_000_000)
        provider.emit(frame(3, offset: nil), start: 0)
        provider.emit(frame(4, offset: 0), start: 0)
        provider.emit(frame(5, offset: nil), start: 0)
        queue.resume()
        queue.sync {}
        try await waitUntil { order.count == 3 }
        XCTAssertEqual(order, ["cleanup", "rearm", "event"])
        service.stop()
    }

    func testSlowDeliveryPreservesAllDiscreteTerminalsInOrder() async throws {
        let queue = DispatchQueue(label: "tico.test.delivery-backpressure")
        let clock = BufferTestClock()
        let worker = GestureProcessingWorker(queue: queue,
            pipelineMetrics: InputPipelineMetrics(now: { clock.now }))
        let provider = RetainingFrameProvider()
        let service = makeService(provider, worker: worker)
        var received: [InputEventDescriptor] = []
        service.start { received.append($0) }
        queue.suspend()
        for index in 0..<120 { provider.emit(frame(Int32(index), offset: index % 2 == 0 ? 0 : nil), start: 0) }
        queue.resume()
        queue.sync {}
        try await waitUntil { received.count == 60 }
        XCTAssertEqual(received.map(\.gesture), Array(repeating: .tap, count: 60))
        XCTAssertEqual(received.map(\.timestamp), stride(from: 1, to: 120, by: 2).map { frame(Int32($0), offset: nil).receivedAt })
        XCTAssertEqual(service.activeTouchCount, 0)
        service.stop()
    }

    // CAP-04.A/B/C: callback antigo não entra na gravação nem na nova sessão.
    func testDelayedCallbacksCannotPolluteRestartedCaptureOrRecording() async throws {
        let queue = DispatchQueue(label: "tico.test.capture-generation")
        let worker = GestureProcessingWorker(queue: queue)
        let provider = RetainingFrameProvider()
        let service = makeService(provider, worker: worker)
        var received: [InputEventDescriptor] = []
        queue.suspend()
        service.start { received.append($0) }
        provider.emit(frame(1, offset: 0), start: 0)
        service.stop()
        service.start { received.append($0) }
        service.startSessionRecording(name: "Nova")
        provider.emit(frame(2, offset: 0.3), start: 0)
        provider.emit(frame(3, offset: 0), start: 1)
        provider.emit(frame(4, offset: nil), start: 1)
        queue.resume()
        try await waitUntil { received.count == 1 }
        let document = try XCTUnwrap(service.stopSessionRecording())
        XCTAssertEqual(document.frames.map(\.frameNumber), [3, 4])
        XCTAssertEqual(received.map(\.gesture), [.tap])
        XCTAssertEqual(received.map(\.fingerCount), [3])
        XCTAssertEqual(received[0].advancedGesture?.tapCount, 1)
        XCTAssertEqual(service.activeTouchCount, 0)
        service.stop()
    }

    // CAP-04.A: resultado já calculado, ainda pendente na main, não é publicado.
    func testCalculatedOutputFromOldGenerationCannotReachNewHandler() async throws {
        let queue = DispatchQueue(label: "tico.test.capture-delivery")
        let provider = RetainingFrameProvider()
        let service = makeService(provider, worker: GestureProcessingWorker(queue: queue))
        var received: [InputEventDescriptor] = []
        service.start { received.append($0) }
        provider.emit(frame(1, offset: 0), start: 0)
        provider.emit(frame(2, offset: nil), start: 0)
        // Barreira exclusiva do teste: deixa os callbacks da main deliberadamente pendentes.
        queue.sync {}
        service.stop()
        service.start { received.append($0) }
        for _ in 0..<10 { await Task.yield() }
        XCTAssertTrue(received.isEmpty)
        XCTAssertNil(service.latestEvent)
        XCTAssertNil(service.laboratorySnapshot)
        XCTAssertEqual(service.activeTouchCount, 0)
        provider.emit(frame(3, offset: 0), start: 1)
        provider.emit(frame(4, offset: 0.25), start: 1)
        provider.emit(frame(5, offset: nil), start: 1)
        try await waitUntil { received.count == 1 }
        XCTAssertEqual(received.map(\.gesture), [.swipeRight])
        service.stop()
    }

    // CAP-04.A: defesa no worker permanece necessária mesmo após o ingresso.
    func testWorkerRejectsOldGenerationBeforeMutatingCurrentEngine() async {
        let worker = GestureProcessingWorker()
        let old = CaptureGeneration()
        let current = CaptureGeneration()
        worker.prepareForCapture(generation: old)
        old.invalidate()
        worker.prepareForCapture(generation: current)
        let done = expectation(description: "Geração atual processada")
        worker.process(frame(1, offset: 0, count: 5), generation: old) { _ in
            XCTFail("Frame inválido não pode produzir output")
        }
        worker.process(frame(2, offset: 0), generation: current) { _ in }
        worker.process(frame(3, offset: nil), generation: current) { output in
            XCTAssertEqual(output.event?.kind, .tap)
            XCTAssertEqual(output.event?.fingerCount, 3)
            done.fulfill()
        }
        await fulfillment(of: [done], timeout: 1)
    }

    // CAP-01.D/04.B: wake interno relê flags antes de qualquer novo gesto.
    func testSleepWakeResynchronizesModifiersAndRejectsOldProviderCallback() async throws {
        let provider = RetainingFrameProvider()
        let service = makeService(provider)
        var flags: Set<InputModifier> = [.command]
        let coordinator = CaptureCoordinator(globalEventTap: LifecycleEventTap(), trackpadGestures: service,
            permissions: PermissionCoordinator(accessibilityCheck: { true }, inputMonitoringCheck: { .granted }, settingsOpener: { _ in }),
            hardwareDetector: TrackpadHardwareDetector(), detectHardware: { [] }, readModifiers: { flags })
        var currentFlags: Set<InputModifier> = []
        var gestureFlags: [Set<InputModifier>] = []
        coordinator.setInputHandler { input in
            if input.isModifierChange { currentFlags = input.modifiers }
            else { gestureFlags.append(currentFlags) }
        }
        XCTAssertTrue(coordinator.startTrackpadObservation())
        XCTAssertEqual(currentFlags, [.command])
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.willSleepNotification, object: nil)
        try await waitUntil { !service.isRunning }
        flags = [.shift]
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
        try await waitUntil { service.isRunning }
        provider.emit(frame(1, offset: 0.5), start: 0)
        provider.emit(frame(2, offset: 0), start: 1)
        provider.emit(frame(3, offset: nil), start: 1)
        try await waitUntil { gestureFlags.count == 1 }
        XCTAssertEqual(currentFlags, [.shift])
        XCTAssertEqual(gestureFlags, [[.shift]])
        coordinator.stopTrackpadObservation()
    }

    // CAP-04.B/05.D: o adaptador guarda a geração imutável do monitor.
    func testRetiredFallbackMonitorCannotEmitAfterProviderChangeOrRestart() {
        let monitor = RetainingGestureMonitor()
        let service = makeService(RetainingFrameProvider(), monitor: monitor)
        var received: [InputEventDescriptor] = []
        service.start { received.append($0) }
        service.activateSystemFallbackForValidation()
        let old = monitor.handlers[0]
        service.restoreAdvancedCapture()
        old(SystemGestureSample(type: .swipe, deltaX: 1))
        XCTAssertTrue(received.isEmpty)
        service.activateSystemFallbackForValidation()
        old(SystemGestureSample(type: .swipe, deltaX: 1))
        monitor.handlers[1](SystemGestureSample(type: .swipe, deltaX: -1))
        XCTAssertEqual(received.map(\.gesture), [.swipeLeft])
        service.stop()
        monitor.handlers[1](SystemGestureSample(type: .swipe, deltaX: 1))
        XCTAssertEqual(received.map(\.gesture), [.swipeLeft])
    }

    // CAP-04.D: controle de interrupção limpa a janela sem cancelar teclado.
    func testCaptureInterruptionRestoresContinuousSessionOnceAndPreservesKeyboardWorkflow() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let rules = ShortcutStore(fileURL: directory.appendingPathComponent("rules.json"), seedExamples: false)
        let keyboard = ShortcutRule(name: "Teclado", trigger: .keyboard(keyCode: 0, modifiers: []), action: .notification(title: "Teclado", body: ""))
        let continuous = ShortcutRule(name: "Janela", trigger: .trackpad(spec: TrackpadTriggerSpec(gesture: .swipeRight, fingerCount: 3)),
            action: .continuousWindow(target: .frontmost, operation: .moveHorizontal, curve: .linear))
        try rules.add(keyboard)
        try rules.add(continuous)
        let provider = RetainingFrameProvider()
        let service = makeService(provider)
        let window = LifecycleWindowController()
        let notification = LifecycleNotification()
        let automation = AutomationCoordinator(shortcutStore: rules,
            eventLogStore: EventLogStore(fileURL: directory.appendingPathComponent("events.json")),
            metricsStore: MetricsStore(fileURL: directory.appendingPathComponent("metrics.json")),
            actionRunner: ActionRunner(notificationService: notification), continuousWindowController: window,
            contextSnapshotService: LifecycleContext(), setContinuousPhasesEnabled: { service.setContinuousPhasesEnabled($0) })
        service.onCaptureInterrupted = { automation.cancelContinuousSessions() }
        service.start { automation.handle(event: $0, modifiers: []) }
        automation.handle(event: .keyboard(keyCode: 0), modifiers: [])
        try await waitUntil { notification.started }
        provider.emit(frame(1, offset: 0), start: 0)
        provider.emit(frame(2, offset: 0.2), start: 0)
        provider.emit(frame(3, offset: 0.3), start: 0)
        try await waitUntil { window.position > 100 }
        service.stop()
        service.stop()
        XCTAssertEqual(window.position, 100)
        XCTAssertEqual(window.cancellations, 1)
        XCTAssertEqual(window.cancelRequests, 1, "Interrupções repetidas não reenviam o controle")
        XCTAssertTrue(window.sessions.isEmpty)
        XCTAssertTrue(automation.runningRuleIDs.contains(keyboard.id))
        notification.release()
        try await waitUntil { automation.lastWorkflowReport != nil }
        XCTAssertEqual(notification.wasCancelled, false)
        XCTAssertEqual(automation.lastWorkflowReport?.wasCancelled, false)
        automation.stop()
    }

    func testCurrentGenerationDeliversPhasesInOrderAndReplayNeverDispatchesActions() async throws {
        let provider = RetainingFrameProvider()
        let service = makeService(provider)
        service.setContinuousPhasesEnabled(true)
        var events: [InputEventDescriptor] = []
        service.start { events.append($0) }
        service.startSessionRecording(name: "Ordem")
        for frame in [frame(1, offset: 0), frame(2, offset: 0.2), frame(3, offset: 0.3), frame(4, offset: nil)] {
            provider.emit(frame, start: 0)
        }
        try await waitUntil { events.count == 3 }
        XCTAssertEqual(events.compactMap(\.gestureEvent?.phase), [.began, .changed, .ended])
        XCTAssertEqual(Set(events.compactMap(\.gestureEvent?.sessionID)).count, 1)
        XCTAssertEqual(events.map(\.gesture), [.swipeRight, .swipeRight, .swipeRight])
        let document = try XCTUnwrap(service.stopSessionRecording())
        let priorEvents = events
        service.replay(document, speed: 100)
        try await waitUntil { !service.isReplaying && service.replayProgress == 1 }
        XCTAssertEqual(events, priorEvents)
        service.stop()
    }

    // CAP-05.A/C: cancelar não conclui, nem transfere movimento à sessão seguinte.
    func testCancelledMagnificationAndRotationNeverCompleteOrLeakAccumulation() {
        for type: NSEvent.EventType in [.magnify, .rotate] {
            let small: CGFloat = type == .magnify ? 0.01 : 1
            let large: CGFloat = type == .magnify ? 0.2 : 4
            for amount in [small, large, -large] {
                let monitor = RetainingGestureMonitor()
                let service = makeService(RetainingFrameProvider(), monitor: monitor)
                var received: [InputEventDescriptor] = []
                service.start { received.append($0) }
                service.activateSystemFallbackForValidation()
                let send = monitor.handlers[0]
                send(sample(type, phase: .began, amount: 0))
                send(sample(type, phase: .changed, amount: amount))
                send(sample(type, phase: .cancelled, amount: amount))
                XCTAssertTrue(received.isEmpty)
                XCTAssertNil(service.latestEvent)
                send(sample(type, phase: .began, amount: 0))
                send(sample(type, phase: .ended, amount: small))
                XCTAssertTrue(received.isEmpty)
                service.stop()
            }
        }
    }

    // CAP-05.B: os dois sinais continuam reconhecidos exatamente uma vez.
    func testNormallyEndedFallbackGesturesKeepDirectionAndEmitOnce() {
        let cases: [(NSEvent.EventType, CGFloat, TrackpadGesture)] = [
            (.magnify, 0.2, .pinchOut), (.magnify, -0.2, .pinchIn),
            (.rotate, 4, .rotateCounterclockwise), (.rotate, -4, .rotateClockwise)
        ]
        for (type, amount, expected) in cases {
            let monitor = RetainingGestureMonitor()
            let service = makeService(RetainingFrameProvider(), monitor: monitor)
            var received: [InputEventDescriptor] = []
            service.start { received.append($0) }
            service.activateSystemFallbackForValidation()
            let send = monitor.handlers[0]
            send(sample(type, phase: .began, amount: 0))
            send(sample(type, phase: .changed, amount: amount))
            send(sample(type, phase: .ended, amount: 0))
            send(sample(type, phase: .ended, amount: 0))
            XCTAssertEqual(received.map(\.gesture), [expected])
            XCTAssertEqual(received.compactMap(\.gestureEvent?.phase), [.ended])
            XCTAssertEqual(service.latestGestureEvent?.kind, expected)
            service.stop()
        }
    }

    private func sample(_ type: NSEvent.EventType, phase: NSEvent.Phase, amount: CGFloat) -> SystemGestureSample {
        SystemGestureSample(type: type, phase: phase,
            magnification: type == .magnify ? amount : 0, rotation: type == .rotate ? amount : 0)
    }

    private func makeService(_ provider: RetainingFrameProvider, worker: GestureProcessingWorker = GestureProcessingWorker(),
                             monitor: RetainingGestureMonitor? = nil) -> TrackpadGestureService {
        let name = "TrackpadCaptureLifecycleTests.\(UUID().uuidString)"
        defaultsNames.append(name)
        let defaults = UserDefaults(suiteName: name)!
        return TrackpadGestureService(providerFactory: { provider }, worker: worker,
            validationStore: TrackpadValidationStore(defaults: defaults, storageKey: "validation"),
            systemGestureMonitor: monitor ?? RetainingGestureMonitor())
    }

    private func frame(_ number: Int32, offset: Double?, count: Int = 3) -> RawTrackpadFrame {
        let touches = offset.map { value in
            (0..<count).map { index in
                RawTrackpadTouch(identifier: Int32(index + 1), state: 4,
                    position: TrackpadPoint(x: 0.25 + Double(index) * 0.06 + value, y: 0.5),
                    velocity: TrackpadPoint(x: 0, y: 0), pressure: 0.5)
            }
        } ?? []
        let date = Date(timeIntervalSince1970: 100 + Double(number) * 0.1)
        return RawTrackpadFrame(touches: touches, deviceTimestamp: Double(number) * 0.1,
            frameNumber: number, receivedAt: date, deviceID: nil)
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<200 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Condição não atingida")
    }
}

// Callbacks retidos intencionalmente: o teste simula entrega após stop sem hardware.
private final class RetainingFrameProvider: TrackpadFrameProvider {
    var startCount: Int { handlers.count }
    let capabilities = TrackpadProviderCapabilities.privateMultitouch
    var isRunning = false
    private var handlers: [@Sendable (RawTrackpadFrame) -> Void] = []
    func start(onFrame: @escaping @Sendable (RawTrackpadFrame) -> Void) throws { handlers.append(onFrame); isRunning = true }
    func stop() { isRunning = false }
    func emit(_ frame: RawTrackpadFrame, start: Int) { handlers[start](frame) }
}

@MainActor
private final class RetainingGestureMonitor: SystemGestureMonitoring {
    var handlers: [(SystemGestureSample) -> Void] = []
    func start(onGesture: @escaping (SystemGestureSample) -> Void) { handlers.append(onGesture) }
    func stop() {}
}

@MainActor
private final class LifecycleEventTap: GlobalEventTapping {
    var isRunning = false
    func start(onEvent: @escaping (InputEventDescriptor) -> Void, onStateChange: ((Bool) -> Void)?) throws { isRunning = true }
    func stop() { isRunning = false }
}

@MainActor
private final class LifecycleContext: ContextSnapshotProviding {
    func snapshot(modifiers: Set<InputModifier>, at date: Date) -> ContextSnapshot { ContextSnapshot(modifiers: modifiers, capturedAt: date) }
}

@MainActor
private final class LifecycleWindowController: ContinuousWindowActionControlling {
    var sessions: Set<UUID> = []
    var position = 100.0
    var cancellations = 0
    var cancelRequests = 0
    func begin(sessionID: UUID, target: ApplicationTarget, operation: ContinuousWindowOperation, capturedTarget: ContinuousWindowTarget?) throws { sessions.insert(sessionID) }
    func update(sessionID: UUID, progress: Double, curve: ContinuousResponseCurve) throws { position = 100 + progress * 100 }
    func commit(sessionID: UUID) -> ContinuousWindowCompletion {
        sessions.remove(sessionID)
        return .resolved(.committed)
    }
    func cancel(sessionID: UUID) -> ContinuousWindowCompletion {
        cancelRequests += 1
        if sessions.remove(sessionID) != nil { position = 100; cancellations += 1 }
        return .resolved(.cancelled)
    }
}

@MainActor
private final class LifecycleNotification: NotificationDelivering {
    var started = false
    var wasCancelled: Bool?
    private var continuation: CheckedContinuation<Void, Never>?
    func deliver(title: String, body: String) async throws {
        started = true
        await withCheckedContinuation { continuation = $0 }
        wasCancelled = Task.isCancelled
    }
    func release() { continuation?.resume(); continuation = nil }
}


/// Somente o relógio numérico é compartilhado; a fila e o teste usam o mesmo lock.
private final class BufferTestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: UInt64 = 0
    var now: UInt64 { lock.lock(); defer { lock.unlock() }; return value }
    func advance(to value: UInt64) { lock.lock(); self.value = value; lock.unlock() }
}
private final class BufferTestResults: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [GestureProcessingOutput] = []
    private var count = 0
    var outputs: [GestureProcessingOutput] { lock.lock(); defer { lock.unlock() }; return values }
    var interruptions: Int { lock.lock(); defer { lock.unlock() }; return count }
    func append(_ output: GestureProcessingOutput) { lock.lock(); values.append(output); lock.unlock() }
    func interrupt() { lock.lock(); count += 1; lock.unlock() }
}

/// Agendamento main controlado; o lock protege apenas a lista de closures.
private final class DeliveryTestSchedule: @unchecked Sendable {
    private let lock = NSLock()
    private var actions: [@MainActor () -> Void] = []
    func append(_ action: @escaping @MainActor () -> Void) { lock.lock(); actions.append(action); lock.unlock() }
    @MainActor func runNext() {
        lock.lock(); let action = actions.removeFirst(); lock.unlock()
        action()
    }
}
