import Foundation

/// Projeções efêmeras da prévia. IDs aleatórios referenciam handles mantidos no
/// serviço, sem revelar dados do processo ou o conteúdo das janelas à interface.
struct SceneLayoutPreview: Identifiable, Sendable {
    /// Sessão e serviço compartilham o prazo; aprovar nunca aceita handles que a
    /// interface ainda apresenta como válidos, mas que o serviço já considera vencidos.
    static let validityDuration: TimeInterval = 5 * 60
    var id: UUID
    var workflowID: UUID
    var displays: [SceneLayoutDisplay]
    var windows: [SceneLayoutPreviewWindow]
    var notices: [String]
    var createdAt: Date
    var canApply: Bool { !windows.isEmpty && windows.allSatisfy { $0.issue == nil && $0.selectedWindowID != nil } }
}

struct SceneLayoutDisplay: Identifiable, Hashable, Sendable {
    var role: SceneLayoutDisplayRole
    var frame: SceneLayoutRect
    var isPrimary: Bool
    var id: SceneLayoutDisplayRole { role }
}

struct SceneLayoutPreviewWindow: Identifiable, Sendable {
    var id: UUID
    var applicationName: String
    var sourceFrame: SceneLayoutRect?
    var sourceDisplay: SceneLayoutDisplayRole?
    var targetFrame: SceneLayoutRect?
    var targetDisplay: SceneLayoutDisplayRole?
    var choices: [SceneLayoutWindowChoice]
    var selectedWindowID: UUID?
    var issue: String?
}

struct SceneLayoutWindowChoice: Identifiable, Sendable {
    var id: UUID
    var label: String
}

struct SceneLayoutCapture: Sendable {
    var plan: SceneLayoutPlan
    var notices: [String]
}

struct SceneLayoutRecovery: Identifiable, Sendable {
    var workflowID: UUID
    var pendingWindowCount: Int
    var results: [WorkflowStepExecution]
    var id: UUID { workflowID }
}
