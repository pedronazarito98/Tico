import Foundation

struct GesturePreset: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var summary: String
    var trigger: TriggerDefinition
    var workflow: ActionWorkflow
    var profileID: UUID?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        summary: String = "",
        trigger: TriggerDefinition,
        workflow: ActionWorkflow,
        profileID: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.trigger = trigger
        self.workflow = workflow
        self.profileID = profileID
        self.createdAt = createdAt
    }
}

