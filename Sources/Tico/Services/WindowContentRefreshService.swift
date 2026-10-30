import AppKit
import ApplicationServices
import Foundation

protocol WindowContentRefreshing {
    func refreshFrontmostWindow() async throws
}

enum WindowContentRefreshError: LocalizedError {
    case accessibilityRequired
    case applicationUnavailable
    case windowUnavailable
    case focusChanged
    case commandUnavailable
    case ambiguousCommand
    case timedOut
    case resultUnknown

    var errorDescription: String? {
        switch self {
        case .accessibilityRequired:
            "Conceda Acessibilidade ao Tico para atualizar a janela."
        case .applicationUnavailable:
            "Não há outro aplicativo em primeiro plano para atualizar."
        case .windowUnavailable:
            "Não há uma janela ativa acessível neste aplicativo."
        case .focusChanged:
            "O aplicativo ou a janela em uso mudou antes da atualização."
        case .commandUnavailable:
            "Não encontrei um comando de atualização acessível nesta janela."
        case .ambiguousCommand:
            "Este aplicativo oferece mais de um comando de atualização; nenhum foi executado."
        case .timedOut:
            "O aplicativo demorou a responder; a atualização não foi solicitada."
        case .resultUnknown:
            "Não foi possível confirmar se o comando de atualização foi executado."
        }
    }
}

/// Consulta apenas menus conhecidos e a barra de ferramentas da janela em foco.
/// A fila serial é dona dos elementos AX; títulos são usados só para localizar o
/// comando e nunca são persistidos ou registrados. O foco é revalidado antes do efeito.
/// Paralelo com React: é uma fronteira de efeito nativo, não estado da interface.
final class WindowContentRefreshService: WindowContentRefreshing {
    private let queue = DispatchQueue(label: "Tico.window.refresh", qos: .userInitiated)

    func refreshFrontmostWindow() async throws {
        try Task.checkCancellation()
        guard AXIsProcessTrusted() else { throw WindowContentRefreshError.accessibilityRequired }
        guard let pid = await Self.frontmostProcessIdentifier() else {
            throw WindowContentRefreshError.applicationUnavailable
        }

        let resolver = WindowRefreshResolver()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                resolver.install(continuation)
                queue.async {
                    do {
                        try Self.requestRefresh(processIdentifier: pid, resolver: resolver)
                        resolver.finish(.success(()))
                    } catch {
                        resolver.finish(.failure(error))
                    }
                }
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
                    resolver.expire()
                }
            }
        } onCancel: {
            resolver.cancel()
        }
    }

    @MainActor
    private static func frontmostProcessIdentifier() -> pid_t? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        return app.processIdentifier
    }

    private static func requestRefresh(processIdentifier pid: pid_t, resolver: WindowRefreshResolver) throws {
        try requireFocusedApplication(pid)
        let app = AXUIElementCreateApplication(pid)
        guard let window = element(kAXFocusedWindowAttribute, of: app) else {
            throw WindowContentRefreshError.windowUnavailable
        }

        let menuCandidates = candidatesInMenu(of: app, resolver: resolver)
        let candidates = menuCandidates.isEmpty ? candidatesInToolbar(of: window, resolver: resolver) : menuCandidates
        guard !resolver.isFinished else { return }
        guard !candidates.isEmpty else { throw WindowContentRefreshError.commandUnavailable }
        guard candidates.count == 1, let command = candidates.first else {
            throw WindowContentRefreshError.ambiguousCommand
        }
        try requireFocusedApplication(pid)
        guard let currentWindow = element(kAXFocusedWindowAttribute, of: app), CFEqual(window, currentWindow) else {
            throw WindowContentRefreshError.focusChanged
        }
        guard resolver.beginEffect() else { return }
        let result = AXUIElementPerformAction(command, kAXPressAction as CFString)
        guard result == .success else {
            if result == .cannotComplete { throw WindowContentRefreshError.resultUnknown }
            throw WindowContentRefreshError.commandUnavailable
        }
    }

    private static func candidatesInMenu(of app: AXUIElement, resolver: WindowRefreshResolver) -> [AXUIElement] {
        guard let bar = element(kAXMenuBarAttribute, of: app) else { return [] }
        var matches: [AXUIElement] = []
        for item in children(of: bar).prefix(16) where !resolver.isFinished {
            guard let title = string(kAXTitleAttribute, of: item), menuTitles.contains(normalized(title)) else { continue }
            for menu in children(of: item).prefix(1) {
                for candidate in children(of: menu).prefix(80) where !resolver.isFinished {
                    if isRefreshCommand(candidate, role: kAXMenuItemRole) { matches.append(candidate) }
                }
            }
        }
        return matches
    }

    private static func candidatesInToolbar(of window: AXUIElement, resolver: WindowRefreshResolver) -> [AXUIElement] {
        var matches: [AXUIElement] = []
        for toolbar in children(of: window).prefix(32) where !resolver.isFinished {
            guard string(kAXRoleAttribute, of: toolbar) == kAXToolbarRole else { continue }
            for item in children(of: toolbar).prefix(80) where !resolver.isFinished {
                if isRefreshCommand(item, role: kAXButtonRole) { matches.append(item) }
                if string(kAXRoleAttribute, of: item) == kAXGroupRole {
                    for candidate in children(of: item).prefix(40) where !resolver.isFinished {
                        if isRefreshCommand(candidate, role: kAXButtonRole) { matches.append(candidate) }
                    }
                }
            }
        }
        return matches
    }

    private static func isRefreshCommand(_ item: AXUIElement, role: String) -> Bool {
        guard string(kAXRoleAttribute, of: item) == role,
              attribute(kAXEnabledAttribute, of: item) as? Bool == true else { return false }
        let labels = [string(kAXTitleAttribute, of: item), string(kAXDescriptionAttribute, of: item)]
        guard labels.compactMap({ $0 }).contains(where: { commandTitles.contains(normalized($0)) }) else { return false }
        var actions: CFArray?
        guard AXUIElementCopyActionNames(item, &actions) == .success,
              let names = actions as? [String] else { return false }
        return names.contains(kAXPressAction)
    }

    private static let menuTitles: Set<String> = [
        "view", "visualizar", "exibir", "visualizacao", "navigation", "navegacao", "data", "dados", "actions", "acoes"
    ]
    private static let commandTitles: Set<String> = [
        "reload", "refresh", "reload page", "reload this page", "reload current page", "refresh page",
        "refresh this page", "reload tab", "refresh tab", "reload window", "refresh window",
        "recarregar", "atualizar", "recarregar pagina", "recarregar a pagina", "recarregar esta pagina",
        "atualizar pagina", "atualizar a pagina", "atualizar esta pagina", "recarregar aba", "atualizar aba",
        "recarregar janela", "atualizar janela", "recarregar janela atual", "atualizar janela atual"
    ]

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func requireFocusedApplication(_ pid: pid_t) throws {
        let system = AXUIElementCreateSystemWide()
        guard let focused = element(kAXFocusedApplicationAttribute, of: system) else {
            throw WindowContentRefreshError.focusChanged
        }
        var focusedPID: pid_t = 0
        guard AXUIElementGetPid(focused, &focusedPID) == .success, focusedPID == pid else {
            throw WindowContentRefreshError.focusChanged
        }
    }

    private static func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
        AXUIElementSetMessagingTimeout(element, 0.15)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }

    private static func element(_ name: String, of parent: AXUIElement) -> AXUIElement? {
        AccessibilityValueDecoder.element(attribute(name, of: parent))
    }

    private static func string(_ name: String, of element: AXUIElement) -> String? {
        attribute(name, of: element) as? String
    }

    private static func children(of element: AXUIElement) -> [AXUIElement] {
        attribute(kAXChildrenAttribute, of: element) as? [AXUIElement] ?? []
    }
}

/// O lock garante conclusão única entre fila AX, prazo e cancelamento. Após o
/// início do efeito, um timeout informa resultado incerto e nunca tenta repetir.
private final class WindowRefreshResolver: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var result: Result<Void, Error>?
    private var effectStarted = false

    var isFinished: Bool {
        lock.lock()
        defer { lock.unlock() }
        return result != nil
    }

    func install(_ continuation: CheckedContinuation<Void, Error>) {
        lock.lock()
        if let result {
            lock.unlock()
            continuation.resume(with: result)
        } else {
            self.continuation = continuation
            lock.unlock()
        }
    }

    func beginEffect() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard result == nil else { return false }
        effectStarted = true
        return true
    }

    func cancel() {
        lock.lock()
        let error: Error = effectStarted ? WindowContentRefreshError.resultUnknown : CancellationError()
        finishLocked(.failure(error))
    }

    func expire() {
        lock.lock()
        let error: WindowContentRefreshError = effectStarted ? .resultUnknown : .timedOut
        finishLocked(.failure(error))
    }

    func finish(_ result: Result<Void, Error>) {
        lock.lock()
        finishLocked(result)
    }

    private func finishLocked(_ result: Result<Void, Error>) {
        guard self.result == nil else { lock.unlock(); return }
        self.result = result
        let continuation = self.continuation
        self.continuation = nil
        lock.unlock()
        continuation?.resume(with: result)
    }
}
