import Foundation

/// Distingue uma intenção real do usuário de uma sugestão ou execução automática.
/// O aprendizado recebe somente conclusões de execuções, nunca eventos brutos.
enum AutomationExecutionOrigin: Sendable {
    case trigger
    case contextualPanel
    case contentPanel
    case scene
    case displayRoutine
}
