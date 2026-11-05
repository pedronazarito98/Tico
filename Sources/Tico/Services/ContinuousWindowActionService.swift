import AppKit
import ApplicationServices
import Foundation

/// Somente valores de AppKit cruzam para o worker. O token de foco vale para
/// .frontmost; um alvo explícito conserva seu PID e valida a janela via AX.
struct ContinuousWindowTarget: Sendable {
    let processIdentifier: pid_t
    let displays: [WindowDisplaySnapshot]
    var generation: CaptureGeneration? = nil
    var budget = AXOperationBudget()
    var isValid: Bool { generation?.isValid ?? true }
}

@MainActor
protocol ContinuousWindowActionControlling {
    func captureTarget(_ target: ApplicationTarget) -> ContinuousWindowTarget?
    func begin(sessionID: UUID, target: ApplicationTarget, operation: ContinuousWindowOperation,
               capturedTarget: ContinuousWindowTarget?) throws
    func update(sessionID: UUID, progress: Double, curve: ContinuousResponseCurve) throws
    func commit(sessionID: UUID) -> ContinuousWindowCompletion
    func cancel(sessionID: UUID) -> ContinuousWindowCompletion
}

extension ContinuousWindowActionControlling {
    func captureTarget(_ target: ApplicationTarget) -> ContinuousWindowTarget? { nil }
    func begin(sessionID: UUID, target: ApplicationTarget, operation: ContinuousWindowOperation) throws {
        try begin(sessionID: sessionID, target: target, operation: operation, capturedTarget: captureTarget(target))
    }
}

/// Fachada MainActor captura NSWorkspace/NSScreen no ingresso. Begin/update e
/// terminais só inserem comandos; nenhum IPC fica aqui. O terminal retorna uma
/// confirmação aguardável depois que o worker encerrou qualquer escrita em voo.
@MainActor
final class ContinuousWindowActionService: ContinuousWindowActionControlling {
    private let worker: ContinuousWindowAXWorker
    private let capture: @MainActor (ApplicationTarget) -> ContinuousWindowTarget?
    private var focusGeneration = CaptureGeneration()
    private var focusObserver: NSObjectProtocol?
    private let notificationCenter: NotificationCenter

    init(workspace: NSWorkspace = .shared,
         accessibilityCheck: @escaping @Sendable () -> Bool = { AXIsProcessTrusted() },
         backend: (any ContinuousWindowAXOperating)? = nil,
         captureTarget: (@MainActor (ApplicationTarget) -> ContinuousWindowTarget?)? = nil,
         budgetFactory: @escaping @Sendable () -> AXOperationBudget = { AXOperationBudget() }) {
        worker = ContinuousWindowAXWorker(backend: backend ?? NativeContinuousWindowAX(accessibilityCheck: accessibilityCheck),
            budgetFactory: budgetFactory)
        capture = captureTarget ?? { target in
            let application: NSRunningApplication?
            switch target {
            case .frontmost: application = workspace.frontmostApplication
            case let .bundleIdentifier(identifier): application = NSRunningApplication.runningApplications(withBundleIdentifier: identifier).first
            }
            guard let application else { return nil }
            let displays = NSScreen.screens.map { screen in
                WindowDisplaySnapshot(identifier: screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")].map { String(describing: $0) } ?? "",
                    frame: screen.frame, visibleFrame: screen.visibleFrame)
            }
            return ContinuousWindowTarget(processIdentifier: application.processIdentifier, displays: displays, budget: budgetFactory())
        }
        notificationCenter = workspace.notificationCenter
        focusObserver = notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.focusGeneration.invalidate()
                    self?.focusGeneration = CaptureGeneration()
                }
            }
    }

    deinit { if let focusObserver { notificationCenter.removeObserver(focusObserver) } }

    func captureTarget(_ target: ApplicationTarget) -> ContinuousWindowTarget? {
        guard var result = capture(target) else { return nil }
        if target == .frontmost, result.generation == nil { result.generation = focusGeneration }
        return result
    }

    func begin(sessionID: UUID, target: ApplicationTarget, operation: ContinuousWindowOperation,
               capturedTarget: ContinuousWindowTarget?) throws {
        guard let capturedTarget else { throw WindowControlError.applicationNotRunning }
        try worker.begin(sessionID: sessionID, target: capturedTarget, operation: operation)
    }
    func update(sessionID: UUID, progress: Double, curve: ContinuousResponseCurve) throws {
        try worker.update(sessionID: sessionID, progress: progress, curve: curve)
    }
    func commit(sessionID: UUID) -> ContinuousWindowCompletion { worker.finish(sessionID: sessionID, outcome: .committed) }
    func cancel(sessionID: UUID) -> ContinuousWindowCompletion { worker.finish(sessionID: sessionID, outcome: .cancelled) }
}
