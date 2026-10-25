import AppKit

/// Snapshot de plataforma coletado no MainActor. O actor de layout recebe somente
/// valores; NSRunningApplication e NSScreen nunca atravessam a fronteira de execução.
@MainActor
enum SceneLayoutEnvironment {
    struct Application: Sendable {
        let bundleIdentifier: String
        let name: String
        let pid: pid_t
        let launchedAt: Date
    }

    struct Screen: Equatable, Sendable {
        let role: SceneLayoutDisplayRole
        let number: UInt32
        let frame: SceneLayoutRect
        let isPrimary: Bool
        var display: SceneLayoutDisplay { .init(role: role, frame: frame, isPrimary: isPrimary) }
    }

    static func applications() -> [Application] {
        NSWorkspace.shared.runningApplications.compactMap { app in
            guard app.activationPolicy == .regular, !app.isTerminated,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
                  let bundleIdentifier = app.bundleIdentifier, let launchedAt = app.launchDate else { return nil }
            return Application(bundleIdentifier: bundleIdentifier, name: app.localizedName ?? bundleIdentifier,
                pid: app.processIdentifier, launchedAt: launchedAt)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func isRunning(_ expected: Application) -> Bool {
        guard let current = NSRunningApplication(processIdentifier: expected.pid) else { return false }
        return !current.isTerminated && current.bundleIdentifier == expected.bundleIdentifier
            && current.launchDate == expected.launchedAt
    }

    static func activate(_ expected: Application) -> Bool {
        guard isRunning(expected), let application = NSRunningApplication(processIdentifier: expected.pid) else { return false }
        return application.activate()
    }

    static func screens() -> [Screen] {
        let screens = NSScreen.screens
        guard let primary = screens.first else { return [] }
        // AX usa origem superior esquerda global. A altura da tela principal é a
        // referência da conversão, inclusive para monitores acima ou abaixo dela.
        let globalTop = primary.frame.maxY
        let ordered = screens.sorted {
            $0.frame.minX == $1.frame.minX ? $0.frame.minY > $1.frame.minY : $0.frame.minX < $1.frame.minX
        }
        var externalIndex = 0
        let externalRoles: [SceneLayoutDisplayRole] = [.external1, .external2, .external3, .external4]
        return ordered.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
            let displayID = number.uint32Value
            let role: SceneLayoutDisplayRole
            if CGDisplayIsBuiltin(displayID) != 0 {
                role = .builtIn
            } else {
                guard externalIndex < externalRoles.count else { return nil }
                role = externalRoles[externalIndex]
                externalIndex += 1
            }
            let visible = screen.visibleFrame
            return Screen(role: role, number: displayID,
                frame: .init(x: visible.minX, y: globalTop - visible.maxY,
                    width: visible.width, height: visible.height), isPrimary: screen == primary)
        }
    }
}

extension SceneLayoutRect {
    init(_ rectangle: CGRect) {
        self.init(x: rectangle.minX, y: rectangle.minY, width: rectangle.width, height: rectangle.height)
    }
    var cgRect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
}
