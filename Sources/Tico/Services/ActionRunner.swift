import Foundation

typealias ScriptApprovalHandler = (String) async -> Bool

final class ActionRunner {
    private let applicationLauncher: any ApplicationLaunching
    private let urlLauncher: any URLLaunching
    private let notificationService: any NotificationDelivering
    private let shellScriptRunner: any ShellScriptRunning
    private let appleScriptRunner: any AppleScriptRunning
    private let macOSShortcutRunner: any MacOSShortcutRunning
    private let inputActionService: any InputActionPerforming
    private let applicationController: any ApplicationControlling
    private let windowController: any WindowControlling
    private let scriptTimeout: TimeInterval
    private let now: () -> Date

    init(
        applicationLauncher: any ApplicationLaunching = ApplicationLauncher(),
        urlLauncher: any URLLaunching = URLLauncher(),
        notificationService: any NotificationDelivering = NotificationService(),
        shellScriptRunner: any ShellScriptRunning = ShellScriptRunner(),
        appleScriptRunner: any AppleScriptRunning = AppleScriptRunner(),
        macOSShortcutRunner: any MacOSShortcutRunning = MacOSShortcutRunner(),
        inputActionService: any InputActionPerforming = InputActionService(),
        applicationController: any ApplicationControlling = ApplicationControlService(),
        windowController: any WindowControlling = WindowControlService(),
        scriptTimeout: TimeInterval = 15,
        now: @escaping () -> Date = Date.init
    ) {
        self.applicationLauncher = applicationLauncher
        self.urlLauncher = urlLauncher
        self.notificationService = notificationService
        self.shellScriptRunner = shellScriptRunner
        self.appleScriptRunner = appleScriptRunner
        self.macOSShortcutRunner = macOSShortcutRunner
        self.inputActionService = inputActionService
        self.applicationController = applicationController
        self.windowController = windowController
        self.scriptTimeout = scriptTimeout
        self.now = now
    }

    func execute(
        _ action: ShortcutAction,
        scriptApproval: ScriptApprovalHandler? = nil
    ) async -> ActionExecutionResult {
        do {
            let message: String

            switch action {
            case let .openApplication(bundleIdentifier):
                try await applicationLauncher.launch(bundleIdentifier: bundleIdentifier)
                message = "Aplicativo aberto: \(bundleIdentifier)"

            case let .openURL(url):
                try urlLauncher.open(url)
                message = "URL aberta: \(url.absoluteString)"

            case let .notification(title, body):
                try await notificationService.deliver(title: title, body: body)
                message = "Notificação exibida: \(title)"

            case let .shellScript(command):
                guard let scriptApproval else {
                    return .failed("O script exige aprovação explícita.", executedAt: now())
                }
                let approved = await scriptApproval(command)
                guard approved else {
                    return .failed("A execução do script foi recusada.", executedAt: now())
                }

                let result = try await shellScriptRunner.run(
                    command: command,
                    approved: true,
                    timeout: scriptTimeout
                )
                guard result.succeeded else {
                    let reason = result.timedOut
                        ? "O script excedeu o tempo limite."
                        : "O script terminou com código \(result.terminationStatus): \(result.standardError)"
                    return .failed(reason, executedAt: now())
                }
                message = result.standardOutput.isEmpty
                    ? "Script executado com sucesso."
                    : result.standardOutput

            case let .appleScript(source):
                guard let scriptApproval else {
                    return .failed("O AppleScript exige aprovação explícita.", executedAt: now())
                }
                guard await scriptApproval(source) else {
                    return .failed("A execução do AppleScript foi recusada.", executedAt: now())
                }
                message = try await appleScriptRunner.run(
                    source: source,
                    approved: true,
                    timeout: scriptTimeout
                )

            case let .macOSShortcut(name, input):
                let output = try await macOSShortcutRunner.run(
                    name: name,
                    input: input,
                    timeout: scriptTimeout
                )
                message = output.isEmpty ? "Atalho “\(name)” executado." : output

            case let .keyboardShortcut(keyCode, modifiers):
                try inputActionService.sendKeyboardShortcut(
                    keyCode: keyCode,
                    modifiers: modifiers
                )
                message = "Atalho de teclado enviado."

            case let .setClipboard(text):
                try inputActionService.setClipboard(text)
                message = "Clipboard atualizado."

            case let .application(target, operation):
                try await applicationController.perform(operation, target: target)
                message = "Ação \(operation.displayName.lowercased()) aplicada ao aplicativo."

            case let .window(target, operation):
                try await windowController.perform(operation, target: target)
                message = "Janela: \(operation.displayName)."

            case .continuousWindow:
                return .failed(
                    "A ação contínua precisa de um gesto com fases.",
                    executedAt: now()
                )
            }

            return .succeeded(message, executedAt: now())
        } catch {
            return .failed(error.localizedDescription, executedAt: now())
        }
    }
}
