import ApplicationServices
import Foundation

/// AXUIElement e todo estado mutável pertencem exclusivamente à fila do
/// ContinuousWindowAXWorker. @unchecked Sendable permite entregar o owner à
/// fila; nenhum método pode ser chamado diretamente da UI. AppKit não é usado.
final class NativeContinuousWindowAX: ContinuousWindowAXOperating, @unchecked Sendable {
    private struct Session {
        let app: AXUIElement
        let window: AXUIElement
        let target: ContinuousWindowTarget
        let originalFrame: CGRect
        let operation: ContinuousWindowOperation
        let visibleFrame: CGRect
    }
    private let accessibilityCheck: @Sendable () -> Bool
    private var sessions: [UUID: Session] = [:]

    init(accessibilityCheck: @escaping @Sendable () -> Bool) { self.accessibilityCheck = accessibilityCheck }

    func begin(sessionID: UUID, target: ContinuousWindowTarget, operation: ContinuousWindowOperation, budget: AXOperationBudget) throws {
        guard accessibilityCheck() else { throw WindowControlError.accessibilityRequired }
        guard target.isValid else { throw WindowControlError.applicationNotRunning }
        let app = AXUIElementCreateApplication(target.processIdentifier)
        guard let window = AccessibilityValueDecoder.element(try value(kAXFocusedWindowAttribute, of: app, budget: budget)) else {
            throw WindowControlError.windowNotFound
        }
        let original = try frame(of: window, budget: budget)
        guard let current = AccessibilityValueDecoder.element(try value(kAXFocusedWindowAttribute, of: app, budget: budget)),
              CFEqual(window, current), target.isValid else { throw WindowControlError.windowNotFound }
        sessions[sessionID] = Session(app: app, window: window, target: target, originalFrame: original,
            operation: operation, visibleFrame: visibleFrame(for: original, displays: target.displays))
    }

    func update(sessionID: UUID, progress: Double, curve: ContinuousResponseCurve, budget: AXOperationBudget) throws {
        guard let session = sessions[sessionID], session.target.isValid,
              let current = AccessibilityValueDecoder.element(try value(kAXFocusedWindowAttribute, of: session.app, budget: budget)),
              CFEqual(session.window, current) else { throw WindowControlError.windowNotFound }
        let mapped = curve.map(progress)
        let horizontalDelta = session.visibleFrame.width * mapped * 0.5
        let verticalDelta = session.visibleFrame.height * mapped * 0.5
        var target = session.originalFrame
        switch session.operation {
        case .moveHorizontal: target.origin.x += horizontalDelta
        case .moveVertical: target.origin.y += verticalDelta
        case .resizeWidth: target.size.width += horizontalDelta
        case .resizeHeight: target.size.height += verticalDelta
        case .resizeProportionally:
            let aspectRatio = max(session.originalFrame.width / session.originalFrame.height, 0.1)
            target.size.width += horizontalDelta
            target.size.height = target.size.width / aspectRatio
        }
        target.size.width = max(240, min(target.size.width, session.visibleFrame.width))
        target.size.height = max(160, min(target.size.height, session.visibleFrame.height))
        target.origin.x = min(max(target.origin.x, session.visibleFrame.minX), session.visibleFrame.maxX - target.size.width)
        target.origin.y = min(max(target.origin.y, session.visibleFrame.minY), session.visibleFrame.maxY - target.size.height)
        try set(frame: target, on: session.window, budget: budget, generation: session.target.generation)
    }

    func finish(sessionID: UUID, restoring: Bool, budget: AXOperationBudget) throws {
        guard let session = sessions.removeValue(forKey: sessionID) else { return }
        // A restauração pertence à janela original mesmo se o foco mudou.
        // O handle é retirado antes do efeito e não pode ser reutilizado depois.
        if restoring { try set(frame: session.originalFrame, on: session.window, budget: budget, generation: nil) }
    }

    private func frame(of window: AXUIElement, budget: AXOperationBudget) throws -> CGRect {
        guard let origin = AccessibilityValueDecoder.point(try value(kAXPositionAttribute, of: window, budget: budget)),
              let size = AccessibilityValueDecoder.size(try value(kAXSizeAttribute, of: window, budget: budget)) else {
            throw WindowControlError.operationFailed("frame indisponível")
        }
        return CGRect(origin: origin, size: size)
    }
    private func value(_ attribute: String, of element: AXUIElement, budget: AXOperationBudget) throws -> CFTypeRef? {
        try budget.configure(element)
        var result: CFTypeRef?
        try requireSuccess(AXUIElementCopyAttributeValue(element, attribute as CFString, &result))
        guard budget.remaining > 0 else { throw WindowControlError.operationFailed("consulta AX fora do prazo") }
        return result
    }
    private func set(frame: CGRect, on window: AXUIElement, budget: AXOperationBudget, generation: CaptureGeneration?) throws {
        var position = frame.origin, size = frame.size
        guard let positionValue = AXValueCreate(.cgPoint, &position), let sizeValue = AXValueCreate(.cgSize, &size) else {
            throw WindowControlError.operationFailed("frame inválido")
        }
        guard generation?.isValid ?? true else { throw WindowControlError.windowNotFound }
        try budget.configure(window)
        try requireSuccess(AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue))
        guard generation?.isValid ?? true else { throw WindowControlError.windowNotFound }
        try budget.configure(window)
        try requireSuccess(AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue))
        guard budget.remaining > 0 else { throw WindowControlError.operationFailed("escrita AX fora do prazo") }
    }
    private func visibleFrame(for frame: CGRect, displays: [WindowDisplaySnapshot]) -> CGRect {
        let display = displays.first { $0.frame.contains(CGPoint(x: frame.midX, y: $0.frame.maxY - frame.midY)) } ?? displays.first
        guard let display else { return CGRect(x: 0, y: 0, width: 1440, height: 900) }
        let visible = display.visibleFrame
        return CGRect(x: visible.minX, y: display.frame.maxY - visible.maxY, width: visible.width, height: visible.height)
    }
    private func requireSuccess(_ result: AXError) throws {
        guard result == .success else { throw WindowControlError.operationFailed("AXError \(result.rawValue)") }
    }
}
