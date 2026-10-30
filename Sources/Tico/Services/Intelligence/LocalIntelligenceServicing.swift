import Foundation

/// Fronteira compartilhada pelos dois fluxos. Só devolve propostas; não possui
/// executor, acesso à seleção, clipboard, persistência ou ferramentas do modelo.
protocol LocalIntelligenceServicing: Sendable {
    func availability() async -> LocalIntelligenceAvailability
    func automationDraft(from text: String, applications: [ApplicationChoice],
                         recordedTrigger: TriggerDefinition?) async throws -> ShortcutRule
    func transform(_ text: String, operation: ContentTransformation) async throws -> String
}
