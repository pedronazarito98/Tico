import ApplicationServices
import CoreGraphics
import Foundation
import OSLog

enum GlobalEventTapError: LocalizedError, Equatable {
    case inputMonitoringPermissionRequired
    case alreadyRunning
    case eventTapCreationFailed
    case installationTimedOut

    var errorDescription: String? {
        switch self {
        case .inputMonitoringPermissionRequired:
            "O Monitoramento de Entrada precisa estar autorizado."
        case .alreadyRunning:
            "A captura global já está ativa."
        case .eventTapCreationFailed:
            "O macOS não permitiu criar o monitor global de eventos."
        case .installationTimedOut:
            "A captura global não iniciou dentro do tempo esperado."
        }
    }
}

final class GlobalEventTapService {
    typealias EventHandler = (InputEventDescriptor) -> Void
    typealias StateHandler = (Bool) -> Void

    private let lock = NSLock()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pedronazarito.AirShortcut",
        category: "GlobalCapture"
    )
    private let permissionCheck: () -> Bool
    private let deliveryQueue: DispatchQueue
    private let clock: () -> Date

    private var eventTap: CFMachPort?
    private var runLoop: CFRunLoop?
    private var workerThread: Thread?
    private var workerFinished: DispatchSemaphore?
    private var eventHandler: EventHandler?
    private var stateHandler: StateHandler?

    init(
        permissionCheck: @escaping () -> Bool = {
            CGPreflightListenEventAccess() || AXIsProcessTrusted()
        },
        deliveryQueue: DispatchQueue = .main,
        clock: @escaping () -> Date = Date.init
    ) {
        self.permissionCheck = permissionCheck
        self.deliveryQueue = deliveryQueue
        self.clock = clock
    }

    deinit {
        stop()
    }

    var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return eventTap != nil
    }

    func start(
        onEvent: @escaping EventHandler,
        onStateChange: StateHandler? = nil
    ) throws {
        guard permissionCheck() else {
            logger.error("Global capture refused: Input Monitoring is unavailable")
            throw GlobalEventTapError.inputMonitoringPermissionRequired
        }

        lock.lock()
        guard workerThread == nil else {
            lock.unlock()
            throw GlobalEventTapError.alreadyRunning
        }

        eventHandler = onEvent
        stateHandler = onStateChange
        let installation = EventTapInstallation()
        let workerFinished = DispatchSemaphore(value: 0)
        let thread = Thread { [weak self] in
            self?.installEventTap(reportingTo: installation)
        }
        thread.name = "AirShortcut.GlobalEventTap"
        thread.qualityOfService = .userInteractive
        workerThread = thread
        self.workerFinished = workerFinished
        lock.unlock()

        thread.start()

        guard installation.wait(timeout: 3) else {
            stop()
            throw GlobalEventTapError.installationTimedOut
        }
        if let error = installation.error {
            logger.error("Global capture installation failed: \(error.localizedDescription, privacy: .public)")
            throw error
        }
        logger.info("Global event tap installed in listen-only mode")
        onStateChange?(true)
    }

    func stop() {
        lock.lock()
        eventHandler = nil
        let tap = eventTap
        let eventRunLoop = runLoop
        let thread = workerThread
        let workerFinished = workerFinished
        lock.unlock()

        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let eventRunLoop {
            CFRunLoopStop(eventRunLoop)
            CFRunLoopWakeUp(eventRunLoop)
        }
        if thread != nil, Thread.current !== thread {
            _ = workerFinished?.wait(timeout: .now() + 1)
        }
        logger.info("Global event tap stopped")
    }

    fileprivate func receive(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            logger.warning("Global event tap was disabled by macOS; attempting to re-enable it")
            lock.lock()
            let tap = eventTap
            lock.unlock()
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
                if !CGEvent.tapIsEnabled(tap: tap) {
                    logger.error("Global event tap could not be re-enabled")
                }
            }
            return Unmanaged.passUnretained(event)
        }

        guard let descriptor = Self.normalize(type: type, event: event, timestamp: clock()) else {
            return Unmanaged.passUnretained(event)
        }

        lock.lock()
        let handler = eventHandler
        lock.unlock()

        if let handler {
            deliveryQueue.async {
                handler(descriptor)
            }
        }
        return Unmanaged.passUnretained(event)
    }

    static func normalize(
        type: CGEventType,
        event: CGEvent,
        timestamp: Date = Date()
    ) -> InputEventDescriptor? {
        let modifiers = normalizedModifiers(from: event.flags)

        switch type {
        case .keyDown, .flagsChanged:
            let rawKeyCode = event.getIntegerValueField(.keyboardEventKeycode)
            guard rawKeyCode >= 0, rawKeyCode <= Int64(UInt16.max) else { return nil }
            return .keyboard(
                keyCode: UInt16(rawKeyCode),
                modifiers: modifiers,
                timestamp: timestamp
            )

        case .otherMouseDown:
            let rawButton = event.getIntegerValueField(.mouseEventButtonNumber)
            guard rawButton >= 0, rawButton <= Int64(Int.max) else { return nil }
            return .mouseButton(
                Int(rawButton),
                modifiers: modifiers,
                timestamp: timestamp
            )

        default:
            return nil
        }
    }

    static func normalizedModifiers(from flags: CGEventFlags) -> Set<InputModifier> {
        var modifiers = Set<InputModifier>()
        if flags.contains(.maskCommand) { modifiers.insert(.command) }
        if flags.contains(.maskAlternate) { modifiers.insert(.option) }
        if flags.contains(.maskControl) { modifiers.insert(.control) }
        if flags.contains(.maskShift) { modifiers.insert(.shift) }
        if flags.contains(.maskAlphaShift) { modifiers.insert(.capsLock) }
        if flags.contains(.maskSecondaryFn) { modifiers.insert(.function) }
        return modifiers
    }

    private func installEventTap(reportingTo installation: EventTapInstallation) {
        let mask = Self.eventMask(for: [.keyDown, .flagsChanged, .otherMouseDown])
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: airShortcutEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            finishWorker()
            installation.resolve(error: .eventTapCreationFailed)
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            finishWorker()
            installation.resolve(error: .eventTapCreationFailed)
            return
        }

        let currentRunLoop = CFRunLoopGetCurrent()
        lock.lock()
        eventTap = tap
        runLoop = currentRunLoop
        lock.unlock()

        CFRunLoopAddSource(currentRunLoop, source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        installation.resolve(error: nil)
        CFRunLoopRun()

        CGEvent.tapEnable(tap: tap, enable: false)
        CFRunLoopRemoveSource(currentRunLoop, source, .commonModes)
        finishWorker()
    }

    private func finishWorker() {
        lock.lock()
        eventTap = nil
        runLoop = nil
        workerThread = nil
        eventHandler = nil
        let stateHandler = stateHandler
        self.stateHandler = nil
        let workerFinished = workerFinished
        self.workerFinished = nil
        lock.unlock()
        workerFinished?.signal()
        deliveryQueue.async {
            stateHandler?(false)
        }
    }

    private static func eventMask(for types: [CGEventType]) -> CGEventMask {
        types.reduce(CGEventMask(0)) { mask, type in
            mask | (CGEventMask(1) << type.rawValue)
        }
    }
}

private func airShortcutEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let service = Unmanaged<GlobalEventTapService>.fromOpaque(userInfo).takeUnretainedValue()
    return service.receive(type: type, event: event)
}

/// `lock` protects the one-shot `resolved` transition and its error payload;
/// callers wait on `semaphore` without holding that lock. Repeated resolution
/// is intentionally idempotent because installation and timeout can race.
private final class EventTapInstallation: @unchecked Sendable {
    private let semaphore = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var resolved = false
    private(set) var error: GlobalEventTapError?

    func resolve(error: GlobalEventTapError?) {
        lock.lock()
        guard !resolved else {
            lock.unlock()
            return
        }
        resolved = true
        self.error = error
        lock.unlock()
        semaphore.signal()
    }

    func wait(timeout: TimeInterval) -> Bool {
        semaphore.wait(timeout: .now() + timeout) == .success
    }
}
