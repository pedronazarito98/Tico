import AppKit
import ApplicationServices
import Foundation
import OSLog

@MainActor
protocol ContinuousWindowActionControlling {
    func begin(
        sessionID: UUID,
        target: ApplicationTarget,
        operation: ContinuousWindowOperation
    ) throws
    func update(
        sessionID: UUID,
        progress: Double,
        curve: ContinuousResponseCurve
    ) throws
    func commit(sessionID: UUID)
    func cancel(sessionID: UUID) throws
}

@MainActor
final class ContinuousWindowActionService: ContinuousWindowActionControlling {
    private struct Session {
        var window: AXUIElement
        var originalFrame: CGRect
        var operation: ContinuousWindowOperation
        var visibleFrame: CGRect
    }

    private let workspace: NSWorkspace
    private let accessibilityCheck: () -> Bool
    private var sessions: [UUID: Session] = [:]
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pedronazarito.AirShortcut",
        category: "ContinuousWindow"
    )

    init(
        workspace: NSWorkspace = .shared,
        accessibilityCheck: @escaping () -> Bool = AXIsProcessTrusted
    ) {
        self.workspace = workspace
        self.accessibilityCheck = accessibilityCheck
    }

    func begin(
        sessionID: UUID,
        target: ApplicationTarget,
        operation: ContinuousWindowOperation
    ) throws {
        guard accessibilityCheck() else {
            throw WindowControlError.accessibilityRequired
        }
        guard let application = runningApplication(for: target) else {
            throw WindowControlError.applicationNotRunning
        }
        let appElement = AXUIElementCreateApplication(application.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedWindowAttribute as CFString,
            &value
        ) == .success,
        let window = AccessibilityValueDecoder.element(value) else {
            throw WindowControlError.windowNotFound
        }
        sessions[sessionID] = Session(
            window: window,
            originalFrame: try frame(of: window),
            operation: operation,
            visibleFrame: visibleFrame(for: window)
        )
        logger.info("Continuous window session began")
    }

    func update(
        sessionID: UUID,
        progress: Double,
        curve: ContinuousResponseCurve
    ) throws {
        guard let session = sessions[sessionID] else {
            throw WindowControlError.operationFailed("sessão contínua não encontrada")
        }
        let mapped = curve.map(progress)
        let horizontalDelta = session.visibleFrame.width * mapped * 0.5
        let verticalDelta = session.visibleFrame.height * mapped * 0.5
        var target = session.originalFrame

        switch session.operation {
        case .moveHorizontal:
            target.origin.x += horizontalDelta
        case .moveVertical:
            target.origin.y += verticalDelta
        case .resizeWidth:
            target.size.width += horizontalDelta
        case .resizeHeight:
            target.size.height += verticalDelta
        case .resizeProportionally:
            let aspectRatio = max(session.originalFrame.width / session.originalFrame.height, 0.1)
            target.size.width += horizontalDelta
            target.size.height = target.size.width / aspectRatio
        }
        target.size.width = max(240, min(target.size.width, session.visibleFrame.width))
        target.size.height = max(160, min(target.size.height, session.visibleFrame.height))
        target.origin.x = min(
            max(target.origin.x, session.visibleFrame.minX),
            session.visibleFrame.maxX - target.size.width
        )
        target.origin.y = min(
            max(target.origin.y, session.visibleFrame.minY),
            session.visibleFrame.maxY - target.size.height
        )
        try set(frame: target, on: session.window)
    }

    func commit(sessionID: UUID) {
        sessions[sessionID] = nil
        logger.info("Continuous window session committed")
    }

    func cancel(sessionID: UUID) throws {
        guard let session = sessions.removeValue(forKey: sessionID) else { return }
        try set(frame: session.originalFrame, on: session.window)
        logger.info("Continuous window session cancelled and restored")
    }

    private func runningApplication(for target: ApplicationTarget) -> NSRunningApplication? {
        switch target {
        case .frontmost:
            workspace.frontmostApplication
        case let .bundleIdentifier(identifier):
            NSRunningApplication.runningApplications(withBundleIdentifier: identifier).first
        }
    }

    private func frame(of window: AXUIElement) throws -> CGRect {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        try requireSuccess(AXUIElementCopyAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            &positionValue
        ))
        try requireSuccess(AXUIElementCopyAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            &sizeValue
        ))
        guard let origin = AccessibilityValueDecoder.point(positionValue),
              let size = AccessibilityValueDecoder.size(sizeValue) else {
            throw WindowControlError.operationFailed("frame indisponível")
        }
        return CGRect(origin: origin, size: size)
    }

    private func set(frame: CGRect, on window: AXUIElement) throws {
        var position = frame.origin
        var size = frame.size
        guard let positionValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size) else {
            throw WindowControlError.operationFailed("frame inválido")
        }
        try requireSuccess(AXUIElementSetAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            positionValue
        ))
        try requireSuccess(AXUIElementSetAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            sizeValue
        ))
    }

    private func visibleFrame(for window: AXUIElement) -> CGRect {
        let current = (try? frame(of: window)) ?? .zero
        let screen = NSScreen.screens.first { screen in
            let center = CGPoint(x: current.midX, y: screen.frame.maxY - current.midY)
            return screen.frame.contains(center)
        } ?? NSScreen.main
        guard let screen else {
            return CGRect(x: 0, y: 0, width: 1_440, height: 900)
        }
        let visible = screen.visibleFrame
        return CGRect(
            x: visible.minX,
            y: screen.frame.maxY - visible.maxY,
            width: visible.width,
            height: visible.height
        )
    }

    private func requireSuccess(_ error: AXError) throws {
        guard error == .success else {
            throw WindowControlError.operationFailed("AXError \(error.rawValue)")
        }
    }
}
