import SwiftUI

struct RuleEditorView: View {
    let rule: ShortcutRule
    let latestRecordedEvent: InputEventDescriptor?
    let recordingIsActive: Bool
    let trackpadCaptureMode: TrackpadCaptureMode
    let trackpadStartupError: String?
    let trackpadSnapshot: TrackpadLaboratorySnapshot?
    let applications: [ApplicationChoice]
    let macOSShortcuts: [String]
    let profiles: [ShortcutProfile]
    let reusableWorkflows: [ActionWorkflow]
    let presets: [GesturePreset]
    let detectedTrackpads: [TrackpadHardwareInfo]
    let deviceCapabilities: [String: TrackpadDeviceCapability]
    let currentContext: ContextSnapshot?
    let onStartRecording: () -> Void
    let onStopRecording: () -> Void
    let onSaveReusableWorkflow: (ActionWorkflow) throws -> Void
    let onSavePreset: (GesturePreset) throws -> Void
    let conflictsForRule: (ShortcutRule) -> [RuleConflict]
    let onSave: (ShortcutRule) throws -> Void
    let onReplaceConflicts: (ShortcutRule) throws -> Void
    let onDelete: () -> Void

    @StateObject private var session: RuleEditingSession

    init(
        rule: ShortcutRule,
        latestRecordedEvent: InputEventDescriptor?,
        recordingIsActive: Bool,
        trackpadCaptureMode: TrackpadCaptureMode,
        trackpadStartupError: String?,
        trackpadSnapshot: TrackpadLaboratorySnapshot?,
        applications: [ApplicationChoice],
        macOSShortcuts: [String],
        profiles: [ShortcutProfile],
        reusableWorkflows: [ActionWorkflow],
        presets: [GesturePreset],
        detectedTrackpads: [TrackpadHardwareInfo],
        deviceCapabilities: [String: TrackpadDeviceCapability],
        currentContext: ContextSnapshot?,
        onStartRecording: @escaping () -> Void,
        onStopRecording: @escaping () -> Void,
        onSaveReusableWorkflow: @escaping (ActionWorkflow) throws -> Void,
        onSavePreset: @escaping (GesturePreset) throws -> Void,
        conflictsForRule: @escaping (ShortcutRule) -> [RuleConflict],
        onSave: @escaping (ShortcutRule) throws -> Void,
        onReplaceConflicts: @escaping (ShortcutRule) throws -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.rule = rule
        self.latestRecordedEvent = latestRecordedEvent
        self.recordingIsActive = recordingIsActive
        self.trackpadCaptureMode = trackpadCaptureMode
        self.trackpadStartupError = trackpadStartupError
        self.trackpadSnapshot = trackpadSnapshot
        self.applications = applications
        self.macOSShortcuts = macOSShortcuts
        self.profiles = profiles
        self.reusableWorkflows = reusableWorkflows
        self.presets = presets
        self.detectedTrackpads = detectedTrackpads
        self.deviceCapabilities = deviceCapabilities
        self.currentContext = currentContext
        self.onStartRecording = onStartRecording
        self.onStopRecording = onStopRecording
        self.onSaveReusableWorkflow = onSaveReusableWorkflow
        self.onSavePreset = onSavePreset
        self.conflictsForRule = conflictsForRule
        self.onSave = onSave
        self.onReplaceConflicts = onReplaceConflicts
        self.onDelete = onDelete
        _session = StateObject(wrappedValue: RuleEditingSession(rule: rule))
    }

    private var draft: ShortcutRule {
        get { session.draft }
        nonmutating set { session.draft = newValue }
    }

    private var urlText: String {
        get { session.urlText }
        nonmutating set { session.urlText = newValue }
    }

    private var recordingMode: TriggerRecordingMode? {
        get { session.recordingMode }
        nonmutating set { session.recordingMode = newValue }
    }

    private var advancedTrackpadOptionsAreExpanded: Bool {
        get { session.advancedTrackpadOptionsAreExpanded }
        nonmutating set { session.advancedTrackpadOptionsAreExpanded = newValue }
    }

    private var saveError: String? {
        get { session.saveError }
        nonmutating set {
            if newValue == nil {
                session.clearSaveError()
            } else {
                session.saveError = newValue
            }
        }
    }

    private var pendingConflictSave: ShortcutRule? {
        get { session.pendingConflictSave }
        nonmutating set {
            if let newValue {
                session.stageConflictSave(newValue)
            } else {
                session.clearPendingConflict()
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            RuleEditorHeaderView(
                name: $session.draft.name,
                isEnabled: $session.draft.isEnabled,
                hasUnsavedChanges: hasUnsavedChanges
            )
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Escopo", systemImage: "app.badge.checkmark")
                                .font(.headline)
                            Divider()
                            RuleContextEditorView(
                                scope: $session.draft.scope,
                                profileID: $session.draft.profileID,
                                conditions: $session.draft.conditions,
                                profiles: profiles,
                                applications: applications,
                                currentContext: currentContext
                            )
                            Stepper(
                                "Prioridade: \(draft.priority)",
                                value: $session.draft.priority,
                                in: -10...10
                            )
                        }
                        .padding(4)
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label("Quando", systemImage: "cursorarrow.rays")
                                    .font(.headline)
                                Spacer()
                                Text(draft.trigger.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Divider()

                            RuleTriggerEditorView(
                                trigger: $session.draft.trigger,
                                advancedTrackpadOptionsAreExpanded: $session.advancedTrackpadOptionsAreExpanded,
                                captureMode: trackpadCaptureMode,
                                detectedTrackpads: detectedTrackpads,
                                deviceCapabilities: deviceCapabilities
                            )

                            if !draftConflicts.isEmpty {
                                conflictSummary
                            }

                            HStack {
                                Button {
                                    startRecording(.standard)
                                } label: {
                                    Label("Gravar gatilho", systemImage: "record.circle")
                                }

                                Button {
                                    startRecording(.customTrackpad)
                                } label: {
                                    Label("Ensinar gesto", systemImage: "scribble.variable")
                                }
                                .help("Crie um gesto de trajetória livre com três amostras")

                                Spacer()

                                if trackpadCaptureMode == .advancedGlobal {
                                    Label("Trackpad pronto", systemImage: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .padding(4)
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Então", systemImage: "bolt.fill")
                                .font(.headline)
                            Divider()

                            WorkflowEditorView(
                                workflow: $session.draft.workflow,
                                applications: applications,
                                macOSShortcuts: macOSShortcuts,
                                reusableWorkflows: reusableWorkflows,
                                onSaveReusable: onSaveReusableWorkflow
                            )

                            if workflowUsesContinuousAction
                                && trackpadCaptureMode != .advancedGlobal {
                                Label(
                                    "Ações contínuas exigem a captura global avançada. "
                                        + "O fallback público não fornece fases de movimento.",
                                    systemImage: "exclamationmark.triangle.fill"
                                )
                                .font(.caption)
                                .foregroundStyle(.orange)
                            }
                        }
                        .padding(4)
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Detalhes", systemImage: "text.alignleft")
                                .font(.headline)
                            TextField("Notas opcionais", text: $session.draft.notes, axis: .vertical)
                                .lineLimit(2...5)
                        }
                        .padding(4)
                    }
                }
                .padding(22)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }

            Divider()
            RuleEditorFooterView(
                hasUnsavedChanges: hasUnsavedChanges,
                canSave: canSave,
                presets: presets,
                onDelete: onDelete,
                onRevert: revert,
                onSaveAsPreset: saveAsPreset,
                onApplyPreset: applyPreset,
                onSave: save
            )
        }
        .sheet(item: $session.recordingMode, onDismiss: onStopRecording) { mode in
            TriggerRecorderView(
                mode: mode,
                suggestedName: draft.name,
                isRecording: recordingIsActive,
                latestEvent: latestRecordedEvent,
                captureMode: trackpadCaptureMode,
                startupError: trackpadStartupError,
                snapshot: trackpadSnapshot,
                onCancel: finishRecording,
                onUseTrigger: { trigger in
                    draft.trigger = trigger
                    finishRecording()
                }
            )
        }
        .alert("Não foi possível salvar", isPresented: saveErrorIsPresented) {
            Button("OK", role: .cancel) { session.clearSaveError() }
        } message: {
            Text(saveError ?? "Erro desconhecido")
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

    private var workflowUsesContinuousAction: Bool {
        draft.workflow.enabledSteps.contains { step in
            if case .continuousWindow = step.action {
                return true
            }
            return false
        }
    }

    private var urlIsValid: Bool {
        session.urlIsValid
    }

    private var canSave: Bool {
        session.canSave
    }

    private var hasUnsavedChanges: Bool {
        session.hasUnsavedChanges
    }

    private var draftForPersistence: ShortcutRule {
        session.draftForPersistence
    }

    private var saveErrorIsPresented: Binding<Bool> {
        Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )
    }

    private var conflictSaveIsPresented: Binding<Bool> {
        Binding(
            get: { pendingConflictSave != nil },
            set: { if !$0 { pendingConflictSave = nil } }
        )
    }

    private var draftConflicts: [RuleConflict] {
        conflictsForRule(draftForPersistence)
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
        let value = draftForPersistence
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
        guard let pendingConflictSave else { return }
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
        session.beginRecording(mode)
        onStartRecording()
    }

    private func finishRecording() {
        session.finishRecording()
    }
}
