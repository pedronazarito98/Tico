import ApplicationServices
import Foundation

struct WindowContext: Equatable, Sendable {
    var title: String?
    var frame: CGRect?
    var focusIsCurrent = true
}

protocol WindowContextReading: Sendable {
    func focusedWindowContext(processIdentifier: pid_t, budget: AXOperationBudget) async -> WindowContext?
}

/// AXUIElement e IPC vivem exclusivamente nesta fila. Nenhum NSWorkspace ou
/// NSScreen cruza essa fronteira; retornam somente valores. O watchdog resolve
/// a espera em até o orçamento e descarta uma resposta síncrona tardia.
final class WindowContextReader: WindowContextReading, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.pedronazarito.Tico.window-context", qos: .userInitiated)
    private let operation: @Sendable (pid_t, AXOperationBudget) -> WindowContext?

    init(accessibilityCheck: @escaping @Sendable () -> Bool = { AXIsProcessTrusted() },
         operation: (@Sendable (pid_t, AXOperationBudget) -> WindowContext?)? = nil) {
        self.operation = operation ?? { pid, budget in
            guard accessibilityCheck() else { return WindowContext() }
            return Self.read(processIdentifier: pid, budget: budget)
        }
    }

    func focusedWindowContext(processIdentifier: pid_t, budget: AXOperationBudget) async -> WindowContext? {
        guard budget.remaining > 0 else { return nil }
        return await withCheckedContinuation { continuation in
            let reply = WindowContextReply(continuation)
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + budget.remaining) {
                budget.invalidate()
                reply.finish(nil)
            }
            queue.async { [operation] in
                guard budget.remaining > 0 else { reply.finish(nil); return }
                let result = operation(processIdentifier, budget)
                reply.finish(budget.remaining > 0 ? result : nil)
            }
        }
    }

    private static func read(processIdentifier: pid_t, budget: AXOperationBudget) -> WindowContext? {
        let app = AXUIElementCreateApplication(processIdentifier)
        do {
            guard let window = AccessibilityValueDecoder.element(try value(kAXFocusedWindowAttribute, of: app, budget: budget)) else { return WindowContext() }
            let title = try value(kAXTitleAttribute, of: window, budget: budget) as? String
            let origin = AccessibilityValueDecoder.point(try value(kAXPositionAttribute, of: window, budget: budget))
            let size = AccessibilityValueDecoder.size(try value(kAXSizeAttribute, of: window, budget: budget))
            let current = AccessibilityValueDecoder.element(try value(kAXFocusedWindowAttribute, of: app, budget: budget))
            guard let current, CFEqual(window, current), budget.remaining > 0 else { return nil }
            return WindowContext(title: title, frame: origin.flatMap { point in size.map { CGRect(origin: point, size: $0) } })
        } catch { return nil }
    }

    private static func value(_ attribute: String, of element: AXUIElement, budget: AXOperationBudget) throws -> CFTypeRef? {
        try budget.configure(element)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        if result == .noValue || result == .attributeUnsupported { return nil }
        guard result == .success, budget.remaining > 0 else { throw WindowControlError.operationFailed("consulta AX indisponível") }
        return value
    }
}

/// Resultado único disputado pelo owner serial e watchdog; a continuation é
/// retirada sob lock e retomada fora dele. Não retém payload depois de concluir.
private final class WindowContextReply: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<WindowContext?, Never>?
    init(_ continuation: CheckedContinuation<WindowContext?, Never>) { self.continuation = continuation }
    func finish(_ result: WindowContext?) {
        lock.lock(); let continuation = continuation; self.continuation = nil; lock.unlock()
        continuation?.resume(returning: result)
    }
}
