import Combine
import Foundation

/// Owner da interação e da recuperação enquanto o Tico estiver aberto. A revisão
/// suspende o mesmo executor depois das ações, sem disparar uma segunda execução.
/// Paralelo com React: estado compartilhado e callbacks observados pelas views;
/// handles AX e efeitos permanecem no actor, fora da composição visual.
@MainActor
final class SceneLayoutSession: ObservableObject {
    private struct ReviewRequest {
        let id: UUID
        let workflowID: UUID
        let sourceWorkflow: ActionWorkflow
        let deadline: Date
        let continuation: CheckedContinuation<Bool, Never>
    }
    private enum Interaction {
        case standalone
        case review(UUID)
    }

    @Published private(set) var preview: SceneLayoutPreview?
    @Published private(set) var recoveries: [UUID: SceneLayoutRecovery] = [:]
    @Published private(set) var isBusy = false
    @Published private(set) var reviewIsBusy = false
    @Published private(set) var message: String?
    @Published private(set) var captureNotices: [String] = []
    @Published private(set) var pendingReviewWorkflow: ActionWorkflow?
    @Published private(set) var resumedWorkflowID: UUID?
    @Published private(set) var lastResumeReport: WorkflowExecutionReport?
    /// Lookup estreito do owner persistido. O coordenador compõe regras e cenas;
    /// a sessão não lê arquivos nem guarda uma segunda coleção.
    var workflowSource: ((ActionWorkflow) -> ActionWorkflow?)?
    var interactionIsSuspended = false {
        didSet {
            guard interactionIsSuspended else { return }
            let previousWorkflow = preview?.workflowID
            cancelOperation()
            revision = UUID()
            preview = nil
            if let previousWorkflow { Task { await service.invalidate(workflowID: previousWorkflow) } }
        }
    }
    private let service: any SceneLayoutServicing
    private let allowsExecution: Bool
    private let reviewPresenter: SceneLayoutReviewPresenter
    private var operation: Task<Void, Never>?
    private var operationOwnerID: UUID?
    private var previewTask: Task<SceneLayoutPreview, Error>?
    private var reviewTimer: Task<Void, Never>?
    private var pendingReview: ReviewRequest?
    private var revision = UUID()
    private var reservation: (token: UUID, workflowID: UUID)?
    private var remainingResumeTime: TimeInterval = 0
    private var resumeTask: Task<Void, Never>?
    private var resumedSourceWorkflow: ActionWorkflow?

    /// Prazo de atenção humana, independente do orçamento de efeitos. A expiração
    /// libera a reserva e os handles; somente uma decisão posterior reconsulta alvos.
    private let reviewDuration = SceneLayoutPreview.validityDuration

    var hasPendingRecovery: Bool { recoveries.values.contains { $0.pendingWindowCount > 0 } }
    var canApproveReview: Bool {
        guard let pendingReview else { return false }
        return !interactionIsSuspended && !reviewIsBusy && !hasPendingRecovery
            && Date() < pendingReview.deadline && preview?.workflowID == pendingReview.workflowID
            && preview?.canApply == true
    }

    init(service: any SceneLayoutServicing = SceneLayoutService(), allowsExecution: Bool = true,
         reviewPresenter: SceneLayoutReviewPresenter? = nil) {
        self.service = service
        self.allowsExecution = allowsExecution
        self.reviewPresenter = reviewPresenter ?? SceneLayoutReviewPresenter()
    }

    /// Diagnóstico sem efeitos; a exclusão é garantida por acquireReservation,
    /// que verifica e reserva atomicamente no mesmo turno do MainActor.
    func preflightIssue() -> String? {
        if !allowsExecution || interactionIsSuspended { return SceneLayoutError.disabled.localizedDescription }
        if isBusy { return SceneLayoutError.busy.localizedDescription }
        if hasPendingRecovery { return SceneLayoutError.pendingRecovery.localizedDescription }
        return nil
    }

    /// Reserva a sequência inteira, inclusive ações anteriores ao layout. O token
    /// identifica a execução, não apenas a cena: uma conclusão antiga não libera
    /// a reserva de uma nova tentativa com o mesmo workflowID.
    func acquireReservation(workflowID: UUID) throws -> UUID {
        try Task.checkCancellation()
        if let issue = preflightIssue() { throw SceneLayoutError.invalid(issue) }
        guard reservation == nil else { throw SceneLayoutError.busy }
        let token = UUID()
        reservation = (token, workflowID)
        isBusy = true
        message = nil
        return token
    }

    /// Chamado e aguardado pelo wrapper do executor após qualquer resultado,
    /// inclusive falha antes do layout e cancelamento durante delay/aprovação.
    func releaseReservation(_ token: UUID) {
        guard let current = reservation, current.token == token else { return }
        if let request = pendingReview, request.workflowID == current.workflowID {
            finishReview(id: request.id, accepted: false)
        }
        reservation = nil
        preview = nil
        isBusy = false
    }

    func capture() async -> SceneLayoutPlan? {
        guard beginOperation() else { return nil }
        captureNotices = []
        defer { isBusy = false }
        do {
            let result = try await service.capture()
            guard !interactionIsSuspended, !Task.isCancelled else { return nil }
            captureNotices = result.notices
            return result.plan
        } catch { message = error.localizedDescription; return nil }
    }

    /// Durante a revisão apenas o workflow pendente pode atualizar a prévia.
    /// A trava global continua ativa; captura e restauração não se intercalam.
    func prepare(workflow: ActionWorkflow) async {
        guard let plan = workflow.sceneLayout, let interaction = beginInteraction(workflowID: workflow.id) else { return }
        let request = UUID()
        revision = request
        preview = nil
        let task = Task { try await service.prepare(plan: plan, workflowID: workflow.id) }
        previewTask = task
        defer {
            endInteraction(interaction)
            if revision == request { previewTask = nil }
        }
        do {
            let result = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: { task.cancel() }
            guard revision == request, isCurrent(interaction), !interactionIsSuspended, !Task.isCancelled else { return }
            preview = result
        } catch { if revision == request { message = error.localizedDescription } }
    }

    func selectWindow(workflowID: UUID, slotID: UUID, windowID: UUID?) async {
        guard let interaction = beginInteraction(workflowID: workflowID) else { return }
        defer { endInteraction(interaction) }
        do {
            let result = try await service.select(workflowID: workflowID, slotID: slotID, windowID: windowID)
            guard isCurrent(interaction), !interactionIsSuspended, !Task.isCancelled else { return }
            preview = result
        } catch { message = error.localizedDescription }
    }

    func identify(workflowID: UUID, slotID: UUID) async {
        guard let interaction = beginInteraction(workflowID: workflowID) else { return }
        defer { endInteraction(interaction) }
        do { try await service.identify(workflowID: workflowID, slotID: slotID) }
        catch { message = error.localizedDescription }
    }

    func invalidate(workflowID: UUID) async {
        if pendingReviewWorkflow?.id == workflowID { discardPendingReview() }
        if pendingReview?.workflowID == workflowID { resolveReview(workflowID: workflowID, accepted: false) }
        revision = UUID()
        if preview?.workflowID == workflowID { preview = nil }
        await service.invalidate(workflowID: workflowID)
    }

    /// O orçamento de efeitos inclui consulta e aplicação, mas não a leitura
    /// humana. A revisão confirma apenas o layout depois de abrir os apps.
    /// A reserva pertence ao mesmo executor e é liberada em todos os retornos.
    func execute(workflow: ActionWorkflow, deadline: Date, reservationToken: UUID,
                 requiresReview: Bool = true) async -> [WorkflowStepExecution] {
        guard let plan = workflow.sceneLayout else { return [] }
        guard let current = reservation, current.token == reservationToken,
              current.workflowID == workflow.id else {
            return failure(workflowID: workflow.id, message: "A reserva desta execução não está mais disponível.")
        }
        guard allowsExecution, !interactionIsSuspended else {
            return failure(workflowID: workflow.id, message: SceneLayoutError.disabled.localizedDescription)
        }
        guard !hasPendingRecovery else {
            return failure(workflowID: workflow.id, message: SceneLayoutError.pendingRecovery.localizedDescription)
        }
        defer { preview = nil }
        let results: [WorkflowStepExecution]
        do {
            try Task.checkCancellation()
            guard Date() < deadline else { throw SceneLayoutError.invalid("O tempo limite terminou antes da revisão do layout.") }
            await service.invalidate(workflowID: workflow.id)
            do {
                preview = try await service.prepare(plan: plan, workflowID: workflow.id)
                if !requiresReview {
                    try await waitForLaunchedWindows(workflow: workflow, plan: plan, deadline: deadline)
                }
            } catch {
                if !requiresReview || error is CancellationError { throw error }
                message = error.localizedDescription
            }
            try Task.checkCancellation()
            guard Date() < deadline else { throw SceneLayoutError.invalid("O tempo limite terminou durante a consulta das janelas.") }
            var applicationDeadline = deadline
            if requiresReview {
                let remainingEffectTime = deadline.timeIntervalSinceNow
                guard await requestReview(workflow: workflow, remainingEffectTime: remainingEffectTime) else {
                    throw SceneLayoutError.invalid(message ?? "Layout cancelado. As ações anteriores já executadas foram preservadas.")
                }
                // Congela o saldo antes da revisão. Não reinicia o workflow nem
                // concede novamente o tempo já consumido pelas ações anteriores.
                applicationDeadline = Date().addingTimeInterval(remainingEffectTime)
            }
            try Task.checkCancellation()
            results = try await service.apply(plan: plan, workflowID: workflow.id, deadline: applicationDeadline)
        } catch {
            message = error is CancellationError ? "Layout cancelado; a recuperação disponível foi preservada." : error.localizedDescription
            results = failure(workflowID: workflow.id, message: message ?? "Não foi possível aplicar o layout.")
        }
        await service.invalidate(workflowID: workflow.id)
        let pending = await service.pendingRecovery(workflowID: workflow.id)
        if pending.pendingWindowCount > 0 { recoveries[workflow.id] = pending }
        return results
    }

    func resolveReview(workflowID: UUID, accepted: Bool) {
        guard let request = pendingReview, request.workflowID == workflowID else { return }
        if accepted, currentSource(for: request.sourceWorkflow) != request.sourceWorkflow {
            message = "A cena mudou ou foi removida. Abra a versão atual para revisar novamente."
            finishReview(id: request.id, accepted: false)
            return
        }
        if accepted, !canApproveReview { return }
        if !accepted { message = "Layout cancelado. As ações anteriores já executadas foram preservadas." }
        finishReview(id: request.id, accepted: accepted)
    }

    func restore(workflowID: UUID) async {
        guard beginOperation() else { return }
        defer { isBusy = false }
        do {
            let result = try await service.restore(workflowID: workflowID)
            recoveries[workflowID] = result
            message = result.pendingWindowCount == 0
                ? "Disposição anterior restaurada e verificada."
                : "\(result.pendingWindowCount) janela(s) continuam pendentes. Revise os resultados antes de tentar novamente."
        } catch { message = error.localizedDescription }
    }

    /// A view confirma o descarte. Isso só libera handles; não altera janelas.
    func discardRecovery(workflowID: UUID) async {
        guard !isBusy else { return }
        do {
            try await service.discardRecovery(workflowID: workflowID)
            recoveries.removeValue(forKey: workflowID)
            message = nil
        } catch { message = error.localizedDescription }
    }

    func perform(ownerID: UUID? = nil, _ action: @escaping @MainActor () async -> Void) {
        guard operation == nil else { return }
        operationOwnerID = ownerID
        operation = Task { [weak self] in
            await action()
            self?.operation = nil
            self?.operationOwnerID = nil
        }
    }

    func isPerforming(ownerID: UUID) -> Bool { operation != nil && operationOwnerID == ownerID }

    /// Fechar um editor cancela somente a consulta que ele iniciou.
    func cancelOperation(ownerID: UUID) {
        guard isPerforming(ownerID: ownerID) else { return }
        operation?.cancel()
    }

    func cancelOperation() {
        operation?.cancel()
        previewTask?.cancel()
        resumeTask?.cancel()
        if let request = pendingReview { finishReview(id: request.id, accepted: false) }
    }

    /// Timeout, fechamento, cancelamento da Task e botões convergem no mesmo ID.
    /// A continuação é removida antes de fechar a janela ou retomá-la, evitando
    /// dupla resolução e callbacks tardios de uma revisão anterior.
    private func requestReview(workflow: ActionWorkflow, remainingEffectTime: TimeInterval) async -> Bool {
        guard let source = resumedSourceWorkflow ?? currentSource(for: workflow),
              currentSource(for: source) == source else {
            message = "A cena mudou ou foi removida. Abra a versão atual para revisar novamente."
            return false
        }
        let id = UUID()
        let deadline = (preview?.createdAt ?? Date()).addingTimeInterval(reviewDuration)
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard !Task.isCancelled, !interactionIsSuspended, Date() < deadline else {
                    continuation.resume(returning: false)
                    return
                }
                pendingReview = .init(id: id, workflowID: workflow.id, sourceWorkflow: source,
                                      deadline: deadline, continuation: continuation)
                reviewIsBusy = false
                reviewTimer = Task { @MainActor [weak self] in
                    do { try await Task.sleep(for: .seconds(max(0, deadline.timeIntervalSinceNow))) }
                    catch { return }
                    guard let self, pendingReview?.id == id else { return }
                    guard currentSource(for: source) == source else {
                        message = "A cena mudou ou foi removida. Abra a versão atual para revisar novamente."
                        finishReview(id: id, accepted: false)
                        return
                    }
                    pendingReviewWorkflow = source
                    remainingResumeTime = remainingEffectTime
                    message = "A revisão foi pausada. Você pode retomá-la sem repetir as ações anteriores."
                    finishReview(id: id, accepted: false)
                }
                reviewPresenter.show(workflow: workflow, session: self, deadline: deadline, onClose: { [weak self] in
                    guard let self, pendingReview?.id == id else { return }
                    resolveReview(workflowID: workflow.id, accepted: false)
                })
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.finishReview(id: id, accepted: false) }
        }
    }

    /// Retoma somente a disposição após expirar a revisão. A cópia não possui
    /// steps: não abre apps, links, scripts nem repete efeitos já concluídos.
    /// Os handles antigos foram invalidados; execute prepara uma prévia nova.
    func resumePendingReview() {
        guard let saved = pendingReviewWorkflow, resumeTask == nil,
              preflightIssue() == nil, remainingResumeTime > 0 else { return }
        guard currentSource(for: saved) == saved else {
            discardPendingReview()
            message = "A cena mudou ou foi removida. Abra a versão atual para revisar novamente."
            return
        }
        var layoutOnly = saved
        layoutOnly.steps = []
        let budget = remainingResumeTime
        do {
            // Reserva antes de consumir a pendência, sem suspensão entre ambos.
            let token = try acquireReservation(workflowID: layoutOnly.id)
            discardPendingReview()
            resumedSourceWorkflow = saved
            resumedWorkflowID = saved.id
            resumeTask = Task { [weak self] in
                guard let self else { return }
                defer {
                    resumeTask = nil
                    resumedSourceWorkflow = nil
                    resumedWorkflowID = nil
                    releaseReservation(token)
                }
                let startedAt = Date()
                let results = await execute(workflow: layoutOnly, deadline: Date().addingTimeInterval(budget),
                                            reservationToken: token)
                lastResumeReport = WorkflowExecutionReport(workflowID: saved.id, stepExecutions: results,
                    startedAt: startedAt, finishedAt: Date(), wasCancelled: Task.isCancelled)
                if pendingReviewWorkflow == nil {
                    message = lastResumeReport?.success == true ? "Disposição aplicada e verificada."
                        : lastResumeReport?.summary.message
                }
            }
        } catch { message = error.localizedDescription }
    }

    /// O snapshot completo é a autorização desta retomada. Editar ou remover a
    /// origem invalida essa decisão; nunca usamos o payload truncado (steps=[]).
    func reconcileResumableWorkflows(_ workflows: [ActionWorkflow]) {
        if let request = pendingReview, !workflows.contains(request.sourceWorkflow) {
            message = "A cena mudou ou foi removida. Abra a versão atual para revisar novamente."
            finishReview(id: request.id, accepted: false)
        }
        if let pendingReviewWorkflow, !workflows.contains(pendingReviewWorkflow) {
            discardPendingReview()
            message = "A cena mudou ou foi removida. Abra a versão atual para revisar novamente."
        }
        if let resumedSourceWorkflow, !workflows.contains(resumedSourceWorkflow) {
            cancelOperation()
        }
    }

    private func currentSource(for workflow: ActionWorkflow) -> ActionWorkflow? {
        guard let workflowSource else { return workflow }
        return workflowSource(workflow)
    }

    func discardPendingReview() {
        pendingReviewWorkflow = nil
        remainingResumeTime = 0
    }

    private func finishReview(id: UUID, accepted: Bool) {
        guard let request = pendingReview, request.id == id else { return }
        pendingReview = nil
        revision = UUID()
        reviewTimer?.cancel()
        reviewTimer = nil
        previewTask?.cancel()
        previewTask = nil
        operation?.cancel()
        reviewIsBusy = false
        reviewPresenter.dismiss()
        request.continuation.resume(returning: accepted)
    }

    private func waitForLaunchedWindows(workflow: ActionWorkflow, plan: SceneLayoutPlan, deadline: Date) async throws {
        let launched = Set(workflow.enabledSteps.compactMap { step -> String? in
            if case let .openApplication(identifier) = step.action { return identifier }
            return nil
        })
        let limit = min(deadline, Date().addingTimeInterval(5))
        while Date() < limit, preview?.windows.contains(where: { row in
            row.choices.isEmpty && plan.windows.contains { $0.id == row.id && launched.contains($0.bundleIdentifier) }
        }) == true {
            try await Task.sleep(for: .milliseconds(250))
            preview = try await service.prepare(plan: plan, workflowID: workflow.id)
        }
    }

    private func beginOperation() -> Bool {
        guard allowsExecution, !interactionIsSuspended, !Task.isCancelled else {
            message = SceneLayoutError.disabled.localizedDescription
            return false
        }
        guard !isBusy else { message = SceneLayoutError.busy.localizedDescription; return false }
        isBusy = true
        message = nil
        return true
    }

    private func beginInteraction(workflowID: UUID) -> Interaction? {
        if let request = pendingReview, request.workflowID == workflowID {
            guard allowsExecution, !interactionIsSuspended, !Task.isCancelled,
                  !reviewIsBusy, Date() < request.deadline else { return nil }
            reviewIsBusy = true
            message = nil
            return .review(request.id)
        }
        return beginOperation() ? .standalone : nil
    }

    private func endInteraction(_ interaction: Interaction) {
        switch interaction {
        case .standalone: isBusy = false
        case .review(let id): if pendingReview?.id == id { reviewIsBusy = false }
        }
    }

    private func isCurrent(_ interaction: Interaction) -> Bool {
        switch interaction {
        case .standalone: true
        case .review(let id): pendingReview?.id == id
        }
    }

    private func failure(workflowID: UUID, message: String) -> [WorkflowStepExecution] {
        [.init(stepID: workflowID, stepName: "Layout de janelas", index: 0, result: .failed(message), duration: 0)]
    }
}
