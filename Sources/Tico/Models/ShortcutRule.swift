import Foundation

struct ShortcutRule: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var isEnabled: Bool
    var trigger: TriggerDefinition
    var workflow: ActionWorkflow
    var scope: RuleScope
    var conditions: [RuleCondition]
    var priority: Int
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        isEnabled: Bool = true,
        trigger: TriggerDefinition,
        action: ShortcutAction,
        workflow: ActionWorkflow? = nil,
        scope: RuleScope = .global,
        conditions: [RuleCondition] = [],
        priority: Int = 0,
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.trigger = trigger
        self.workflow = workflow ?? ActionWorkflow(action: action)
        self.scope = scope
        self.conditions = conditions
        self.priority = priority
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case isEnabled
        case trigger
        case action
        case workflow
        case scope
        case profileID
        case conditions
        case priority
        case notes
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? .distantPast

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        trigger = try container.decode(TriggerDefinition.self, forKey: .trigger)
        if let decodedWorkflow = try container.decodeIfPresent(ActionWorkflow.self, forKey: .workflow) {
            workflow = decodedWorkflow
        } else {
            workflow = ActionWorkflow(
                action: try container.decode(ShortcutAction.self, forKey: .action)
            )
        }
        scope = try container.decodeIfPresent(RuleScope.self, forKey: .scope) ?? .global
        // Uma regra antiga isolada não pode perder uma restrição e ficar ativa.
        // O codec incorpora as condições herdadas; leituras avulsas ficam pausadas.
        if try container.decodeIfPresent(UUID.self, forKey: .profileID) != nil {
            isEnabled = false
        }
        conditions = try container.decodeIfPresent([RuleCondition].self, forKey: .conditions) ?? []
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? 0
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        self.createdAt = createdAt
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(trigger, forKey: .trigger)
        // Keep the legacy single action as a compatibility hint for older builds.
        try container.encode(action, forKey: .action)
        try container.encode(workflow, forKey: .workflow)
        try container.encode(scope, forKey: .scope)
        try container.encode(conditions, forKey: .conditions)
        try container.encode(priority, forKey: .priority)
        try container.encode(notes, forKey: .notes)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    var action: ShortcutAction {
        get {
            workflow.steps.first?.action
                ?? .notification(title: TicoBrand.displayName, body: "Workflow vazio")
        }
        set {
            if workflow.steps.isEmpty {
                workflow.steps = [WorkflowStep(action: newValue)]
            } else {
                workflow.steps[0].action = newValue
            }
        }
    }

    func matches(_ context: ContextSnapshot) -> Bool {
        isEnabled && scope.matches(context) && conditions.allSatisfy { $0.matches(context) }
    }

    var effectiveSpecificity: Int { scope.specificity + conditions.count }
}
