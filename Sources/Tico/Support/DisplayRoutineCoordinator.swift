import Combine
import Foundation

/// A topologia precisa estabilizar antes de produzir uma intenção, nunca uma execução direta.
/// Sleep, bloqueio, prática, replay e pausa descartam o evento e estabelecem outra baseline.
/// Paralelo com React: um efeito com cleanup; debounce e callbacks têm um único owner.
@MainActor
final class DisplayRoutineCoordinator: ObservableObject {
    @Published private(set) var suggestion: DisplayRoutineSuggestion?
    @Published private(set) var statusMessage = "Rotinas de telas desativadas."
    @Published private(set) var topology: DisplayEnvironmentSnapshot?

    /// Projeção para a apresentação distinguir configuração habilitada de
    /// disponibilidade real durante pausa, prática, bloqueio ou repouso.
    var isObserving: Bool { store.isEnabled && canObserve }

    private let store: DisplayRoutineStore
    private let monitor: DisplayEnvironmentMonitor
    private let workflowLookup: (UUID) -> ActionWorkflow?
    private let isExecutionAllowed: () -> Bool
    private let onAutomaticExecution: (DisplayRoutineExecutionIntent) -> Void
    private let onExecutionContextChanged: () -> Void
    private var storeSubscription: AnyCancellable?
    private var stabilization: Task<Void, Never>?
    private var expiration: Task<Void, Never>?
    private var baseline: DisplayEnvironmentSnapshot?
    private var interruptions: Set<DisplayEnvironmentInterruption> = []
    private var started = false
    private var runtimeAvailable = false
    private var resuming = false
    private var issuedIntents: Set<UUID> = []
    private var lastOfferedAt: [UUID: Date] = [:]

    init(store: DisplayRoutineStore,
         workflowLookup: @escaping (UUID) -> ActionWorkflow?,
         isExecutionAllowed: @escaping () -> Bool,
         onAutomaticExecution: @escaping (DisplayRoutineExecutionIntent) -> Void,
         onExecutionContextChanged: @escaping () -> Void) {
        self.store = store
        monitor = DisplayEnvironmentMonitor()
        self.workflowLookup = workflowLookup
        self.isExecutionAllowed = isExecutionAllowed
        self.onAutomaticExecution = onAutomaticExecution
        self.onExecutionContextChanged = onExecutionContextChanged
        storeSubscription = store.$document.dropFirst().sink { [weak self] _ in
            // @Published envia antes da atribuição; o salto lê o documento já confirmado.
            Task { @MainActor [weak self] in self?.rebaseline() }
        }
    }

    deinit { stabilization?.cancel(); expiration?.cancel() }

    /// O composition root não deve chamar start em UI testing ou replay isolado.
    func start() {
        guard !started else { return }
        started = true
        rebaseline()
        monitor.start { [weak self] event in self?.receive(event) }
    }

    func stop() {
        started = false
        monitor.stop()
        cancelPending()
        interruptions.removeAll()
        baseline = nil
        onExecutionContextChanged()
        statusMessage = "Observação de telas interrompida."
    }

    func setRuntimeAvailable(_ available: Bool) {
        guard runtimeAvailable != available else { return }
        runtimeAvailable = available
        if available && started { beginResumeStabilization() } else { rebaseline() }
    }

    /// Também é chamado pelo root quando cenas forem editadas ou removidas.
    func rebaseline() {
        cancelPending()
        guard started else { onExecutionContextChanged(); return }
        topology = monitor.snapshot()
        baseline = topology
        onExecutionContextChanged()
        statusMessage = !store.isEnabled ? "Rotinas de telas desativadas."
            : (canObserve ? "Aguardando uma mudança estável nas telas." : "Rotinas pausadas durante esta atividade.")
    }

    func dismissSuggestion() {
        expiration?.cancel()
        expiration = nil
        suggestion = nil
        issuedIntents.removeAll()
    }

    func acceptSuggestion(routineID: UUID? = nil) -> DisplayRoutineExecutionIntent? {
        guard let suggestion,
              let intent = routineID.flatMap({ id in suggestion.intents.first { $0.routineID == id } })
                ?? (suggestion.intents.count == 1 ? suggestion.intents.first : nil),
              isCurrent(intent) else {
            dismissSuggestion()
            statusMessage = "A cena ou as telas mudaram. Aguarde uma nova sugestão."
            return nil
        }
        self.suggestion = nil
        expiration?.cancel()
        issuedIntents = [intent.id]
        return intent
    }

    /// Consome uma intenção uma única vez, imediatamente antes do executor central agir.
    func validate(intent: DisplayRoutineExecutionIntent) -> Bool {
        guard issuedIntents.remove(intent.id) != nil, isCurrent(intent) else {
            statusMessage = "A execução foi descartada porque o contexto mudou."
            return false
        }
        statusMessage = "Preparando \(intent.workflow.name.isEmpty ? "cena" : intent.workflow.name)."
        return true
    }

    /// Depois de consumida, a intenção continua ligada ao ambiente e à configuração
    /// que a autorizaram. O gate de busy e a expiração da sugestão não se aplicam à
    /// própria execução em voo; suspensão ou alteração do owner continuam valendo.
    func executionContextIsCurrent(_ intent: DisplayRoutineExecutionIntent) -> Bool {
        started && runtimeAvailable && interruptions.isEmpty && !resuming
            && store.isEnabled && intent.topology == monitor.snapshot()
            && store.routines.contains(intent.routine)
            && workflowLookup(intent.workflow.id) == intent.workflow
    }

    /// A execução silenciosa exige destino estável; ações de conteúdo e scripts usam sugestão.
    static func supportsAutomaticExecution(_ workflow: ActionWorkflow) -> Bool {
        workflow.isValid
            && (workflow.sceneLayout?.windows.allSatisfy { $0.selection == .singleWindow } ?? true)
            && workflow.enabledSteps.allSatisfy { step in
            switch step.action {
            case .openApplication, .openURL, .notification: return true
            case let .application(target, operation):
                if case .bundleIdentifier = target { return operation == .open || operation == .activate }
                return false
            case let .window(target, operation):
                if case .bundleIdentifier = target { return operation != .close && operation != .tileAll }
                return false
            default: return false
            }
        }
    }

    /// O mesmo gate do executor determina o texto da interface. Uma cena editada
    /// pode deixar de permitir execução automática sem mudar a rotina persistida.
    static func effectiveMode(for routine: DisplayRoutine, workflow: ActionWorkflow) -> DisplayRoutineMode {
        routine.mode == .automatic && supportsAutomaticExecution(workflow) ? .automatic : .suggest
    }

    static func automaticExecutionUnavailableReason(_ workflow: ActionWorkflow) -> String? {
        guard workflow.isValid else { return "Conclua a configuração da cena antes de ativar esta rotina." }
        if let layout = workflow.sceneLayout, layout.windows.contains(where: { $0.selection != .singleWindow }) {
            return "Esta cena pede que você escolha uma janela. Ela será oferecida para confirmação."
        }
        guard supportsAutomaticExecution(workflow) else {
            return "Esta cena contém ações que precisam de contexto ou aprovação. Ela será oferecida para confirmação."
        }
        return nil
    }

    private var canObserve: Bool {
        started && runtimeAvailable && interruptions.isEmpty && !resuming && isExecutionAllowed()
    }

    private func receive(_ event: DisplayEnvironmentEvent) {
        guard started else { return }
        switch event {
        case let .suspended(reason):
            interruptions.insert(reason)
            rebaseline()
        case let .resumed(reason, snapshot):
            interruptions.remove(reason)
            topology = snapshot
            beginResumeStabilization()
        case let .changed(snapshot):
            topology = snapshot
            stabilization?.cancel()
            dismissSuggestion()
            onExecutionContextChanged()
            if resuming { beginResumeStabilization(); return }
            guard canObserve, store.isEnabled, snapshot.totalCount > 0 else {
                baseline = snapshot
                return
            }
            guard snapshot != baseline else { return }
            statusMessage = "Aguardando as telas estabilizarem…"
            stabilization = Task { [weak self] in
                try? await Task.sleep(for: .seconds(2.5))
                guard !Task.isCancelled, let self else { return }
                self.settle(snapshot)
            }
        }
    }

    /// A retomada absorve notificações atrasadas de docking/sleep sem executar rotinas.
    private func beginResumeStabilization() {
        cancelPending()
        resuming = true
        onExecutionContextChanged()
        statusMessage = "Reestabelecendo o ambiente de telas…"
        stabilization = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, let self else { return }
            self.resuming = false
            self.rebaseline()
        }
    }

    private func settle(_ snapshot: DisplayEnvironmentSnapshot) {
        guard canObserve, store.isEnabled else { rebaseline(); return }
        guard monitor.snapshot() == snapshot,
              let previous = baseline, previous != snapshot else { return }
        baseline = snapshot
        let now = Date()
        let intents = store.routines.compactMap { routine -> DisplayRoutineExecutionIntent? in
            guard routine.matches(from: previous, to: snapshot),
                  lastOfferedAt[routine.id].map({ now.timeIntervalSince($0) >= 30 }) ?? true,
                  let workflow = workflowLookup(routine.workflowID), workflow.isValid,
                  (try? DocumentSecurityPolicy.validate(workflow)) != nil else { return nil }
            return DisplayRoutineExecutionIntent(id: UUID(), routine: routine, workflow: workflow,
                topology: snapshot, createdAt: now)
        }
        guard !intents.isEmpty else {
            statusMessage = "Ambiente atualizado; nenhuma rotina aplicável."
            return
        }
        for intent in intents { lastOfferedAt[intent.routineID] = now }
        lastOfferedAt = lastOfferedAt.filter { now.timeIntervalSince($0.value) < 300 }
        issuedIntents = Set(intents.map(\.id))
        if intents.count == 1, let intent = intents.first, intent.routine.mode == .automatic,
           Self.supportsAutomaticExecution(intent.workflow) {
            onAutomaticExecution(intent)
            return
        }
        let reason = intents.count > 1 ? "Mais de uma rotina corresponde a este ambiente. Escolha uma cena."
            : (intents.first?.routine.mode == .automatic
                ? "Esta cena precisa de confirmação porque contém ações dependentes de contexto ou aprovação."
                : "Seu ambiente mudou. Preparar a cena?")
        suggestion = DisplayRoutineSuggestion(intents: intents, reason: reason)
        statusMessage = "Uma cena está disponível para este ambiente."
        expiration = Task { [weak self] in
            try? await Task.sleep(for: .seconds(120))
            guard !Task.isCancelled else { return }
            self?.dismissSuggestion()
            self?.statusMessage = "A sugestão expirou. Aguardando outra mudança de telas."
        }
    }

    private func isCurrent(_ intent: DisplayRoutineExecutionIntent) -> Bool {
        canObserve && executionContextIsCurrent(intent)
            && Date().timeIntervalSince(intent.createdAt) < 120
    }

    private func cancelPending() {
        stabilization?.cancel()
        stabilization = nil
        dismissSuggestion()
        resuming = false
    }
}
