import AppKit
import Combine
import Foundation

/// Coordena as entradas da V2 sobre os mesmos workflows. Nenhum executor paralelo.
/// Paralelo com React: um owner de interação que projeta estado e expõe callbacks às views.
@MainActor
final class CompanionCoordinator: ObservableObject {
    private let store: ShortcutStore
    private let automation: AutomationCoordinator
    private let contextProvider: any ContextSnapshotProviding
    private let panel: any ContextualPanelPresenting
    private let allowsExecution: Bool
    private var panelRules: [ShortcutRule] = []
    private var panelContext: ContextSnapshot?
    // A identidade é revogada ao fechar/trocar o painel. AX tardio não pode
    // reapresentar uma UI encerrada nem executar a escolha de outro contexto.
    private var contextRequestToken = UUID()
    private var contextTask: Task<Void, Never>?
    private var pendingMap = false
    private var cancellables = Set<AnyCancellable>()
    @Published private(set) var context: ContextSnapshot?
    @Published private(set) var message: String?
    var onRequestContent: (() -> Void)?
    var onRequestSelection: (() -> Void)?

    var explanation: AutomationExplanation? { automation.explanation }
    var lastReport: WorkflowExecutionReport? { automation.lastWorkflowReport }
    var runningIDs: Set<UUID> { automation.runningRuleIDs }
    var interactionIsSuspended = false {
        didSet { if interactionIsSuspended { closePanel() } }
    }

    init(store: ShortcutStore, automation: AutomationCoordinator,
         contextProvider: any ContextSnapshotProviding, allowsExecution: Bool,
         panel: (any ContextualPanelPresenting)? = nil) {
        self.store = store
        self.automation = automation
        self.contextProvider = contextProvider
        self.allowsExecution = allowsExecution
        self.panel = panel ?? ContextualPanelService()
        automation.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
        self.panel.onRequestActions = { [weak self] in self?.showActions() }
        self.panel.onRequestMap = { [weak self] in self?.showMap() }
        self.panel.onClose = { [weak self] in self?.invalidateContextRequest() }
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let snapshot = contextProvider.snapshot(modifiers: [], at: Date())
                    if snapshot.frontmostApplicationBundleIdentifier != panelContext?.frontmostApplicationBundleIdentifier {
                        closePanel()
                    }
                    if snapshot.frontmostApplicationBundleIdentifier != Bundle.main.bundleIdentifier {
                        context = snapshot
                    }
                }
            }.store(in: &cancellables)
    }

    func handle(_ event: InputEventDescriptor) -> Bool {
        guard !interactionIsSuspended else { return true }
        if contextTask != nil, event.kind == .keyboard,
           event.keyCode == 53 || (pendingMap && event.modifiers != [.command, .option]) {
            closePanel()
            return true
        }
        return panel.handle(event)
    }

    func closePanel() { invalidateContextRequest(); panel.close() }

    private func invalidateContextRequest() {
        contextRequestToken = UUID()
        contextTask?.cancel()
        contextTask = nil
        pendingMap = false
    }

    func showActions() { show(isMap: false) }
    func showMap() { show(isMap: true) }

    func runScene(_ workflow: ActionWorkflow) {
        guard canExecute else { return }
        guard workflow.enabledSteps.allSatisfy({ step in
            if case .continuousWindow = step.action { return false }
            return true
        }) else {
            message = "Ações contínuas precisam de um gesto. Use esta cena em um atalho."
            return
        }
        let rule = ShortcutRule(id: workflow.id, name: workflow.name, isEnabled: false,
            trigger: .keyboard(keyCode: 49, modifiers: []),
            action: workflow.steps.first?.action ?? .notification(title: "Tico", body: "Cena vazia"), workflow: workflow)
        message = nil
        automation.runManually(rule, origin: .scene)
    }

    func cancel(_ id: UUID) { automation.cancelWorkflow(ruleID: id) }

    private var canExecute: Bool {
        guard allowsExecution, !interactionIsSuspended else {
            message = "Execução indisponível durante prática, gravação, replay ou validação isolada."
            return false
        }
        return true
    }

    private func show(isMap: Bool) {
        guard !interactionIsSuspended else { return }
        closePanel()
        let request = contextProvider.makeRequest(modifiers: [], at: Date(), includeWindowContext: true)
        let token = contextRequestToken
        pendingMap = isMap
        contextTask = Task { [weak self] in
            guard let self else { return }
            defer { if contextRequestToken == token { contextTask = nil; pendingMap = false } }
            guard let snapshot = await contextProvider.resolve(request),
                  !Task.isCancelled, contextRequestToken == token, !interactionIsSuspended,
                  contextProvider.isCurrent(request) else { return }
            contextTask = nil
            pendingMap = false
            present(snapshot: snapshot, isMap: isMap)
        }
    }

    private func present(snapshot: ContextSnapshot, isMap: Bool) {
        context = snapshot
        panelContext = snapshot
        let configured = store.rules.filter { rule in
            rule.matches(snapshot) && (isMap || rule.workflow.enabledSteps.allSatisfy {
                if case .continuousWindow = $0.action { return false }
                return true
            })
        }.sorted { $0.effectiveSpecificity > $1.effectiveSpecificity }
        var candidates = configured
        if !isMap {
            for recipe in AutomationRecipeCatalog.recipes where candidates.count < 4 {
                var rule = recipe.makeRule()
                rule.isEnabled = true
                if rule.matches(snapshot),
                   !candidates.contains(where: { $0.action == rule.action }) {
                    candidates.append(rule)
                }
            }
        }
        panelRules = isMap ? candidates : Array(candidates.prefix(4))
        let token = contextRequestToken
        panel.show(appName: snapshot.frontmostApplicationName ?? "Aplicativo atual",
            items: panelRules.map { ContextualActionItem(id: $0.id, name: $0.name, trigger: $0.trigger.displayName) },
            isMap: isMap, onSelect: { [weak self] id in
                guard let self, contextRequestToken == token else { return }
                select(id)
            }, onContent: { [weak self] in
                guard let self, contextRequestToken == token else { return }
                closePanel(); onRequestContent?()
            }, onSelection: { [weak self] in
                guard let self, contextRequestToken == token else { return }
                closePanel(); onRequestSelection?()
            })
    }

    private func select(_ id: UUID) {
        closePanel()
        guard canExecute, let selected = panelRules.first(where: { $0.id == id }),
              let appID = panelContext?.frontmostApplicationBundleIdentifier else { return }
        let request = contextProvider.makeRequest(modifiers: [], at: Date(), includeWindowContext: true)
        let token = contextRequestToken
        let wasSaved = store.rules.contains { $0.id == id }
        contextTask = Task { [weak self] in
            guard let self else { return }
            defer { if contextRequestToken == token { contextTask = nil } }
            guard let current = await contextProvider.resolve(request),
                  !Task.isCancelled, contextRequestToken == token, canExecute,
                  contextProvider.isCurrent(request) else { return }
            contextTask = nil
            guard current.frontmostApplicationBundleIdentifier == appID else {
                message = "O aplicativo mudou. Abra o painel novamente para escolher uma ação."
                return
            }
            var rule = selected
            if let saved = store.rules.first(where: { $0.id == id }) {
                guard saved.updatedAt == selected.updatedAt, saved.matches(current) else { return }
                rule = saved
            } else if wasSaved { return }
            execute(rule: rule, appID: appID)
        }
    }

    private func execute(rule selected: ShortcutRule, appID: String) {
        var rule = selected
        // Fixe alvos relativos antes de fechar o painel; o foco não deve mudar o destino.
        for index in rule.workflow.steps.indices {
            switch rule.workflow.steps[index].action {
            case let .window(.frontmost, operation):
                rule.workflow.steps[index].action = .window(target: .bundleIdentifier(appID), operation: operation)
            case let .application(.frontmost, operation):
                rule.workflow.steps[index].action = .application(target: .bundleIdentifier(appID), operation: operation)
            default: break
            }
        }
        message = nil
        automation.runManually(rule, origin: .contextualPanel)
    }
}
