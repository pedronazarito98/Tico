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
    @State private var selectedSection = TicoSection.overview
    @State private var selectedRuleID: ShortcutRule.ID?
    @State private var searchText = ""
    @State private var didPerformInitialSetup = false
    @State private var practicePresentation: PracticePresentation?
    @State private var showsDescription = false

    var body: some View {
        NavigationSplitView(columnVisibility: $navigationVisibility) {
            SidebarView(
                selection: sectionBinding,
                selectedRuleID: $selectedRuleID,
                applicationFilter: $applicationFilter,
                scopedApplications: scopedApplications,
                enabledRuleCount: shortcutStore.rules.filter(\.isEnabled).count,
                totalRuleCount: shortcutStore.rules.count,
                captureIsRunning: controller.captureIsRunning
            )
        } detail: {
            detail
                .scrollEdgeEffectStyle(.soft, for: .top)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 1_040, minHeight: 620)
        .searchable(
            text: $searchText,
            placement: .toolbar,
            prompt: "Buscar atalhos"
        )
        .searchToolbarBehavior(.automatic)
        .onChange(of: searchText) {
            guard !searchText.isEmpty, selectedSection != .rules else { return }
            selectedSection = .rules
            storedSection = TicoSection.rules.rawValue
        }
        .toolbar(id: "main-toolbar") {
            ToolbarItem(id: "describe-rule", placement: .primaryAction) {
                Button("Descrever automação", systemImage: "text.bubble") { showsDescription = true }
            }
            ToolbarItem(id: "new-rule", placement: .primaryAction) {
                Button {
                    select(.rules)
                    createRule()
                } label: {
                    Label("Novo atalho", systemImage: "plus")
                }
                .labelStyle(.titleAndIcon)
                .accessibilityIdentifier("tico.toolbar.new-rule")
            }

            ToolbarSpacer(.fixed, placement: .primaryAction)

            ToolbarItem(id: "capture", placement: .primaryAction) {
                Button(action: controller.toggleCapture) {
                    Label(
                        controller.captureIsRunning ? "Pausar captura" : "Iniciar captura",
                        systemImage: controller.captureIsRunning ? "pause.fill" : "play.fill"
                    )
                }
                .buttonStyle(.glassProminent)
                .tint(
                    controller.captureIsRunning
                        ? Color.orange
                        : TicoBrand.Palette.primary
                )
                .help(controller.captureIsRunning ? "Pausar captura global" : "Iniciar captura global")
            }
        }
        .onAppear {
            guard !didPerformInitialSetup else { return }
            didPerformInitialSetup = true
            selectedSection = TicoSection(rawValue: storedSection) ?? .overview
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
            GesturePracticeView(session: controller.practiceSession, isRecording: controller.recordingIsActive,
                startupError: controller.trackpadStartupError,
                onFinish: {
                    controller.endPractice(sessionID: presentation.id)
                    practicePresentation = nil
                })
                .onDisappear { controller.endPractice(sessionID: presentation.id) }
        }
        .sheet(isPresented: $showsDescription) {
            DescribeAutomationView(applications: controller.availableApplications,
                latestEvent: controller.recordedEvent, recordingIsActive: controller.recordingIsActive,
                captureMode: controller.trackpadCaptureMode, startupError: controller.trackpadStartupError,
                snapshot: controller.laboratorySnapshot, onStartRecording: controller.beginRecording,
                onStopRecording: controller.endRecording, onCreate: installDraft)
        }
        .sheet(item: $ruleWorkspace.presentedEditor) { session in
            ShortcutComposerView(session: session, practiceSession: controller.practiceSession,
                applications: controller.availableApplications, macOSShortcuts: controller.availableMacOSShortcuts,
                profiles: shortcutStore.profiles, reusableWorkflows: shortcutStore.reusableWorkflows,
                presets: shortcutStore.presets, displays: controller.availableDisplays,
                latestEvent: controller.recordedEvent, recordingIsActive: controller.recordingIsActive,
                captureMode: controller.trackpadCaptureMode, startupError: controller.trackpadStartupError,
                snapshot: controller.laboratorySnapshot, detectedTrackpads: controller.detectedTrackpads,
                deviceCapabilities: controller.capabilityStore.devices,
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
        .alert(item: scriptApprovalBinding) { approval in
            Alert(
                title: Text("Executar automação de “\(approval.ruleName)”?"),
                message: Text(approval.command),
                primaryButton: .default(Text("Executar")) {
                    controller.resolveScriptApproval(approved: true)
                },
                secondaryButton: .cancel {
                    controller.resolveScriptApproval(approved: false)
                }
            )
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch currentSection {
        case .explore:
            ExploreView(applications: controller.availableApplications, onChoose: installDraft,
                onPractice: practice, onDescribe: { showsDescription = true }, onOpenLibrary: { select(.library) })
        case .gestureMap:
            GestureMapView(rules: shortcutStore.rules, profiles: shortcutStore.profiles,
                applications: controller.availableApplications, context: companion.context,
                onPractice: practice, onEdit: editRule)
        case .scenes:
            ScenesView(workflows: shortcutStore.reusableWorkflows, applications: controller.availableApplications,
                macOSShortcuts: controller.availableMacOSShortcuts, runningIDs: companion.runningIDs,
                lastReport: companion.lastReport, onSave: shortcutStore.saveReusableWorkflow,
                onDelete: shortcutStore.deleteReusableWorkflow, onRun: companion.runScene,
                onCancel: companion.cancel, onCreateRule: installSceneRule)
        case .overview:
            VStack(spacing: 0) {
                ExecutionInsightView(explanation: companion.explanation, report: companion.lastReport,
                    onEdit: editRule, onExplore: { select(.explore) })
                OverviewView(
                enabledRuleCount: shortcutStore.rules.filter(\.isEnabled).count,
                totalRuleCount: shortcutStore.rules.count,
                captureIsRunning: controller.captureIsRunning,
                trackpadCaptureMode: controller.trackpadCaptureMode,
                trackpadStartupError: controller.trackpadStartupError,
                permissionsAreReady: permissions.status.canCaptureGlobalInput,
                lastEventDescription: controller.lastEvent?.displayName,
                lastEventDate: controller.lastEvent?.timestamp,
                recentLogMessages: eventLogStore.entries.map { $0.result.message },
                onToggleCapture: controller.toggleCapture,
                onCreateRule: {
                    select(.rules)
                    createRule()
                },
                onOpenPermissions: { select(.permissions) }
                )
            }

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
                profiles: shortcutStore.profiles,
                reusableWorkflows: shortcutStore.reusableWorkflows,
                presets: shortcutStore.presets,
                detectedTrackpads: controller.detectedTrackpads,
                deviceCapabilities: controller.capabilityStore.devices,
                currentContext: controller.currentContextSnapshot,
                onStartRecording: controller.beginRecording,
                onStopRecording: controller.endRecording,
                onSaveReusableWorkflow: shortcutStore.saveReusableWorkflow,
                onSavePreset: shortcutStore.savePreset,
                onPractice: practice
            )

        case .profiles:
            ProfilesView(
                store: shortcutStore,
                applications: controller.availableApplications
            )

        case .library:
            GestureLibraryView(store: shortcutStore)

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

        case .metrics:
            MetricsView(store: controller.metricsStore)

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

    private var scriptApprovalBinding: Binding<PendingScriptApproval?> {
        Binding(
            get: { controller.pendingScriptApproval },
            set: { approval in
                guard approval == nil, controller.pendingScriptApproval != nil else { return }
                controller.resolveScriptApproval(approved: false)
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
        guard let id = controller.beginPractice(rule) else { return }
        practicePresentation = PracticePresentation(id: id)
    }

    private func editRule(_ id: UUID) {
        guard shortcutStore.rules.contains(where: { $0.id == id }) else { return }
        applicationFilter = nil
        selectedRuleID = id
        select(.rules)
    }

    private func installDraft(_ draft: ShortcutRule) {
        applicationFilter = nil
        do {
            var disabled = draft
            disabled.isEnabled = false
            let rule = try shortcutStore.add(disabled)
            selectedRuleID = rule.id
            select(.rules)
        } catch { controller.presentedError = error.localizedDescription }
    }

    private func installSceneRule(_ workflow: ActionWorkflow) {
        installDraft(ShortcutRule(name: workflow.name, isEnabled: false,
            trigger: .keyboard(keyCode: 49, modifiers: [.command, .option, .shift]),
            action: workflow.steps.first?.action ?? .notification(title: "Tico", body: "Cena vazia"),
            workflow: workflow, notes: "Escolha um gatilho e associe um perfil em Escopo, se desejar."))
    }

    private func createRule() {
        applicationFilter = nil
        ruleWorkspace.create()
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
}
