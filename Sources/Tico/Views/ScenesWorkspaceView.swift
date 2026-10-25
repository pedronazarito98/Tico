import SwiftUI

/// Compõe cenas e rotinas no mesmo espaço, observando cada owner de estado.
/// ObservableObject não propaga mudanças de objetos aninhados automaticamente;
/// por isso as projeções das rotinas observam seus próprios store e coordenador.
/// Paralelo com React: a composição assina as fontes utilizadas e entrega valores
/// e callbacks à apresentação, sem duplicar listas ou executar efeitos no body.
struct ScenesWorkspaceView: View {
    @ObservedObject private var shortcutStore: ShortcutStore
    @ObservedObject private var companion: CompanionCoordinator
    @ObservedObject private var experiences: ContextualExperienceCoordinator
    @ObservedObject private var routineStore: DisplayRoutineStore
    @ObservedObject private var displayRoutines: DisplayRoutineCoordinator
    @ObservedObject private var layouts: SceneLayoutSession
    let applications: [ApplicationChoice]
    let macOSShortcuts: [String]
    let onCreateRule: (ActionWorkflow) -> Void
    var searchText = ""
    var newSceneRequest: UUID? = nil
    @State private var routineScene: ActionWorkflow?

    init(shortcutStore: ShortcutStore, companion: CompanionCoordinator,
         experiences: ContextualExperienceCoordinator, applications: [ApplicationChoice],
         macOSShortcuts: [String], onCreateRule: @escaping (ActionWorkflow) -> Void,
         searchText: String = "", newSceneRequest: UUID? = nil) {
        self.shortcutStore = shortcutStore
        self.companion = companion
        self.experiences = experiences
        routineStore = experiences.routineStore
        displayRoutines = experiences.displayRoutines
        layouts = experiences.sceneLayouts
        self.applications = applications
        self.macOSShortcuts = macOSShortcuts
        self.onCreateRule = onCreateRule
        self.searchText = searchText
        self.newSceneRequest = newSceneRequest
    }

    var body: some View {
        ScenesView(
            workflows: shortcutStore.reusableWorkflows,
            applications: applications,
            macOSShortcuts: macOSShortcuts,
            runningIDs: companion.runningIDs.union(layouts.resumedWorkflowID.map { [$0] } ?? []),
            lastReport: latestReport,
            onSave: shortcutStore.saveReusableWorkflow,
            onDelete: shortcutStore.deleteReusableWorkflow,
            onRun: companion.runScene,
            onCancel: { id in
                if layouts.resumedWorkflowID == id { layouts.cancelOperation() }
                else { companion.cancel(id) }
            },
            onCreateRule: onCreateRule,
            sceneLayouts: experiences.sceneLayouts,
            routineSection: DisplayRoutineSectionView(
                routines: routineStore.routines,
                isEnabled: routineStore.isEnabled,
                isMonitoringAvailable: displayRoutines.isObserving,
                workflows: shortcutStore.reusableWorkflows,
                statusMessage: displayRoutines.statusMessage,
                suggestion: displayRoutines.suggestion,
                errorMessage: routineStore.errorMessage,
                onSetEnabled: routineStore.setEnabled,
                onSave: routineStore.save,
                onDelete: routineStore.remove,
                onAccept: experiences.acceptRoutine,
                onDismiss: displayRoutines.dismissSuggestion
            ),
            searchText: searchText,
            newSceneRequest: newSceneRequest,
            onConfigureRoutine: { routineScene = $0 },
            hasPendingRecovery: layouts.hasPendingRecovery
        )
        .sheet(item: $routineScene) { scene in
            DisplayRoutineEditorView(initialWorkflowID: scene.id, workflows: shortcutStore.reusableWorkflows,
                isGloballyEnabled: routineStore.isEnabled, onSave: routineStore.save)
        }
    }

    private var latestReport: WorkflowExecutionReport? {
        [companion.lastReport, layouts.lastResumeReport].compactMap { $0 }
            .max { $0.finishedAt < $1.finishedAt }
    }
}
