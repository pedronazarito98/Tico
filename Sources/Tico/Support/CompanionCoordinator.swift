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
    private let panel = ContextualPanelService()
    private let allowsExecution: Bool
    private var panelRules: [ShortcutRule] = []
    private var panelContext: ContextSnapshot?
    private var cancellables = Set<AnyCancellable>()
    @Published private(set) var context: ContextSnapshot?
    @Published private(set) var message: String?

    var explanation: AutomationExplanation? { automation.explanation }
    var lastReport: WorkflowExecutionReport? { automation.lastWorkflowReport }
    var runningIDs: Set<UUID> { automation.runningRuleIDs }
    var interactionIsSuspended = false {
        didSet { if interactionIsSuspended { panel.close() } }
    }

    init(store: ShortcutStore, automation: AutomationCoordinator,
         contextProvider: any ContextSnapshotProviding, allowsExecution: Bool) {
        self.store = store
        self.automation = automation
        self.contextProvider = contextProvider
        self.allowsExecution = allowsExecution
        automation.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
        panel.onRequestActions = { [weak self] in self?.showActions() }
        panel.onRequestMap = { [weak self] in self?.showMap() }
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didActivateApplicationNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let snapshot = contextProvider.snapshot(modifiers: [], at: Date())
                    if snapshot.frontmostApplicationBundleIdentifier != panelContext?.frontmostApplicationBundleIdentifier {
                        panel.close()
                    }
                    if snapshot.frontmostApplicationBundleIdentifier != Bundle.main.bundleIdentifier {
                        context = snapshot
                    }
                }
            }.store(in: &cancellables)
    }

    func handle(_ event: InputEventDescriptor) -> Bool {
        guard !interactionIsSuspended else { return true }
        return panel.handle(event)
    }

    func closePanel() { panel.close() }

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
        automation.runManually(rule)
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
        let snapshot = contextProvider.snapshot(modifiers: [], at: Date())
        context = snapshot
        panelContext = snapshot
        let configured = store.rules.filter { rule in
            rule.matches(snapshot, profiles: store.profiles) && (isMap || rule.workflow.enabledSteps.allSatisfy {
                if case .continuousWindow = $0.action { return false }
                return true
            })
        }.sorted { $0.effectiveSpecificity(profiles: store.profiles) > $1.effectiveSpecificity(profiles: store.profiles) }
        var candidates = configured
        if !isMap {
            for recipe in AutomationRecipeCatalog.recipes where candidates.count < 4 {
                var rule = recipe.makeRule()
                rule.isEnabled = true
                if rule.matches(snapshot, profiles: store.profiles),
                   !candidates.contains(where: { $0.action == rule.action }) {
                    candidates.append(rule)
                }
            }
        }
        panelRules = isMap ? candidates : Array(candidates.prefix(4))
        panel.show(appName: snapshot.frontmostApplicationName ?? "Aplicativo atual",
            items: panelRules.map { ContextualActionItem(id: $0.id, name: $0.name, trigger: $0.trigger.displayName) },
            isMap: isMap, onSelect: { [weak self] id in self?.select(id) })
    }

    private func select(_ id: UUID) {
        panel.close()
        guard canExecute, var rule = panelRules.first(where: { $0.id == id }),
              let originalContext = panelContext,
              let appID = originalContext.frontmostApplicationBundleIdentifier else { return }
        let current = contextProvider.snapshot(modifiers: [], at: Date())
        guard current.frontmostApplicationBundleIdentifier == appID else {
            message = "O aplicativo mudou. Abra o painel novamente para escolher uma ação."
            return
        }
        if let saved = store.rules.first(where: { $0.id == id }) {
            guard saved.matches(current, profiles: store.profiles) else { return }
            rule = saved
        }
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
        automation.runManually(rule)
    }
}
