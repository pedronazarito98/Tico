# Arquivos desta fase de responsividade

A lista compara o código integrado com o snapshot anterior à correção de responsividade. Não representa todas as mudanças pendentes no Git; as funcionalidades e a revisão de UX anteriores já estavam no worktree.

Foram alterados 55 arquivos existentes e criados 3 componentes: `AdaptiveSheetFrame`, `AdaptiveSplitView` e `ContentPanelFooterView`. Nenhum novo teste, mock, fixture ou dependência foi criado nesta fase.

- `Sources/Tico/App/TicoApp.swift`
- `Sources/Tico/Services/ExperiencePanelPresenter.swift`
- `Sources/Tico/Services/SceneLayoutReviewPresenter.swift`
- `Sources/Tico/Views/Components/AdaptiveSheetFrame.swift`
- `Sources/Tico/Views/Components/AdaptiveSplitView.swift`
- `Sources/Tico/Views/Components/Content/ContentActionEditorView.swift`
- `Sources/Tico/Views/Components/Content/ContentActionPanelView.swift`
- `Sources/Tico/Views/Components/Content/ContentDestinationEditorView.swift`
- `Sources/Tico/Views/Components/Content/ContentPanelActionsView.swift`
- `Sources/Tico/Views/Components/Content/ContentPanelFooterView.swift`
- `Sources/Tico/Views/Components/Content/ContentPanelInputView.swift`
- `Sources/Tico/Views/Components/Content/ContentRecipeEditorView.swift`
- `Sources/Tico/Views/Components/ContentInteractionPanelView.swift`
- `Sources/Tico/Views/Components/DisplayRoutineEditorView.swift`
- `Sources/Tico/Views/Components/DisplayRoutinePromptView.swift`
- `Sources/Tico/Views/Components/DisplayRoutineSectionView.swift`
- `Sources/Tico/Views/Components/Rules/Composer/ComposerActionStep.swift`
- `Sources/Tico/Views/Components/Rules/Composer/ComposerReviewStep.swift`
- `Sources/Tico/Views/Components/Rules/Composer/KeyboardShortcutPicker.swift`
- `Sources/Tico/Views/Components/Rules/Composer/TriggerCaptureEditor.swift`
- `Sources/Tico/Views/Components/Rules/Composer/TriggerChoiceSurface.swift`
- `Sources/Tico/Views/Components/Rules/Composer/VisualKeyboardView.swift`
- `Sources/Tico/Views/Components/Rules/RuleActionPickerView.swift`
- `Sources/Tico/Views/Components/Rules/RuleInspectorTriggerView.swift`
- `Sources/Tico/Views/Components/Rules/RuleTriggerEditorView.swift`
- `Sources/Tico/Views/Components/Rules/ShortcutGestureRecorder.swift`
- `Sources/Tico/Views/Components/Rules/ShortcutOptionsView.swift`
- `Sources/Tico/Views/Components/Rules/ShortcutTriggerPicker.swift`
- `Sources/Tico/Views/Components/Rules/WindowActionChoices.swift`
- `Sources/Tico/Views/Components/Scenes/SceneCardView.swift`
- `Sources/Tico/Views/Components/Scenes/SceneLayoutCanvas.swift`
- `Sources/Tico/Views/Components/Scenes/SceneLayoutConfigurationView.swift`
- `Sources/Tico/Views/Components/Scenes/SceneLayoutPlanEditor.swift`
- `Sources/Tico/Views/Components/Scenes/SceneLayoutRecoveryView.swift`
- `Sources/Tico/Views/Components/Scenes/SceneLayoutReviewView.swift`
- `Sources/Tico/Views/Components/Scenes/SceneLayoutWindowEditor.swift`
- `Sources/Tico/Views/Components/ScriptApprovalView.swift`
- `Sources/Tico/Views/Components/ShortcutLearningGoalView.swift`
- `Sources/Tico/Views/Components/ShortcutLearningPromptView.swift`
- `Sources/Tico/Views/Components/TrackpadLaboratoryHUD.swift`
- `Sources/Tico/Views/ContentView.swift`
- `Sources/Tico/Views/DescribeAutomationView.swift`
- `Sources/Tico/Views/GestureLibraryView.swift`
- `Sources/Tico/Views/GestureMapView.swift`
- `Sources/Tico/Views/GesturePracticeView.swift`
- `Sources/Tico/Views/MetricsView.swift`
- `Sources/Tico/Views/OverviewView.swift`
- `Sources/Tico/Views/PermissionsView.swift`
- `Sources/Tico/Views/ProfilesView.swift`
- `Sources/Tico/Views/RulesView.swift`
- `Sources/Tico/Views/SceneEditorView.swift`
- `Sources/Tico/Views/ScenesView.swift`
- `Sources/Tico/Views/SequenceEditorView.swift`
- `Sources/Tico/Views/ShortcutComposerView.swift`
- `Sources/Tico/Views/TrackpadLaboratoryView.swift`
- `Sources/Tico/Views/TrackpadLiveView.swift`
- `Sources/Tico/Views/TriggerRecorderView.swift`

- `Xcode/TicoUITests/FirstShortcutUITests.swift` — adaptação da navegação do teste existente para rolar até os controles na janela compacta; todas as assertions anteriores foram preservadas.
