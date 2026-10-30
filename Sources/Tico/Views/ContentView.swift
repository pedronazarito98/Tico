import SwiftUI

struct ContentView: View {
    @ObservedObject var controller: AppController
    @ObservedObject var companion: CompanionCoordinator
    @ObservedObject var shortcutStore: ShortcutStore
    @ObservedObject var eventLogStore: EventLogStore
    @ObservedObject var permissions: PermissionCoordinator
    @ObservedObject var commandRouter: AppCommandRouter

    @Environment(\.dismissSearch) private var dismissSearch
    @Environment(\.openWindow) private var openWindow
    @Environment(\.scenePhase) private var scenePhase
    @SceneStorage("mainSection") private var storedSection = TicoSection.rules.rawValue
    @StateObject private var ruleWorkspace = RuleWorkspaceSession()
    @State private var applicationFilter: String?
    @State private var navigationVisibility = NavigationSplitViewVisibility.all
    @State private var selectedSection = TicoSection.activity
    @State private var selectedRuleID: ShortcutRule.ID?
    @State private var searchText = ""
    @State private var didPerformInitialSetup = false
    @State private var practicePresentation: PracticePresentation?
    @State private var practiceError: String?
    @State private var showsDescription = false
    @State private var describedDraft: ShortcutRule?
    @State private var newSceneRequest: UUID?

    var body: some View {
        GeometryReader { geometry in
            windowContent
                .environment(\.presentationAvailableSize, CGSize(
                    width: max(1, geometry.size.width - 32),
                    height: max(1, geometry.size.height - 24)))
        }
        .frame(minWidth: 680, minHeight: 480)
    }

    // A área oferecida pelo SwiftUI é a fonte dos limites dos modais. Redimensionar
    // a janela atualiza o ambiente sem recriar o owner dos rascunhos.
    private var windowContent: some View {
        NavigationSplitView(columnVisibility: $navigationVisibility) {
            SidebarView(
                selection: sectionBinding,
                selectedRuleID: $selectedRuleID,
                applicationFilter: $applicationFilter,
                scopedApplications: scopedApplications,
                enabledRuleCount: shortcutStore.rules.filter(\.isEnabled).count,
                totalRuleCount: shortcutStore.rules.count,
                captureIsRunning: controller.captureIsRunning,
                onToggleCapture: controller.toggleCapture
            )
        } detail: {
            detail
                .scrollEdgeEffectStyle(.soft, for: .top)
                .modifier(SectionSearchModifier(text: $searchText, prompt: searchPrompt))
        }
        .navigationSplitViewStyle(.balanced)
        // A toolbar pertence à janela. Uma família customizável com ID fixo
        // sincronizava o botão automático da sidebar entre janelas reabertas,
        // duplicando esse item no AppKit. Os controles mantêm seus IDs acessíveis.
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if selectedSection == .scenes {
                    Button("Nova cena", systemImage: "plus") { newSceneRequest = UUID() }
                        .accessibilityIdentifier("tico.scenes.new")
                } else if [.rules, .explore, .library, .activity].contains(selectedSection) {
                    Button("Novo atalho", systemImage: "plus") { createRule() }
                        .accessibilityIdentifier("tico.toolbar.new-rule")
                }
            }
        }
        .onAppear {
            guard !didPerformInitialSetup else { return }
            didPerformInitialSetup = true
            controller.experiences.onPractice = { [weak router = commandRouter, openWindow] id in
                openWindow(id: "main")
                router?.send(.practiceRule(id))
            }
            selectedSection = TicoSection.restored(from: storedSection)
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--open-laboratory") {
                select(.laboratory)
            }
            permissions.refresh()
            if selectedRuleID == nil {
                selectedRuleID = shortcutStore.rules.first?.id
            }
            if arguments.contains("--force-trackpad-fallback") {
                controller.activatePublicFallbackForValidation()
            }
            if controller.settings.startEventCaptureOnLaunch
                || arguments.contains("--start-capture") {
                controller.startCapture()
            }
        }
        // @Published emite em willSet; consuma no próximo ciclo para o roteador
        // já possuir o envelope e garantir consumo único entre várias janelas.
        .onReceive(commandRouter.$pendingCommand.compactMap { $0 }.receive(on: RunLoop.main)) { envelope in
            guard let command = commandRouter.consume(envelope) else { return }
            handle(command)
        }
        .onChange(of: scenePhase) {
            guard scenePhase == .active else { return }
            permissions.refresh()
        }
        .sheet(item: $practicePresentation) { presentation in
            GesturePracticeView(session: controller.practiceSession,
                isRecording: presentation.sessionID != nil
                    && controller.practiceSession.sessionID == presentation.sessionID && controller.recordingIsActive,
                startupError: practiceError ?? controller.trackpadStartupError,
                onFinish: { finishPractice(presentation.id) }, rule: presentation.rule,
                onRetry: { retryPractice(presentation.id) },
                onOpenPermissions: permissions.openInputMonitoringSettings)
                .onDisappear { finishPractice(presentation.id) }
        }
        .sheet(isPresented: $showsDescription, onDismiss: {
            guard let draft = describedDraft else { return }
            describedDraft = nil
            installDraft(draft)
        }) {
            DescribeAutomationView(intelligenceService: controller.localIntelligence, applications: controller.availableApplications,
                latestEvent: controller.recordedEvent, recordingIsActive: controller.recordingIsActive,
                captureMode: controller.trackpadCaptureMode, startupError: controller.trackpadStartupError,
                snapshot: controller.laboratorySnapshot, onStartRecording: controller.beginRecording,
                onStopRecording: controller.endRecording, onCreate: { describedDraft = $0 })
        }
        .sheet(item: $ruleWorkspace.presentedEditor) { session in
            ShortcutComposerView(session: session, practiceSession: controller.practiceSession,
                localInput: controller.localInputCapture,
                applications: controller.availableApplications, macOSShortcuts: controller.availableMacOSShortcuts, reusableWorkflows: shortcutStore.reusableWorkflows,
                presets: shortcutStore.presets, displays: controller.availableDisplays,
                latestEvent: controller.recordedEvent, recordingIsActive: controller.recordingIsActive,
                captureMode: controller.trackpadCaptureMode, startupError: controller.trackpadStartupError,
                snapshot: controller.laboratorySnapshot, detectedTrackpads: controller.detectedTrackpads,
                deviceCapabilities: controller.capabilityStore.devices,
                canCaptureGlobalInput: permissions.status.canCaptureGlobalInput,
                onOpenPermissions: permissions.openInputMonitoringSettings,
                onStartLocalRecording: controller.beginLocalRecording,
                onStartRecording: controller.beginRecording, onStopRecording: controller.endRecording,
                onStartPreview: { controller.beginPractice($0, repetitionLimit: nil) },
                onStopPreview: controller.endPractice,
                onSaveReusableWorkflow: shortcutStore.saveReusableWorkflow, onSavePreset: shortcutStore.savePreset,
                conflictsForRule: shortcutStore.conflicts,
                onSave: { try saveComposedRule($0, replacingConflicts: $1, session: session) },
                onCancel: { ruleWorkspace.presentedEditor = nil })
        }
        .onChange(of: companion.message) {
            if let message = companion.message { controller.presentedError = message }
        }
        .alert(TicoBrand.displayName, isPresented: presentedErrorBinding) {
            Button("OK", role: .cancel) { controller.presentedError = nil }
        } message: {
            Text(controller.presentedError ?? "Erro desconhecido")
        }

    }

    @ViewBuilder
    private var detail: some View {
        switch currentSection {
        case .explore:
            ExploreView(applications: controller.availableApplications, onChoose: installDraft,
                onPractice: practice, onDescribe: { showsDescription = true }, onOpenLibrary: { select(.library) },
                searchText: searchText)
        case .gestureMap:
            GestureMapView(learning: controller.experiences.learning,
                rules: shortcutStore.rules,
                applications: controller.availableApplications, context: companion.context,
                onPractice: practice, onEdit: editRule)
        case .scenes:
            ScenesWorkspaceView(shortcutStore: shortcutStore, companion: companion,
                experiences: controller.experiences, applications: controller.availableApplications,
                macOSShortcuts: controller.availableMacOSShortcuts, onCreateRule: installSceneRule,
                searchText: searchText, newSceneRequest: newSceneRequest)
        case .activity:
            ActivityView(store: controller.metricsStore,
                status: ActivityStatusView(
                    state: .resolve(captureIsRunning: controller.captureIsRunning,
                                    permissionsAreReady: permissions.status.canCaptureGlobalInput,
                                    captureMode: controller.trackpadCaptureMode),
                    enabledRuleCount: shortcutStore.rules.filter(\.isEnabled).count,
                    totalRuleCount: shortcutStore.rules.count,
                    startupError: controller.trackpadStartupError,
                    onToggleCapture: controller.toggleCapture,
                    onOpenPermissions: { select(.permissions) },
                    onOpenLaboratory: { select(.laboratory) },
                    onOpenRules: { select(.rules) }, onCreateRule: createRule),
                session: ActivitySessionView(explanation: companion.explanation, report: companion.lastReport,
                    onEdit: editRule, onExplore: { select(.explore) }),
                ruleIDs: Set(shortcutStore.rules.map(\.id)),
                sceneIDs: Set(shortcutStore.reusableWorkflows.map(\.id)),
                onOpenRule: editRule, onOpenScenes: { select(.scenes) }, searchText: searchText)

        case .permissions:
            PermissionsView(
                permissions: [
                    PermissionPresentation(
                        id: "accessibility",
                        title: "Acessibilidade",
                        explanation: "Permite executar automações e controlar apps quando uma regra pedir isso.",
                        systemImage: "accessibility",
                        isGranted: permissions.status.accessibilityGranted,
                        statusText: permissions.status.accessibilityGranted ? "Concedida" : "Pendente",
                        requestTitle: "Solicitar",
                        request: { permissions.requestAccessibility() },
                        settingsTitle: "Abrir Ajustes",
                        openSettings: permissions.openAccessibilitySettings
                    ),
                    PermissionPresentation(
                        id: "input-monitoring",
                        title: "Monitoramento de Entrada",
                        explanation: "Permite reconhecer atalhos globais de teclado e mouse sem bloquear seu uso normal.",
                        systemImage: "keyboard.badge.ellipsis",
                        isGranted: permissions.status.inputMonitoringGranted,
                        statusText: inputMonitoringStatusText,
                        requestTitle: permissions.status.inputMonitoring == .denied
                            ? "Mostrar app no Finder"
                            : "Solicitar",
                        request: {
                            if permissions.status.inputMonitoring == .denied {
                                permissions.revealApplicationInFinder()
                            } else {
                                permissions.requestInputMonitoring()
                            }
                        },
                        settingsTitle: "Abrir Ajustes",
                        openSettings: permissions.openInputMonitoringSettings
                    )
                ],
                onRefresh: { permissions.refresh() }
            )

        case .rules:
            RulesView(
                store: shortcutStore,
                workspace: ruleWorkspace,
                selectedRuleID: $selectedRuleID,
                searchText: searchText,
                applicationFilter: applicationFilter,
                latestRecordedEvent: controller.recordedEvent,
                recordingIsActive: controller.recordingIsActive,
                trackpadCaptureMode: controller.trackpadCaptureMode,
                trackpadStartupError: controller.trackpadStartupError,
                trackpadSnapshot: controller.laboratorySnapshot,
                applications: controller.availableApplications,
                macOSShortcuts: controller.availableMacOSShortcuts,
                reusableWorkflows: shortcutStore.reusableWorkflows,
                presets: shortcutStore.presets,
                detectedTrackpads: controller.detectedTrackpads,
                deviceCapabilities: controller.capabilityStore.devices,
                currentContext: controller.currentContextSnapshot,
                onStartRecording: controller.beginRecording,
                onStopRecording: controller.endRecording,
                onSaveReusableWorkflow: shortcutStore.saveReusableWorkflow,
                onSavePreset: shortcutStore.savePreset,
                onPractice: practice,
                captureIsRunning: controller.captureIsRunning
            )

        case .library:
            GestureLibraryView(store: shortcutStore, onUsePreset: installPreset, searchText: searchText)

        case .laboratory:
            TrackpadLaboratoryView(
                snapshot: controller.laboratorySnapshot,
                captureMode: controller.trackpadCaptureMode,
                startupError: controller.trackpadStartupError,
                calibrationStore: controller.calibrationStore,
                validationStore: controller.validationStore,
                detectedTrackpads: controller.detectedTrackpads,
                isRecording: controller.laboratoryIsRecording,
                recordedFrameCount: controller.laboratoryRecordedFrameCount,
                lastRecording: controller.laboratoryLastRecording,
                isReplaying: controller.laboratoryIsReplaying,
                replayProgress: controller.laboratoryReplayProgress,
                onStartObservation: { _ = controller.startTrackpadObservation() },
                onStopObservation: controller.stopTrackpadObservationIfIdle,
                onStartRecording: controller.startLaboratoryRecording,
                onStopRecording: controller.stopLaboratoryRecording,
                onCancelRecording: controller.cancelLaboratoryRecording,
                onReplay: controller.replayLaboratoryDocument,
                onCancelReplay: controller.cancelLaboratoryReplay,
                onActivateFallback: controller.activatePublicFallbackForValidation,
                onRestoreAdvanced: controller.restoreAdvancedTrackpadCapture,
                onRefreshHardware: controller.refreshTrackpadHardware
            )

        case .log:
            EventLogView(
                entries: eventLogStore.entries.map {
                    EventLogPresentation(
                        id: $0.id,
                        date: $0.result.executedAt,
                        title: $0.ruleName,
                        detail: $0.result.message,
                        isError: !$0.result.success,
                        steps: $0.stepExecutions
                    )
                },
                onClear: controller.clearLog
            )
        }
    }

    private var currentSection: TicoSection {
        selectedSection
    }

    private var scopedApplications: [ApplicationChoice] {
        let ids = Set(shortcutStore.rules.flatMap { $0.scope.bundleIdentifiers })
        return ids.map { id in
            controller.availableApplications.first { $0.bundleIdentifier == id }
                ?? ApplicationChoice(bundleIdentifier: id, name: id, isRunning: false)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func handle(_ command: AppCommand) {
        switch command {
        case .showContextualActions:
            companion.showActions()
        case .showContentActions:
            controller.contentInteraction.show()
        case .useSelectedContent:
            controller.contentInteraction.show(useSelection: true)
        case .createContentRule:
            controller.contentInteraction.showRecipeEditor()
        case let .practiceRule(id):
            guard let rule = shortcutStore.rules.first(where: { $0.id == id }) else { return }
            select(.gestureMap)
            practice(rule)
        case .showGestureMap:
            select(.gestureMap)
        case .describeAutomation:
            showsDescription = true
        case .openMainWindow:
            openWindow(id: "main")
        case .createRule:
            select(.rules)
            createRule()
        case .deleteSelectedRule:
            deleteSelectedRule()
        case .startCapture:
            controller.startCapture()
        case .stopCapture:
            controller.stopCapture()
        case let .selectSection(section):
            select(section)
        case .importRules:
            importRules()
        case .exportRules:
            exportRules()
        }
    }

    private var inputMonitoringStatusText: String {
        switch permissions.status.inputMonitoring {
        case .granted: "Concedida"
        case .denied: "Negada"
        case .notDetermined: "Não solicitada"
        }
    }

    private var sectionBinding: Binding<TicoSection?> {
        Binding(
            get: { selectedSection },
            set: applySelection
        )
    }

    private var presentedErrorBinding: Binding<Bool> {
        Binding(
            get: { controller.presentedError != nil },
            set: { isPresented in
                guard !isPresented, controller.presentedError != nil else { return }
                controller.presentedError = nil
            }
        )
    }

    private func select(_ section: TicoSection) {
        applySelection(section)
    }

    private func applySelection(_ section: TicoSection?) {
        guard let selection = ShellNavigationSelection.resolve(
            requestedSection: section,
            currentSection: selectedSection
        ) else { return }

        if selection.changesDestination {
            selectedSection = selection.selectedSection
            storedSection = selection.selectedSection.rawValue
        }
        searchText = selection.searchText
        if selection.dismissesSearch {
            dismissSearch()
        }
    }

    private func practice(_ rule: ShortcutRule) {
        guard practicePresentation == nil else { return }
        let sessionID = controller.beginPractice(rule)
        practiceError = sessionID == nil ? controller.presentedError : nil
        if practiceError != nil { controller.presentedError = nil }
        practicePresentation = PracticePresentation(id: UUID(), rule: rule, sessionID: sessionID)
    }

    /// A apresentação tem identidade estável; cada tentativa possui seu token.
    /// Um fechamento tardio nunca encerra a captura de outra janela.
    private func retryPractice(_ id: UUID) {
        guard var presentation = practicePresentation, presentation.id == id else { return }
        if let token = presentation.sessionID { controller.endPractice(sessionID: token) }
        presentation.sessionID = controller.beginPractice(presentation.rule)
        practiceError = presentation.sessionID == nil ? controller.presentedError : nil
        if practiceError != nil { controller.presentedError = nil }
        practicePresentation = presentation
    }

    private func finishPractice(_ id: UUID) {
        guard let presentation = practicePresentation, presentation.id == id else { return }
        if let token = presentation.sessionID { controller.endPractice(sessionID: token) }
        practicePresentation = nil
        practiceError = nil
    }

    private func editRule(_ id: UUID) {
        guard let rule = shortcutStore.rules.first(where: { $0.id == id }) else { return }
        applicationFilter = nil
        selectedRuleID = id
        select(.rules)
        ruleWorkspace.edit(rule)
    }

    /// Receitas e modelos abrem o mesmo rascunho. Só o botão final do criador
    /// persiste: personalizar e cancelar não deixam regras incompletas na coleção.
    private func installDraft(_ draft: ShortcutRule) {
        applicationFilter = nil
        let session = RuleEditingSession(rule: draft, isNew: true)
        session.chooseWorkflow(draft.workflow, title: draft.name)
        session.chooseTrigger(draft.trigger)
        ruleWorkspace.presentedEditor = session
    }

    private func installPreset(_ preset: GesturePreset) {
        installDraft(ShortcutRule(name: preset.name, isEnabled: true,
            trigger: preset.trigger,
            action: preset.workflow.steps.first?.action ?? .notification(title: "Tico", body: "Cena"),
            workflow: preset.workflow, scope: preset.scope, conditions: preset.conditions,
            priority: preset.priority, notes: preset.summary))
    }

    private func installSceneRule(_ workflow: ActionWorkflow) {
        let draft = ShortcutRule(name: workflow.name, isEnabled: true,
            trigger: .keyboard(keyCode: 49, modifiers: [.command, .option, .shift]),
            action: workflow.steps.first?.action ?? .notification(title: "Tico", body: "Cena"),
            workflow: workflow)
        let session = RuleEditingSession(rule: draft, isNew: true)
        session.chooseWorkflow(draft.workflow, title: draft.name)
        // O gatilho inicial só satisfaz o modelo; não conta como escolha feita.
        ruleWorkspace.presentedEditor = session
    }

    private func createRule() {
        applicationFilter = nil
        ruleWorkspace.create()
    }

    private var searchPrompt: String? {
        switch selectedSection {
        case .rules: "Buscar atalhos"
        case .scenes: "Buscar cenas"
        case .explore: "Buscar ideias"
        case .library: "Buscar modelos e gestos"
        case .activity: "Buscar execuções"
        default: nil
        }
    }

    /// Persiste uma única vez; fechar o criador antes de salvar não cria uma regra.
    /// O store conserva sua escrita atômica tanto na criação quanto na substituição.
    private func saveComposedRule(_ rule: ShortcutRule, replacingConflicts: Bool, session: RuleEditingSession) throws {
        if session.isNew {
            if replacingConflicts { try shortcutStore.addReplacingConflictingRules(rule) }
            else { try shortcutStore.add(rule) }
            ruleWorkspace.recentlyCreatedID = rule.id
        } else {
            if replacingConflicts { try shortcutStore.replaceConflictingRules(with: rule) }
            else { try shortcutStore.update(rule) }
        }
        session.markSaved(rule)
        ruleWorkspace.presentedEditor = nil
        applicationFilter = nil
        searchText = ""
        selectedRuleID = rule.id
        select(.rules)
    }

    private func deleteSelectedRule() {
        guard currentSection == .rules, let selectedRuleID else { return }
        do {
            try deleteRule(selectedRuleID)
        } catch {
            controller.presentedError = error.localizedDescription
        }
    }

    private func deleteRule(_ id: ShortcutRule.ID) throws {
        try shortcutStore.delete(id: id)
        if selectedRuleID == id {
            selectedRuleID = shortcutStore.rules.first?.id
        }
    }

    private func importRules() {
        guard let url = RuleFilePanel.chooseImportURL() else { return }
        do {
            try shortcutStore.importRules(from: url, strategy: .merge)
            selectedRuleID = shortcutStore.rules.first?.id
            select(.rules)
        } catch {
            controller.presentedError = error.localizedDescription
        }
    }

    private func exportRules() {
        guard let url = RuleFilePanel.chooseExportURL() else { return }
        do {
            try shortcutStore.exportRules(to: url)
        } catch {
            controller.presentedError = error.localizedDescription
        }
    }
}

private struct PracticePresentation: Identifiable {
    let id: UUID
    let rule: ShortcutRule
    var sessionID: UUID?
}

/// Busca pertence à seção visível. Digitar nunca muda o destino de navegação.
private struct SectionSearchModifier: ViewModifier {
    @Binding var text: String
    let prompt: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let prompt {
            content.searchable(text: $text, placement: .toolbar, prompt: Text(prompt))
                .searchToolbarBehavior(.automatic)
        } else { content }
    }
}
