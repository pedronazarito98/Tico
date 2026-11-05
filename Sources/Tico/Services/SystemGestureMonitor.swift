import AppKit

/// Valores da fronteira AppKit, sem reter NSEvent ao atravessar uma fila.
struct SystemGestureSample: Sendable {
    var type: NSEvent.EventType
    var phase: NSEvent.Phase = []
    var deltaX: CGFloat = 0
    var deltaY: CGFloat = 0
    var magnification: CGFloat = 0
    var rotation: CGFloat = 0

    init(type: NSEvent.EventType, phase: NSEvent.Phase = [], deltaX: CGFloat = 0,
         deltaY: CGFloat = 0, magnification: CGFloat = 0, rotation: CGFloat = 0) {
        self.type = type
        self.phase = phase
        self.deltaX = deltaX
        self.deltaY = deltaY
        self.magnification = magnification
        self.rotation = rotation
    }

    init(_ event: NSEvent) {
        type = event.type
        phase = event.phase
        switch event.type {
        case .swipe: deltaX = event.deltaX; deltaY = event.deltaY
        case .magnify: magnification = event.magnification
        case .rotate: rotation = CGFloat(event.rotation)
        default: break
        }
    }
}

@MainActor
protocol SystemGestureMonitoring: AnyObject {
    func start(onGesture: @escaping (SystemGestureSample) -> Void)
    func stop()
}

/// Único owner dos handles NSEvent do fallback. Instala/remove na main e
/// entrega valores na main; o serviço consumidor valida a geração do callback.
@MainActor
final class SystemGestureMonitor: SystemGestureMonitoring {
    private var localMonitor: Any?
    private var globalMonitor: Any?

    func start(onGesture: @escaping (SystemGestureSample) -> Void) {
        stop()
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: TrackpadGestureService.fallbackEventMask) { event in
            MainActor.assumeIsolated { onGesture(SystemGestureSample(event)) }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: TrackpadGestureService.fallbackEventMask) { event in
            let sample = SystemGestureSample(event)
            Task { @MainActor in onGesture(sample) }
        }
    }

    func stop() {
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil
        globalMonitor = nil
    }
}

