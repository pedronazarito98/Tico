import SwiftUI

/// Inspetor da seleção. Não cria outro rascunho: observa a sessão mantida pela janela.
/// Paralelo com React: recebe estado controlado e encaminha ações aos owners existentes.
struct RuleEditorView: View {
    let latestRecordedEvent: InputEventDescriptor?
    let recordingIsActive: Bool
    let trackpadCaptureMode: TrackpadCaptureMode
    let trackpadStartupError: String?
    let trackpadSnapshot: TrackpadLaboratorySnapshot?
    let applications: [ApplicationChoice]
    let macOSShortcuts: [String]

    let reusableWorkflows: [ActionWorkflow]
    let presets: [GesturePreset]
    let detectedTrackpads: [TrackpadHardwareInfo]
    let deviceCapabilities: [String: TrackpadDeviceCapability]
    let currentContext: ContextSnapshot?
    let onStartRecording: () -> Bool
    let onStopRecording: () -> Void
    let onSaveReusableWorkflow: (ActionWorkflow) throws -> Void
    let onSavePreset: (GesturePreset) throws -> Void
    let onPractice: (ShortcutRule) -> Void
    let conflictsForRule: (ShortcutRule) -> [RuleConflict]
    let onSave: (ShortcutRule) throws -> Void
    let onReplaceConflicts: (ShortcutRule) throws -> Void
    let onDelete: () -> Void

    @ObservedObject var session: RuleEditingSession

    var body: some View {
        VStack(spacing: 0) {
            RuleEditorHeaderView(
                name: $session.draft.name,
                isEnabled: $session.draft.isEnabled,
                hasUnsavedChanges: session.hasUnsavedChanges
            )
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    RuleInspectorTriggerView(trigger: $session.draft.trigger,
                        advancedTrackpadOptionsAreExpanded: $session.advancedTrackpadOptionsAreExpanded,
                        captureMode: trackpadCaptureMode, detectedTrackpads: detectedTrackpads,
                        deviceCapabilities: deviceCapabilities, onRecord: startRecording)
                    Divider()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ação").font(.headline)
                        WorkflowEditorView(workflow: $session.draft.workflow, applications: applications,
                            macOSShortcuts: macOSShortcuts, reusableWorkflows: reusableWorkflows,
                            onSaveReusable: onSaveReusableWorkflow)
                        if workflowUsesContinuousAction && trackpadCaptureMode != .advancedGlobal {
                            Label("Ações contínuas exigem captura global avançada.", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption).foregroundStyle(.orange)
                        }
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Disponível em").font(.headline)
                        RuleScopeComposerView(scope: $session.draft.scope, applications: applications)
                    }
                    Divider()

                    if !draftConflicts.isEmpty { conflictSummary }
                    if let issue = session.validationMessage {
                        Label(issue, systemImage: "exclamationmark.circle")
                            .font(.callout).foregroundStyle(.orange)
                    }

                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 16) {
                            RuleContextEditorView(scope: $session.draft.scope,
                                conditions: $session.draft.conditions,
                                applications: applications, currentContext: currentContext, showsScopePicker: false)
                            Stepper("Prioridade: \(session.draft.priority)", value: $session.draft.priority, in: -20...20)
                            TextField("Notas opcionais", text: $session.draft.notes, axis: .vertical).lineLimit(2...5)
                        }.padding(.top, 14)
                    } label: {
                        Label(advancedSummary, systemImage: "slider.horizontal.3").foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
            RuleEditorFooterView(
                hasUnsavedChanges: session.hasUnsavedChanges,
                canSave: session.canSave,
                presets: presets,
                onDelete: onDelete,
                onPractice: { onPractice(session.draft) },
                onRevert: revert,
                onSaveAsPreset: saveAsPreset,
                onApplyPreset: applyPreset,
                onSave: save
            )
        }
        .controlSize(.small)
        .textFieldStyle(.roundedBorder)
        .sheet(item: $session.recordingMode, onDismiss: onStopRecording) { mode in
            TriggerRecorderView(
                mode: mode,
                suggestedName: session.draft.name,
                isRecording: recordingIsActive,
                latestEvent: latestRecordedEvent,
                captureMode: trackpadCaptureMode,
                startupError: trackpadStartupError,
                snapshot: trackpadSnapshot,
                onCancel: finishRecording,
                onUseTrigger: { trigger in
                    session.draft.trigger = trigger
                    finishRecording()
                }
            )
        }
        .alert("Não foi possível salvar", isPresented: saveErrorIsPresented) {
            Button("OK", role: .cancel) { session.clearSaveError() }
        } message: {
            Text(session.saveError ?? "Erro desconhecido")
        }
        .confirmationDialog(
            "Este gatilho já está em uso",
            isPresented: conflictSaveIsPresented,
            titleVisibility: .visible
        ) {
            Button("Substituir regra existente", role: .destructive) {
                replaceConflicts()
            }
            Button("Cancelar", role: .cancel) {
                session.clearPendingConflict()
            }
        } message: {
            Text(blockingConflicts.map(\.message).joined(separator: "\n"))
        }
    }

    private var advancedSummary: String {
        let count = session.draft.conditions.count
        return count > 0 ? "Opções avançadas · \(count) \(count == 1 ? "condição aplicada" : "condições aplicadas")" : "Opções avançadas"
    }

    private var workflowUsesContinuousAction: Bool {
        session.draft.workflow.enabledSteps.contains { step in
            if case .continuousWindow = step.action {
                return true
            }
            return false
        }
    }

    private var saveErrorIsPresented: Binding<Bool> {
        Binding(
            get: { session.saveError != nil },
            set: { if !$0 { session.clearSaveError() } }
        )
    }

    private var conflictSaveIsPresented: Binding<Bool> {
        Binding(
            get: { session.pendingConflictSave != nil },
            set: { if !$0 { session.clearPendingConflict() } }
        )
    }

    private var draftConflicts: [RuleConflict] {
        conflictsForRule(session.draftForPersistence)
    }

    private var blockingConflicts: [RuleConflict] {
        draftConflicts.filter { $0.severity == .replacementRequired }
    }

    private var conflictSummary: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(draftConflicts) { conflict in
                Label(
                    conflict.message,
                    systemImage: conflict.severity == .replacementRequired
                        ? "exclamationmark.triangle.fill"
                        : "info.circle"
                )
                .font(.caption)
                .foregroundStyle(
                    conflict.severity == .replacementRequired ? .orange : .secondary
                )
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func save() {
        let value = session.draftForPersistence
        if !blockingConflicts.isEmpty {
            session.stageConflictSave(value)
            return
        }
        persist(value, replacingConflicts: false)
    }

    private func persist(_ value: ShortcutRule, replacingConflicts: Bool) {
        do {
            if replacingConflicts {
                try onReplaceConflicts(value)
            } else {
                try onSave(value)
            }
            session.markSaved(value)
        } catch {
            session.recordSaveError(error)
        }
    }

    private func replaceConflicts() {
        guard let pendingConflictSave = session.pendingConflictSave else { return }
        persist(pendingConflictSave, replacingConflicts: true)
    }

    private func revert() {
        session.revert()
    }

    private func saveAsPreset() {
        do {
            try onSavePreset(session.makePreset())
        } catch {
            session.recordSaveError(error)
        }
    }

    private func applyPreset(_ preset: GesturePreset) {
        session.applyPreset(preset)
    }

    private func startRecording(_ mode: TriggerRecordingMode) {
        guard onStartRecording() else { return }
        session.beginRecording(mode)
    }

    private func finishRecording() {
        session.finishRecording()
    }
}
