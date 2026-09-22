import Combine
import Foundation

/// A janela mantém os rascunhos enquanto o usuário alterna entre linhas ou seções.
/// O store continua sendo a fonte persistida; salvar permanece uma ação explícita.
/// Paralelo com React: estado elevado ao pai preserva o formulário ao trocar a seleção.
@MainActor
final class RuleWorkspaceSession: ObservableObject {
    @Published private(set) var sessions: [UUID: RuleEditingSession] = [:]
    @Published var presentedEditor: RuleEditingSession?
    @Published var recentlyCreatedID: UUID?

    func create() {
        presentedEditor = RuleEditingSession(rule: ShortcutRule(
            name: "Novo atalho", isEnabled: true,
            trigger: .trackpad(gesture: .swipeLeft, fingerCount: 3),
            action: .window(target: .frontmost, operation: .leftHalf)
        ), isNew: true)
    }

    func edit(_ rule: ShortcutRule) {
        presentedEditor = session(for: rule)
    }

    func session(for rule: ShortcutRule) -> RuleEditingSession {
        if let session = sessions[rule.id] {
            session.receivePersisted(rule)
            return session
        }
        let session = RuleEditingSession(rule: rule)
        sessions[rule.id] = session
        return session
    }

    func synchronize(with rules: [ShortcutRule]) {
        let ids = Set(rules.map(\.id))
        sessions = sessions.filter { ids.contains($0.key) }
        for rule in rules { sessions[rule.id]?.receivePersisted(rule) }
    }
}
