import Foundation

/// Fronteira de efeitos consumida pela sessão. O isolamento Actor torna explícito
/// que os handles AX pertencem ao serviço e nunca são entregues à interface.
protocol SceneLayoutServicing: Actor {
    func capture() async throws -> SceneLayoutCapture
    func prepare(plan: SceneLayoutPlan, workflowID: UUID) async throws -> SceneLayoutPreview
    func select(workflowID: UUID, slotID: UUID, windowID: UUID?) async throws -> SceneLayoutPreview
    func identify(workflowID: UUID, slotID: UUID) async throws
    func invalidate(workflowID: UUID) async
    func apply(plan: SceneLayoutPlan, workflowID: UUID, deadline: Date) async throws -> [WorkflowStepExecution]
    func restore(workflowID: UUID) async throws -> SceneLayoutRecovery
    func pendingRecovery(workflowID: UUID) async -> SceneLayoutRecovery
    func discardRecovery(workflowID: UUID) async throws
}
