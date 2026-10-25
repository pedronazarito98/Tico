import Foundation

/// Fronteira de leitura dos documentos anteriores à remoção de Perfis (v8).
/// Não publica perfis nem participa da execução: incorpora as restrições nas
/// regras/modelos independentes e pausa regras associadas para revisão explícita.
/// O repository preserva o documento original antes de salvar a versão migrada.
/// Paralelo com React: normalização de um payload antigo na camada de dados,
/// antes de entregá-lo ao estado consumido pelos componentes.
struct LegacyShortcutContextMigration: Decodable {
    private let profiles: [UUID: Profile]

    private enum CodingKeys: String, CodingKey { case profiles }
    private enum AssociationKey: String, CodingKey { case profileID }

    init() { profiles = [:] }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let values = try container.decodeIfPresent([Profile].self, forKey: .profiles) ?? []
        guard values.count <= 200, Set(values.map(\.id)).count == values.count else {
            throw ShortcutStoreError.invalidDocument
        }
        for value in values {
            guard (-10...10).contains(value.priority), value.conditions.count <= 100,
                  value.applicationBundleIdentifiers.count <= 100,
                  value.applicationBundleIdentifiers.allSatisfy({ $0.utf8.count <= DocumentSecurityPolicy.maximumStringLength }) else {
                throw ShortcutStoreError.invalidDocument
            }
        }
        profiles = Dictionary(uniqueKeysWithValues: values.map { ($0.id, $0) })
    }

    func migrate(_ legacy: Rule) throws -> ShortcutRule {
        var rule = legacy.value
        guard let id = legacy.profileID else { return rule }
        let context = try inheritedContext(id: id, conditions: rule.conditions, priority: rule.priority)
        rule.conditions = context.conditions
        rule.priority = context.priority
        rule.isEnabled = false
        let notice = profiles[id] == nil
            ? "Migração: associação antiga ausente. Revise as condições antes de ativar este atalho."
            : "Migração: condições herdadas incorporadas ao atalho. Revise antes de ativar."
        let annotated = [rule.notes, notice].filter { !$0.isEmpty }.joined(separator: "\n\n")
        // Notas já no limite permanecem intactas; a migração não trunca conteúdo
        // nem rejeita um documento válido apenas por acrescentar esta explicação.
        if annotated.utf8.count <= DocumentSecurityPolicy.maximumStringLength {
            rule.notes = annotated
        }
        return rule
    }

    func migrate(_ legacy: Preset) throws -> GesturePreset {
        var preset = legacy.value
        guard let id = legacy.profileID else { return preset }
        let context = try inheritedContext(id: id, conditions: preset.conditions, priority: preset.priority)
        preset.conditions = context.conditions
        preset.priority = context.priority
        return preset
    }

    private func inheritedContext(id: UUID, conditions: [RuleCondition], priority: Int) throws
        -> (conditions: [RuleCondition], priority: Int) {
        guard (-10...10).contains(priority), conditions.count <= 100 else {
            throw ShortcutStoreError.invalidDocument
        }
        guard let profile = profiles[id] else {
            // Uma referência órfã nunca se converte silenciosamente em escopo global.
            return (conditions + [.application(bundleIdentifiers: [])], priority)
        }
        var inherited = conditions + profile.conditions
        if !profile.applicationBundleIdentifiers.isEmpty {
            inherited.append(.application(bundleIdentifiers: profile.applicationBundleIdentifiers))
        }
        return (inherited, priority + profile.priority)
    }

    struct Rule: Decodable {
        let value: ShortcutRule
        let profileID: UUID?

        init(from decoder: Decoder) throws {
            value = try ShortcutRule(from: decoder)
            profileID = try decoder.container(keyedBy: AssociationKey.self)
                .decodeIfPresent(UUID.self, forKey: .profileID)
        }
    }

    struct Preset: Decodable {
        let value: GesturePreset
        let profileID: UUID?

        init(from decoder: Decoder) throws {
            value = try GesturePreset(from: decoder)
            profileID = try decoder.container(keyedBy: AssociationKey.self)
                .decodeIfPresent(UUID.self, forKey: .profileID)
        }
    }

    private struct Profile: Decodable {
        let id: UUID
        let applicationBundleIdentifiers: Set<String>
        let conditions: [RuleCondition]
        let priority: Int
    }
}
