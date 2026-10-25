import Foundation

struct GesturePreset: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var summary: String
    var trigger: TriggerDefinition
    var workflow: ActionWorkflow
    var scope: RuleScope
    var conditions: [RuleCondition]
    var priority: Int
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        summary: String = "",
        trigger: TriggerDefinition,
        workflow: ActionWorkflow,
        scope: RuleScope = .global,
        conditions: [RuleCondition] = [],
        priority: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.trigger = trigger
        self.workflow = workflow
        self.scope = scope
        self.conditions = conditions
        self.priority = priority
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, summary, trigger, workflow, scope, conditions, priority, createdAt
    }

    /// Modelos antigos só guardavam uma associação externa. Os novos carregam
    /// o contexto explicitamente, como as regras independentes que irão criar.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        summary = try container.decode(String.self, forKey: .summary)
        trigger = try container.decode(TriggerDefinition.self, forKey: .trigger)
        workflow = try container.decode(ActionWorkflow.self, forKey: .workflow)
        scope = try container.decodeIfPresent(RuleScope.self, forKey: .scope) ?? .global
        conditions = try container.decodeIfPresent([RuleCondition].self, forKey: .conditions) ?? []
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 0
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}
