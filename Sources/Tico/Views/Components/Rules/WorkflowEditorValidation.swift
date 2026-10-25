import Foundation

/// Validação de formulário, sem efeitos. Evita salvar uma configuração incompleta
/// quando a entrada inválida está em uma ação recolhida ou posterior na sequência.
enum WorkflowEditorValidation {
    static func issue(in workflow: ActionWorkflow) -> String? {
        if let issue = workflow.sceneLayout?.validationIssue { return issue }
        guard workflow.isValid else { return "Mantenha uma ação ativa ou um layout de janelas válido." }
        for (index, step) in workflow.steps.enumerated() where step.isEnabled {
            if let issue = issue(in: step.action) { return "Ação \(index + 1): \(issue)" }
        }
        return nil
    }

    static func issue(in action: ShortcutAction) -> String? {
        switch action {
        case let .openURL(url):
            guard RuleURLValidator.isValidWebURL(url), let host = url.host, !host.isEmpty else {
                return "Informe um endereço completo, como https://example.com."
            }
        case let .openApplication(id):
            if id.isEmpty { return "Escolha um aplicativo." }
        case let .application(target, _), let .window(target, _), let .continuousWindow(target, _, _):
            if case let .bundleIdentifier(id) = target, id.isEmpty {
                return "Escolha o aplicativo que receberá esta ação."
            }
        case let .shellScript(command), let .appleScript(command):
            if command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Escreva o comando a executar." }
        case let .content(configuration):
            return configuration.validationMessage
        case let .macOSShortcut(name, _):
            if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Informe o nome do atalho do macOS." }
        default: break
        }
        return nil
    }
}
