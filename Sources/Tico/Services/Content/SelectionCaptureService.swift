import AppKit
import ApplicationServices
import Foundation

protocol SelectedTextCapturing {
    func capture() async throws -> AutomationContent
}

/// Identidade efêmera fixada antes de abrir um painel. PID evita capturar uma
/// nova instância do mesmo app; nunca é persistido, exibido ou incluído em logs.
struct SelectionCaptureTarget: Sendable, Equatable {
    let processIdentifier: Int32
    let bundleIdentifier: String
}

/// Leitura AX somente sob ação explícita. A fila serial possui todos os objetos AX;
/// o MainActor fixa e revalida o aplicativo. O watchdog pode devolver timeout, mas
/// uma resposta AX tardia nunca substitui o resultado já concluído.
final class SelectionCaptureService: SelectedTextCapturing {
    private let queue = DispatchQueue(label: "Tico.content.selection", qos: .userInitiated)

    @MainActor
    func frontmostTarget(expectedBundleIdentifier: String? = nil) -> SelectionCaptureTarget? {
        guard let application = NSWorkspace.shared.frontmostApplication,
              application.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let bundleIdentifier = application.bundleIdentifier,
              expectedBundleIdentifier.map({ $0 == bundleIdentifier }) ?? true else { return nil }
        return SelectionCaptureTarget(processIdentifier: application.processIdentifier,
                                      bundleIdentifier: bundleIdentifier)
    }

    func capture() async throws -> AutomationContent {
        guard let target = await frontmostTarget() else { throw ContentActionError.selectionUnavailable }
        return try await capture(expectedTarget: target)
    }

    /// Um painel só autoriza ler o alvo fixado antes de aparecer. Se o usuário
    /// trocar de app ou o processo original reiniciar, falha sem mudar o foco.
    func capture(expectedTarget target: SelectionCaptureTarget) async throws -> AutomationContent {
        try Task.checkCancellation()
        guard AXIsProcessTrusted() else { throw ContentActionError.permissionRequired }
        guard await frontmostTarget() == target else { throw ContentActionError.focusChanged }
        let pid = target.processIdentifier
        let resolver = SelectionCaptureResolver()
        let content = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                resolver.install(continuation)
                queue.async {
                    guard !resolver.isFinished else { return }
                    do { resolver.finish(.success(try Self.readSelection(processIdentifier: pid, isCancelled: { resolver.isFinished }))) }
                    catch let error as ContentActionError { resolver.finish(.failure(error)) }
                    catch { resolver.finish(.failure(.selectionUnavailable)) }
                }
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.5) {
                    resolver.finish(.failure(.captureTimedOut))
                }
            }
        } onCancel: {
            resolver.finish(.failure(.cancelled))
        }
        try Task.checkCancellation()
        guard await frontmostTarget() == target else { throw ContentActionError.focusChanged }
        return content
    }

    private static func readSelection(processIdentifier: pid_t, isCancelled: () -> Bool) throws -> AutomationContent {
        try requireFocusedApplication(processIdentifier)
        let app = AXUIElementCreateApplication(processIdentifier)
        AXUIElementSetMessagingTimeout(app, 0.15)
        guard let element = AccessibilityValueDecoder.element(attribute(kAXFocusedUIElementAttribute, of: app)) else {
            throw ContentActionError.selectionUnavailable
        }
        AXUIElementSetMessagingTimeout(element, 0.15)
        try rejectProtectedElement(element, isCancelled: isCancelled)
        // A faixa é consultada antes do conteúdo para limitar a leitura. Nunca
        // consultamos AXValue, clipboard, documento inteiro ou atalhos de cópia.
        guard !isCancelled() else { throw ContentActionError.cancelled }
        guard let rawRange = attribute(kAXSelectedTextRangeAttribute, of: element),
              CFGetTypeID(rawRange) == AXValueGetTypeID() else {
            throw ContentActionError.selectionUnavailable
        }
        let axRange = unsafeBitCast(rawRange, to: AXValue.self) // CFTypeID validado acima.
        var range = CFRange()
        guard AXValueGetType(axRange) == .cfRange, AXValueGetValue(axRange, .cfRange, &range),
              range.location >= 0, range.length > 0 else { throw ContentActionError.emptyContent }
        guard range.length <= AutomationContent.maximumTextBytes else { throw ContentActionError.contentTooLarge }
        guard !isCancelled() else { throw ContentActionError.cancelled }
        try requireFocusedApplication(processIdentifier)
        guard let text = attribute(kAXSelectedTextAttribute, of: element) as? String else {
            throw ContentActionError.selectionUnavailable
        }
        guard !isCancelled() else { throw ContentActionError.cancelled }
        guard let current = AccessibilityValueDecoder.element(attribute(kAXFocusedUIElementAttribute, of: app)),
              CFEqual(current, element) else { throw ContentActionError.focusChanged }
        guard let rawFinalRange = attribute(kAXSelectedTextRangeAttribute, of: element),
              CFGetTypeID(rawFinalRange) == AXValueGetTypeID() else { throw ContentActionError.focusChanged }
        let finalRangeValue = unsafeBitCast(rawFinalRange, to: AXValue.self) // CFTypeID validado acima.
        var finalRange = CFRange()
        guard AXValueGetType(finalRangeValue) == .cfRange,
              AXValueGetValue(finalRangeValue, .cfRange, &finalRange),
              range.location == finalRange.location, range.length == finalRange.length else {
            throw ContentActionError.focusChanged
        }
        try requireFocusedApplication(processIdentifier)
        let content = AutomationContent.text(text)
        try content.validate()
        return content
    }

    /// O app frontmost do Workspace e o app com foco AX podem divergir com um
    /// NSPanel não ativante. Consultar ambos impede ler o painel ou um terceiro app.
    private static func requireFocusedApplication(_ expectedPID: pid_t) throws {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.15)
        guard let focused = AccessibilityValueDecoder.element(attribute(kAXFocusedApplicationAttribute, of: system)) else {
            throw ContentActionError.focusChanged
        }
        var focusedPID: pid_t = 0
        guard AXUIElementGetPid(focused, &focusedPID) == .success, focusedPID == expectedPID else {
            throw ContentActionError.focusChanged
        }
    }

    private static func rejectProtectedElement(_ element: AXUIElement, isCancelled: () -> Bool) throws {
        var current: AXUIElement? = element
        for _ in 0..<12 {
            guard !isCancelled() else { throw ContentActionError.cancelled }
            guard let node = current else { return }
            AXUIElementSetMessagingTimeout(node, 0.15)
            guard let role = attribute(kAXRoleAttribute, of: node) as? String else {
                throw ContentActionError.selectionUnavailable
            }
            let subrole = attribute(kAXSubroleAttribute, of: node) as? String
            if role == "AXSecureTextField" || subrole == "AXSecureTextField"
                || (attribute("AXProtectedContent", of: node) as? Bool == true) {
                throw ContentActionError.secureField
            }
            if role == kAXWindowRole || role == kAXApplicationRole { return }
            current = AccessibilityValueDecoder.element(attribute(kAXParentAttribute, of: node))
        }
        // Uma árvore que não pode ser verificada por completo falha fechada.
        if current != nil { throw ContentActionError.selectionUnavailable }
    }

    private static func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
}

/// `lock` protege resultado, continuação e conclusão única entre fila AX,
/// cancelamento e timeout. Nenhum AXUIElement atravessa essa fronteira.
private final class SelectionCaptureResolver: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<AutomationContent, Error>?
    private var result: Result<AutomationContent, ContentActionError>?

    var isFinished: Bool {
        lock.lock()
        defer { lock.unlock() }
        return result != nil
    }

    func install(_ continuation: CheckedContinuation<AutomationContent, Error>) {
        lock.lock()
        if let result {
            lock.unlock()
            continuation.resume(with: result.mapError { $0 as Error })
        } else {
            self.continuation = continuation
            lock.unlock()
        }
    }

    func finish(_ result: Result<AutomationContent, ContentActionError>) {
        lock.lock()
        guard self.result == nil else { lock.unlock(); return }
        self.result = result
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result.mapError { $0 as Error })
    }
}
