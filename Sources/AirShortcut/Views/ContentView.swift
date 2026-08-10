import SwiftUI

struct ContentView: View {
    @ObservedObject var controller: AppController
    @ObservedObject var shortcutStore: ShortcutStore
    @ObservedObject var eventLogStore: EventLogStore
    @ObservedObject var permissions: PermissionCoordinator
    @ObservedObject var commandRouter: AppCommandRouter

    @Environment(\.openWindow) private var openWindow
    @SceneStorage("mainSection") private var storedSection = AirShortcutSection.overview.rawValue
    @State private var selectedSection = AirShortcutSection.overview
    @State private var selectedRuleID: ShortcutRule.ID?
    @State private var didPerformInitialSetup = false

    var body: some View {
        NavigationSplitView {
            SidebarView(
                selection: sectionBinding,
                enabledRuleCount: shortcutStore.rules.filter(\.isEnabled).count,
                totalRuleCount: shortcutStore.rules.count,
                captureIsRunning: controller.captureIsRunning
            )
        } detail: {
            detail
        }
        .frame(minWidth: 860, minHeight: 560)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    select(.rules)
                    createRule()
                } label: {
                    Label("Nova regra", systemImage: "plus")
                }

                Button(action: controller.toggleCapture) {
                    Label(
                        controller.captureIsRunning ? "Pausar captura" : "Iniciar captura",
                        systemImage: controller.captureIsRunning ? "pause.fill" : "play.fill"
                    )
                }
                .help(controller.captureIsRunning ? "Pausar captura global" : "Iniciar captura global")
            }
        }
        .onAppear {
            guard !didPerformInitialSetup else { return }
            didPerformInitialSetup = true
            selectedSection = AirShortcutSection(rawValue: storedSection) ?? .overview
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
        .onReceive(commandRouter.$pendingCommand.compactMap { $0 }) { envelope in
            guard let command = commandRouter.consume(envelope) else { return }
            handle(command)
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
        case .overview:
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
                selectedRuleID: $selectedRuleID,
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
                onSavePreset: shortcutStore.savePreset
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

    private var currentSection: AirShortcutSection {
        selectedSection
    }

    private func handle(_ command: AppCommand) {
        switch command {
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

    private var sectionBinding: Binding<AirShortcutSection?> {
        Binding(
            get: { selectedSection },
            set: { newValue in
                guard let newValue, newValue != selectedSection else { return }
                select(newValue)
            }
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

    private func select(_ section: AirShortcutSection) {
        selectedSection = section
        storedSection = section.rawValue
    }

    private func createRule() {
        do {
            let rule = try shortcutStore.create(
                name: "Nova regra",
                trigger: .keyboard(keyCode: 49, modifiers: [.command]),
                action: .notification(title: TicoBrand.displayName, body: "Regra executada")
            )
            selectedRuleID = rule.id
        } catch {
            controller.presentedError = error.localizedDescription
        }
    }

    private func deleteSelectedRule() {
        guard currentSection == .rules, let selectedRuleID else { return }
        do {
            try shortcutStore.delete(id: selectedRuleID)
            self.selectedRuleID = shortcutStore.rules.first?.id
        } catch {
            controller.presentedError = error.localizedDescription
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
