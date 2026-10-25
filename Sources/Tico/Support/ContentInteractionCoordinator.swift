import Combine
import Foundation

/// O AppController possui esta sessão. Conteúdo, contexto e tarefa são transitórios;
/// nenhum caminho de apresentação cria outro executor ou persiste a entrada.
@MainActor
final class ContentInteractionCoordinator: ObservableObject {
    @Published private(set) var choices: [ContentActionChoice] = []
    /// Apenas diagnósticos locais fixos; nunca recebe mensagens de relatórios,
    /// saídas de scripts ou conteúdo capturado.
    @Published private(set) var executionIssue: String?
    @Published private(set) var recipeDraft: ContentRecipe?
    @Published private(set) var recipeError: String?
    @Published private(set) var availableMacOSShortcuts: [String] = []
    var interactionIsSuspended = false {
        didSet { if interactionIsSuspended { close() } }
    }

    private let store: ShortcutStore
    private let automation: AutomationCoordinator
    private let contextProvider: any ContextSnapshotProviding
    private let allowsExecution: Bool
    private let recipes: ContentRecipeStore
    private let contentService = ContentActionService()
    private let selection = SelectionCaptureService()
    private let presenter = ExperiencePanelPresenter()
    private var requestedRule: ShortcutRule?
    private enum RequestOwner { case rule(UUID, Date), scene(UUID, ActionWorkflow), transient }
    private var requestOwner: RequestOwner = .transient
    private var initialSelection: Result<AutomationContent, ContentActionError>?
    private var originalContext: ContextSnapshot?
    private var originalSelectionTarget: SelectionCaptureTarget?
    private var activeRuleID: UUID?
    private var captureTask: Task<Void, Never>?
    private var generation = UUID()
    private var subscriptions = Set<AnyCancellable>()

    lazy var session = ContentPanelSession(execute: { [weak self] choice, content in
        guard let self else { return .failed("O painel foi encerrado.") }
        return await execute(choice: choice, content: content)
    }, onCancel: { [weak self] in
        guard let self, let activeRuleID else { return }
        automation.cancelWorkflow(ruleID: activeRuleID)
    })

    init(store: ShortcutStore, automation: AutomationCoordinator,
         contextProvider: any ContextSnapshotProviding, allowsExecution: Bool) {
        self.store = store
        self.automation = automation
        self.contextProvider = contextProvider
        self.allowsExecution = allowsExecution
        recipes = ContentRecipeStore(repository: FileContentRecipeRepository(
            dataURL: store.fileURL.deletingLastPathComponent().appendingPathComponent("content-recipes.json")))
        store.$rules.receive(on: RunLoop.main).sink { [weak self] _ in
            self?.refreshChoices()
        }.store(in: &subscriptions)
        recipes.$recipes.receive(on: RunLoop.main).sink { [weak self] _ in
            self?.refreshChoices()
        }.store(in: &subscriptions)
        recipes.$errorMessage.receive(on: RunLoop.main).sink { [weak self] message in
            self?.recipeError = message
        }.store(in: &subscriptions)
        automation.onContentRequested = { [weak self] rule in self?.show(requestedRule: rule) }
    }

    func show(useSelection: Bool = false, requestedRule: ShortcutRule? = nil) {
        guard !interactionIsSuspended else { return }
        close()
        self.requestedRule = requestedRule
        if let requestedRule, store.rules.contains(where: { $0.id == requestedRule.id }) {
            requestOwner = .rule(requestedRule.id, requestedRule.updatedAt)
        } else if let requestedRule, store.reusableWorkflows.contains(where: { $0.id == requestedRule.workflow.id }) {
            requestOwner = .scene(requestedRule.workflow.id, requestedRule.workflow)
        } else { requestOwner = .transient }
        originalContext = allowsExecution ? contextProvider.snapshot(modifiers: [], at: Date()) : ContextSnapshot()
        originalSelectionTarget = allowsExecution ? selection.frontmostTarget(
            expectedBundleIdentifier: originalContext?.frontmostApplicationBundleIdentifier
        ) : nil
        let token = UUID()
        generation = token
        captureTask = Task { [weak self] in
            guard let self else { return }
            var captured: AutomationContent?
            var captureError: Error?
            let needsSnapshot = requestedRule?.workflow.enabledSteps.contains {
                if case let .content(configuration) = $0.action {
                    return configuration.source == .selection && configuration.selectionTiming == .workflowStart
                }
                return false
            } == true
            // Abrir/configurar o painel não autoriza ler seleção. A captura aqui
            // pertence exclusivamente ao comando explícito "Usar seleção".
            if useSelection {
                if allowsExecution, let target = originalSelectionTarget {
                    do { captured = try await selection.capture(expectedTarget: target) }
                    catch { captureError = error }
                } else { captureError = ContentActionError.selectionUnavailable }
            }
            guard !Task.isCancelled, generation == token, !interactionIsSuspended else { return }
            if useSelection && needsSnapshot {
                initialSelection = captured.map { .success($0) }
                    ?? .failure(captureError as? ContentActionError ?? .selectionUnavailable)
            }
            refreshChoices()
            if useSelection, let captured { session.setContent(captured) }
            if let captureError { session.reportCaptureError(captureError) }
            presenter.show(ContentInteractionPanelView(coordinator: self), purpose: .content,
                onClose: { [weak self] in self?.clearSession() })
            captureTask = nil
        }
    }

    func close() {
        generation = UUID()
        captureTask?.cancel()
        captureTask = nil
        presenter.close()
        clearSession()
    }

    func createAction() {
        createRecipe(intent: .google)
    }

    /// Entrada do menu para criar uma receita sem passar pelo composer de gestos.
    func showRecipeEditor() {
        guard !interactionIsSuspended, !session.isRunning else { return }
        if originalContext == nil || !canManageRecipes { show() }
        createAction()
    }

    var canManageRecipes: Bool { requestedRule == nil }

    func updateMacOSShortcuts(_ names: [String]) {
        availableMacOSShortcuts = Array(Set(names)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    func createRecipe(intent: ContentRecipeIntent) {
        guard !session.isRunning, canManageRecipes else { return }
        recipeDraft = ContentRecipe(configuration: .init(source: .provided, destination: intent.destination))
    }

    func editRecipe(_ id: UUID) {
        guard !session.isRunning, canManageRecipes else { return }
        recipeDraft = recipes.recipes.first { $0.id == id }
    }

    func cancelRecipeEditing() { recipeDraft = nil }

    func saveRecipe(_ recipe: ContentRecipe) throws {
        guard !session.isRunning, recipeDraft?.id == recipe.id, canManageRecipes else {
            throw ContentRecipeError.unavailable
        }
        try recipes.save(recipe)
        recipeDraft = nil
        refreshChoices()
    }

    func removeRecipe(_ id: UUID) {
        guard !session.isRunning, canManageRecipes else { return }
        do { try recipes.remove(id); refreshChoices() }
        catch { recipeError = (error as? ContentRecipeError)?.localizedDescription ?? ContentRecipeError.persistence.localizedDescription }
    }

    private func clearSession() {
        // Também é chamado pelo fechamento nativo do painel. A invalidação deve
        // ocorrer aqui para impedir execução/restauração depois de Escape/fechar.
        generation = UUID()
        captureTask?.cancel()
        captureTask = nil
        session.clear()
        executionIssue = nil
        recipeDraft = nil
        requestedRule = nil
        requestOwner = .transient
        initialSelection = nil
        originalContext = nil
        originalSelectionTarget = nil
    }

    private func availableRules() -> [ShortcutRule] {
        if let requestedRule { return [requestedRule] }
        guard let originalContext else { return [] }
        return store.rules.filter { $0.matches(originalContext) }
    }

    private func refreshChoices() {
        let manualChoices = canManageRecipes
            ? ContentRecipe.builtIns.map { ContentActionChoice(recipe: $0) }
                + recipes.recipes.map { ContentActionChoice(recipe: $0, isEditable: true) }
            : []
        choices = manualChoices + availableRules().compactMap { rule in
            let configurations = rule.workflow.enabledSteps.compactMap { step -> ContentActionConfiguration? in
                if case let .content(configuration) = step.action { return configuration }
                return nil
            }
            let supplied = configurations.filter { $0.source == .provided }
            guard !supplied.isEmpty else { return nil }
            let acceptsFiles = supplied.allSatisfy {
                if case .macOSShortcut = $0.destination { return true }
                return false
            }
            return ContentActionChoice(id: rule.id, title: rule.name, detail: rule.trigger.displayName,
                acceptedKinds: acceptsFiles ? [.text, .webURL, .files] : [.text, .webURL])
        }
    }

    private func execute(choice: ContentActionChoice, content: AutomationContent) async -> ActionExecutionResult {
        // Uma tarefa cancelada antes de iniciar não pode alterar o diagnóstico
        // de uma apresentação que já tenha sido reaberta.
        guard !Task.isCancelled else { return .failed("A execução foi cancelada.") }
        executionIssue = nil
        let token = generation
        guard allowsExecution, !interactionIsSuspended else {
            return reject("Execução indisponível durante esta atividade.", generation: token)
        }
        if let recipe = choice.recipe {
            return await executeRecipe(recipe, content: content, generation: token)
        }
        guard var rule = availableRules().first(where: { $0.id == choice.id }) else {
            return reject("A ação mudou. Abra o painel novamente.", generation: token)
        }
        switch requestOwner {
        case let .rule(id, revision):
            guard let saved = store.rules.first(where: { $0.id == id }), saved.updatedAt == revision,
                  saved.isEnabled else { return reject("O atalho foi removido, alterado ou pausado. Abra o painel novamente.", generation: token) }
        case let .scene(id, expected):
            guard store.reusableWorkflows.first(where: { $0.id == id }) == expected else {
                return reject("A cena foi removida ou alterada. Abra o painel novamente.", generation: token)
            }
        case .transient: break
        }
        if let saved = store.rules.first(where: { $0.id == rule.id }) {
            guard saved.updatedAt == rule.updatedAt, saved.isEnabled else {
                return reject("O atalho foi alterado ou pausado. Abra o painel novamente.", generation: token)
            }
            rule = saved
        }
        let expectedRule = rule
        let needsSnapshot = rule.workflow.enabledSteps.contains {
            if case let .content(configuration) = $0.action {
                return configuration.source == .selection && configuration.selectionTiming == .workflowStart
            }
            return false
        }
        var preparedSelection = initialSelection
        if needsSnapshot, preparedSelection == nil {
            // No painel genérico, só a escolha explícita de uma regra mista
            // autoriza a captura. Não observamos seleção ao listar as ações.
            do { preparedSelection = .success(try await captureOriginalSelection(generation: token)) }
            catch let error as ContentActionError { preparedSelection = .failure(error) }
            catch { preparedSelection = .failure(Task.isCancelled ? .cancelled : .selectionUnavailable) }
        }
        guard !Task.isCancelled, generation == token, !interactionIsSuspended else {
            return reject("A execução foi cancelada.", generation: token)
        }
        guard requestIsCurrent(), let currentRule = availableRules().first(where: { $0.id == expectedRule.id }),
              currentRule.updatedAt == expectedRule.updatedAt, currentRule.workflow == expectedRule.workflow,
              store.rules.first(where: { $0.id == expectedRule.id }).map({ $0.isEnabled && $0.updatedAt == expectedRule.updatedAt }) ?? true else {
            return reject("A ação mudou durante a captura. Abra o painel novamente.", generation: token)
        }
        // O painel aceita apenas destinos explícitos. Operações de teclado
        // poderiam atingir o campo de conteúdo; nunca as redirecionamos por heurística.
        for index in rule.workflow.steps.indices where rule.workflow.steps[index].isEnabled {
            switch rule.workflow.steps[index].action {
            case .keyboardShortcut:
                return reject("Use uma sequência sem envio de teclas no painel de conteúdo.", generation: token)
            case let .window(.frontmost, operation):
                guard let target = originalContext?.frontmostApplicationBundleIdentifier,
                      target != Bundle.main.bundleIdentifier else { return reject("Escolha um aplicativo de destino na ação de janela.", generation: token) }
                rule.workflow.steps[index].action = .window(target: .bundleIdentifier(target), operation: operation)
            case let .application(.frontmost, operation):
                guard let target = originalContext?.frontmostApplicationBundleIdentifier,
                      target != Bundle.main.bundleIdentifier else { return reject("Escolha um aplicativo de destino nesta ação.", generation: token) }
                rule.workflow.steps[index].action = .application(target: .bundleIdentifier(target), operation: operation)
            default: break
            }
        }
        activeRuleID = rule.id
        let prepared = ContentExecutionContext(providedContent: content, initialSelection: preparedSelection)
        guard let task = automation.runManually(rule, origin: .contentPanel,
                                                providedContent: content, preparedContent: prepared) else {
            activeRuleID = nil
            return reject("A sequência não está disponível para execução.", generation: token)
        }
        let report = await task.value
        if activeRuleID == rule.id { activeRuleID = nil }
        return report.summary
    }

    /// Receitas têm uma única ação e nenhum gatilho oculto. Reutilizam a mesma
    /// fronteira de conteúdo, com cancelamento estruturado e diagnósticos fixos.
    /// Regras com várias etapas continuam no executor central acima.
    private func executeRecipe(_ recipe: ContentRecipe, content: AutomationContent, generation token: UUID) async -> ActionExecutionResult {
        guard canManageRecipes, recipe.configuration.source == .provided,
              (ContentRecipe.builtIns + recipes.recipes).contains(recipe) else {
            return reject("A receita mudou. Escolha a ação novamente.", generation: token)
        }
        do {
            try Task.checkCancellation()
            guard generation == token, !interactionIsSuspended else { throw ContentActionError.cancelled }
            let message = try await contentService.execute(recipe.configuration,
                context: ContentExecutionContext(providedContent: content), timeout: 60)
            try Task.checkCancellation()
            guard generation == token else { throw ContentActionError.cancelled }
            return .succeeded(message)
        } catch {
            let issue = error as? ContentActionError ?? (Task.isCancelled ? .cancelled : .shortcutFailed)
            // ContentActionError não transporta strings externas ou payloads.
            if generation == token { executionIssue = issue.localizedDescription }
            return .failed(issue.localizedDescription)
        }
    }

    /// StaticString restringe o diagnóstico a mensagens conhecidas no código.
    /// A geração impede uma rejeição tardia de aparecer em um painel reaberto.
    private func reject(_ issue: StaticString, generation token: UUID) -> ActionExecutionResult {
        let message = String(describing: issue)
        if generation == token { executionIssue = message }
        return .failed(message)
    }

    /// Oculta, mas mantém a mesma sessão e geração. A captura exige o PID/bundle
    /// original ainda frontmost; nunca ativa apps para tentar reencontrar seleção.
    private func captureOriginalSelection(generation token: UUID) async throws -> AutomationContent {
        try Task.checkCancellation()
        guard generation == token, !interactionIsSuspended else { throw ContentActionError.cancelled }
        guard let target = originalSelectionTarget, selection.frontmostTarget() == target else {
            throw ContentActionError.focusChanged
        }
        guard let presentation = presenter.hideForSelectionCapture() else { throw ContentActionError.cancelled }
        defer {
            if generation == token, !interactionIsSuspended {
                presenter.restoreAfterSelectionCapture(presentation)
            }
        }
        // Devolve um turno ao AppKit após orderOut. Tempo não autoriza a captura:
        // o serviço revalida Workspace e app focado AX antes de ler o conteúdo.
        await Task.yield()
        try Task.checkCancellation()
        guard generation == token, !interactionIsSuspended else { throw ContentActionError.cancelled }
        return try await selection.capture(expectedTarget: target)
    }

    private func requestIsCurrent() -> Bool {
        switch requestOwner {
        case let .rule(id, revision):
            return store.rules.contains { $0.id == id && $0.updatedAt == revision && $0.isEnabled }
        case let .scene(id, expected):
            return store.reusableWorkflows.first(where: { $0.id == id }) == expected
        case .transient:
            return true
        }
    }
}
