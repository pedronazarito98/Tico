# Manifest da implementação

Este inventário distingue arquivos tocados nesta tarefa de mudanças que já
existiam no worktree. Arquivos compartilhados, como ContentView e AppController,
preservam os trechos anteriores; o diff total contra HEAD também inclui trabalho
anterior do usuário e não deve ser atribuído integralmente a esta tarefa.

## Modificados nesta tarefa

- `README.md`
- `Sources/Tico/App/Commands.swift`
- `Sources/Tico/Models/ActionWorkflow.swift`
- `Sources/Tico/Models/ShortcutAction.swift`
- `Sources/Tico/Services/ActionRunner.swift`
- `Sources/Tico/Services/ContextualPanelService.swift`
- `Sources/Tico/Services/WorkflowExecutor.swift`
- `Sources/Tico/Stores/ShortcutDocumentCodec.swift`
- `Sources/Tico/Support/AppCommandRouter.swift`
- `Sources/Tico/Support/AppController.swift`
- `Sources/Tico/Support/AutomationCoordinator.swift`
- `Sources/Tico/Support/CompanionCoordinator.swift`
- `Sources/Tico/Support/DisplayText.swift`
- `Sources/Tico/Support/DocumentSecurityPolicy.swift`
- `Sources/Tico/Views/Components/Rules/RuleActionKind.swift`
- `Sources/Tico/Views/Components/Rules/ShortcutActionCatalogView.swift`
- `Sources/Tico/Views/Components/Rules/WorkflowEditorValidation.swift`
- `Sources/Tico/Views/ContentView.swift`
- `Sources/Tico/Views/ContextualActionsView.swift`
- `Sources/Tico/Views/GestureMapView.swift`
- `Sources/Tico/Views/MenuBarContentView.swift`
- `Sources/Tico/Views/RuleActionEditorView.swift`
- `Sources/Tico/Views/SceneEditorView.swift`
- `Sources/Tico/Views/ScenesView.swift`
- `Sources/Tico/Views/WorkflowEditorView.swift`

## Criados nesta tarefa

- `.specs/features/contextual-experiences/files.md`
- `.specs/features/contextual-experiences/spec.md`
- `.specs/features/contextual-experiences/validation.md`
- `Sources/Tico/Models/AutomationContent.swift`
- `Sources/Tico/Models/AutomationExecutionOrigin.swift`
- `Sources/Tico/Models/ContentActionChoice.swift`
- `Sources/Tico/Models/ContentActionConfiguration.swift`
- `Sources/Tico/Models/DisplayEnvironmentSnapshot.swift`
- `Sources/Tico/Models/DisplayRoutine.swift`
- `Sources/Tico/Models/SceneLayoutPlan.swift`
- `Sources/Tico/Models/SceneLayoutPreview.swift`
- `Sources/Tico/Models/ShortcutLearningGoal.swift`
- `Sources/Tico/Services/Content/ContentActionService.swift`
- `Sources/Tico/Services/Content/ContentShortcutRunner.swift`
- `Sources/Tico/Services/Content/SelectionCaptureService.swift`
- `Sources/Tico/Services/DisplayEnvironmentMonitor.swift`
- `Sources/Tico/Services/ExperiencePanelPresenter.swift`
- `Sources/Tico/Services/SceneLayoutAccessibility.swift`
- `Sources/Tico/Services/SceneLayoutEnvironment.swift`
- `Sources/Tico/Services/SceneLayoutReviewPresenter.swift`
- `Sources/Tico/Services/SceneLayoutService.swift`
- `Sources/Tico/Services/SceneLayoutServicing.swift`
- `Sources/Tico/Services/ScriptApprovalPresenter.swift`
- `Sources/Tico/Stores/DisplayRoutineRepository.swift`
- `Sources/Tico/Stores/DisplayRoutineStore.swift`
- `Sources/Tico/Stores/ShortcutLearningRepository.swift`
- `Sources/Tico/Stores/ShortcutLearningStore.swift`
- `Sources/Tico/Support/ContentInteractionCoordinator.swift`
- `Sources/Tico/Support/ContextualExperienceCoordinator.swift`
- `Sources/Tico/Support/DisplayRoutineCoordinator.swift`
- `Sources/Tico/Support/SceneLayoutSession.swift`
- `Sources/Tico/Views/Components/Content/ContentActionEditorView.swift`
- `Sources/Tico/Views/Components/Content/ContentActionPanelView.swift`
- `Sources/Tico/Views/Components/Content/ContentPanelSession.swift`
- `Sources/Tico/Views/Components/ContentInteractionPanelView.swift`
- `Sources/Tico/Views/Components/DisplayRoutineEditorView.swift`
- `Sources/Tico/Views/Components/DisplayRoutinePromptView.swift`
- `Sources/Tico/Views/Components/DisplayRoutineSectionView.swift`
- `Sources/Tico/Views/Components/Scenes/SceneLayoutCanvas.swift`
- `Sources/Tico/Views/Components/Scenes/SceneLayoutConfigurationView.swift`
- `Sources/Tico/Views/Components/Scenes/SceneLayoutRecoveryView.swift`
- `Sources/Tico/Views/Components/Scenes/SceneLayoutReviewView.swift`
- `Sources/Tico/Views/Components/Scenes/SceneLayoutWindowEditor.swift`
- `Sources/Tico/Views/Components/ScriptApprovalView.swift`
- `Sources/Tico/Views/Components/ShortcutLearningGoalView.swift`
- `Sources/Tico/Views/Components/ShortcutLearningPromptView.swift`
- `Sources/Tico/Views/ScenesWorkspaceView.swift`
- `outputs/experiencias-contextuais.md`

## Preservados fora do escopo

Criador visual preexistente, LocalInputCaptureService, InputPresentation, alterações
preexistentes de GesturePracticeSession, testes XCUITest e script/build_and_run.sh.
Não foram criados testes, mocks, fixtures, dependências ou commits.
