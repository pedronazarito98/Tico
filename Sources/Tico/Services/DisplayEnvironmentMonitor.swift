import AppKit
import CoreGraphics

/// Único adaptador AppKit das rotinas. Observers pertencem à instância e são removidos
/// por stop/deinit. Callbacks saltam à MainActor antes de ler NSScreen ou publicar eventos.
@MainActor
final class DisplayEnvironmentMonitor {
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var distributedObservers: [NSObjectProtocol] = []
    private var onEvent: ((DisplayEnvironmentEvent) -> Void)?
    private var generation = UUID()

    func snapshot() -> DisplayEnvironmentSnapshot {
        var builtIn = 0
        var external = 0
        let screens = NSScreen.screens
        let main = CGMainDisplayID()
        let originX = screens.map { $0.frame.minX }.min() ?? 0
        let originY = screens.map { $0.frame.minY }.min() ?? 0
        var arrangement: [DisplayEnvironmentGeometry] = []
        for screen in screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { continue }
            let isBuiltIn = CGDisplayIsBuiltin(number.uint32Value) != 0
            if isBuiltIn { builtIn += 1 } else { external += 1 }
            arrangement.append(DisplayEnvironmentGeometry(role: isBuiltIn ? .builtIn : .external,
                isPrimary: number.uint32Value == main,
                x: Int((screen.frame.minX - originX).rounded()), y: Int((screen.frame.minY - originY).rounded()),
                width: Int(screen.frame.width.rounded()), height: Int(screen.frame.height.rounded())))
        }
        arrangement.sort { lhs, rhs in
            (lhs.role.rawValue, lhs.x, lhs.y, lhs.width, lhs.height, lhs.isPrimary ? 1 : 0)
                < (rhs.role.rawValue, rhs.x, rhs.y, rhs.width, rhs.height, rhs.isPrimary ? 1 : 0)
        }
        let role: DisplayEnvironmentSnapshot.MainDisplayRole = builtIn + external == 0
            ? .unavailable : (CGDisplayIsBuiltin(main) != 0 ? .builtIn : .external)
        return DisplayEnvironmentSnapshot(builtInCount: builtIn, externalCount: external,
            mainDisplayRole: role, arrangement: arrangement)
    }

    func start(onEvent: @escaping (DisplayEnvironmentEvent) -> Void) {
        guard observers.isEmpty else { return }
        generation = UUID()
        self.onEvent = onEvent
        observe(.default, NSApplication.didChangeScreenParametersNotification) { monitor in
            monitor.onEvent?(.changed(monitor.snapshot()))
        }
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.willSleepNotification) { $0.onEvent?(.suspended(.sleep)) }
        observe(workspace, NSWorkspace.didWakeNotification) { monitor in
            monitor.onEvent?(.resumed(.sleep, monitor.snapshot()))
        }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification) { $0.onEvent?(.suspended(.inactiveSession)) }
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification) { monitor in
            monitor.onEvent?(.resumed(.inactiveSession, monitor.snapshot()))
        }
        observe(workspace, NSWorkspace.screensDidSleepNotification) { $0.onEvent?(.suspended(.displaySleep)) }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { monitor in
            monitor.onEvent?(.resumed(.displaySleep, monitor.snapshot()))
        }
        // Sinais adicionais do sistema, sem ler userInfo, sessão ou identificadores.
        // O gate de sessão/repouso continua independente destes nomes de notificação.
        observeDistributed("com.apple.screenIsLocked") { $0.onEvent?(.suspended(.locked)) }
        observeDistributed("com.apple.screenIsUnlocked") { monitor in
            monitor.onEvent?(.resumed(.locked, monitor.snapshot()))
        }
    }

    func stop() {
        generation = UUID()
        observers.forEach { $0.0.removeObserver($0.1) }
        observers.removeAll()
        distributedObservers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
        distributedObservers.removeAll()
        onEvent = nil
    }

    deinit {
        observers.forEach { $0.0.removeObserver($0.1) }
        distributedObservers.forEach { DistributedNotificationCenter.default().removeObserver($0) }
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name,
                         action: @escaping @MainActor (DisplayEnvironmentMonitor) -> Void) {
        let observerGeneration = generation
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.onEvent != nil, self.generation == observerGeneration else { return }
                action(self)
            }
        }
        observers.append((center, token))
    }

    private func observeDistributed(_ name: String,
                                    action: @escaping @MainActor (DisplayEnvironmentMonitor) -> Void) {
        let observerGeneration = generation
        let token = DistributedNotificationCenter.default().addObserver(forName: Notification.Name(name),
            object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.onEvent != nil, self.generation == observerGeneration else { return }
                    action(self)
                }
            }
        distributedObservers.append(token)
    }
}
