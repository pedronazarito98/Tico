import AppKit
import Foundation

/// Valores de AppKit capturados na main, antes de qualquer espera de contexto.
struct WindowDisplaySnapshot: Equatable, Sendable {
    let identifier: String
    let frame: CGRect
    let visibleFrame: CGRect
}
struct ContextEnvironmentSnapshot: Sendable {
    var processIdentifier: pid_t?
    var bundleIdentifier: String?
    var applicationName: String?
}
struct ContextSnapshotRequest: Sendable {
    let base: ContextSnapshot
    var requiresResolution = false
    var processIdentifier: pid_t?
    var displays: [WindowDisplaySnapshot] = []
    var focusGeneration: UInt64 = 0
    var budget = AXOperationBudget()
}

@MainActor
protocol ContextSnapshotProviding {
    /// Caminho barato e síncrono. Não consulta Accessibility.
    func snapshot(modifiers: Set<InputModifier>, at date: Date) -> ContextSnapshot
    func makeRequest(modifiers: Set<InputModifier>, at date: Date, includeWindowContext: Bool) -> ContextSnapshotRequest
    func resolve(_ request: ContextSnapshotRequest) async -> ContextSnapshot?
    func isCurrent(_ request: ContextSnapshotRequest) -> Bool
}

extension ContextSnapshotProviding {
    /// Provedores de contexto pronto (inclusive fakes) conservam o caminho
    /// imediato. O provedor de plataforma opta pela resolução AX assíncrona.
    func makeRequest(modifiers: Set<InputModifier>, at date: Date, includeWindowContext: Bool) -> ContextSnapshotRequest {
        ContextSnapshotRequest(base: snapshot(modifiers: modifiers, at: date))
    }
    func resolve(_ request: ContextSnapshotRequest) async -> ContextSnapshot? { request.base }
    func isCurrent(_ request: ContextSnapshotRequest) -> Bool { true }
}

/// MainActor possui AppKit e a geração de foco. A requisição fixa PID, telas e
/// flags no ingresso; resolve() nunca redireciona uma entrada antiga para o app
/// que ficou frontmost enquanto AX aguardava. Paralelo com React: request com
/// identidade capturada, validada novamente antes de publicar o resultado.
@MainActor
final class ContextSnapshotService: ContextSnapshotProviding {
    private let windowContextReader: any WindowContextReading
    private let captureEnvironment: @MainActor () -> ContextEnvironmentSnapshot
    private let captureDisplays: @MainActor () -> [WindowDisplaySnapshot]
    private var focusGeneration: UInt64 = 0
    private var focusObserver: NSObjectProtocol?
    private let notificationCenter: NotificationCenter

    init(workspace: NSWorkspace = .shared,
         windowContextReader: any WindowContextReading = WindowContextReader(),
         captureEnvironment: (@MainActor () -> ContextEnvironmentSnapshot)? = nil,
         captureDisplays: (@MainActor () -> [WindowDisplaySnapshot])? = nil) {
        self.windowContextReader = windowContextReader
        self.captureEnvironment = captureEnvironment ?? {
            let application = workspace.frontmostApplication
            return ContextEnvironmentSnapshot(processIdentifier: application?.processIdentifier,
                bundleIdentifier: application?.bundleIdentifier, applicationName: application?.localizedName)
        }
        self.captureDisplays = captureDisplays ?? {
            NSScreen.screens.map { screen in
                WindowDisplaySnapshot(identifier: screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")].map { String(describing: $0) } ?? "",
                    frame: screen.frame, visibleFrame: screen.visibleFrame)
            }
        }
        notificationCenter = workspace.notificationCenter
        focusObserver = notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.focusGeneration &+= 1 }
            }
    }

    deinit { if let focusObserver { notificationCenter.removeObserver(focusObserver) } }

    func snapshot(modifiers: Set<InputModifier>, at date: Date = Date()) -> ContextSnapshot {
        makeRequest(modifiers: modifiers, at: date, includeWindowContext: false).base
    }

    func makeRequest(modifiers: Set<InputModifier>, at date: Date, includeWindowContext: Bool) -> ContextSnapshotRequest {
        let environment = captureEnvironment()
        let requiresResolution = includeWindowContext && environment.processIdentifier != nil
        return ContextSnapshotRequest(base: ContextSnapshot(
            frontmostApplicationBundleIdentifier: environment.bundleIdentifier,
            frontmostApplicationName: environment.applicationName, modifiers: modifiers, capturedAt: date),
            requiresResolution: requiresResolution,
            processIdentifier: environment.processIdentifier, displays: requiresResolution ? captureDisplays() : [],
            focusGeneration: focusGeneration)
    }

    func isCurrent(_ request: ContextSnapshotRequest) -> Bool {
        request.focusGeneration == focusGeneration && request.processIdentifier == captureEnvironment().processIdentifier
    }

    func resolve(_ request: ContextSnapshotRequest) async -> ContextSnapshot? {
        guard isCurrent(request), !Task.isCancelled else { return nil }
        guard request.requiresResolution, let pid = request.processIdentifier else { return request.base }
        guard request.budget.remaining > 0 else { return nil }
        guard let window = await windowContextReader.focusedWindowContext(processIdentifier: pid, budget: request.budget),
              window.focusIsCurrent, isCurrent(request), !Task.isCancelled else { return nil }
        var result = request.base
        result.frontmostWindowTitle = window.title
        if let frame = window.frame {
            result.displayIdentifier = request.displays.first { display in
                display.frame.contains(CGPoint(x: frame.midX, y: display.frame.maxY - frame.midY))
            }?.identifier
        }
        return result
    }
}
