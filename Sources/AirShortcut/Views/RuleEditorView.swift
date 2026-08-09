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
            editorHeader
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

                            Picker("Tipo de gatilho", selection: triggerKind) {
                                ForEach(EditorTriggerKind.allCases) { kind in
                                    Label(kind.title, systemImage: kind.systemImage).tag(kind)
                                }
                            }

                            triggerFields

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
            editorFooter
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

    private var editorHeader: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Nome da regra", text: $session.draft.name)
                    .textFieldStyle(.plain)
                    .font(.title2.weight(.semibold))
                Text(hasUnsavedChanges ? "Alterações não salvas" : "Regra atualizada")
                    .font(.caption)
                    .foregroundStyle(hasUnsavedChanges ? .orange : .secondary)
            }
            Spacer()
            Toggle("Ativa", isOn: $session.draft.isEnabled)
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    private var workflowUsesContinuousAction: Bool {
        draft.workflow.enabledSteps.contains { step in
            if case .continuousWindow = step.action {
                return true
            }
            return false
        }
    }

    private var editorFooter: some View {
        HStack {
            Button("Excluir", role: .destructive, action: onDelete)
            Spacer()
            Button("Reverter", action: revert)
                .disabled(!hasUnsavedChanges)
            Menu {
                Button("Salvar regra como preset") {
                    saveAsPreset()
                }
                if !presets.isEmpty {
                    Divider()
                    ForEach(presets) { preset in
                        Button("Aplicar “\(preset.name)”") {
                            applyPreset(preset)
                        }
                    }
                }
            } label: {
                Label("Preset", systemImage: "square.stack.3d.up")
            }
            Button("Salvar", action: save)
                .buttonStyle(.borderedProminent)
                .disabled(!canSave || !hasUnsavedChanges)
                .keyboardShortcut("s", modifiers: [.command])
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var triggerFields: some View {
        switch draft.trigger {
        case .keyboard:
            Stepper("Código da tecla: \(keyboardKeyCode.wrappedValue)", value: keyboardKeyCode, in: 0...255)
            modifierToggles
        case .mouseButton:
            Stepper("Número do botão: \(mouseButton.wrappedValue)", value: mouseButton, in: 0...31)
            modifierToggles
        case .trackpad:
            Picker("Gesto", selection: trackpadGesture) {
                ForEach(TrackpadGesture.allCases, id: \.self) { gesture in
                    Text(gesture.displayName).tag(gesture)
                }
            }
            HStack {
                Stepper(
                    "Mínimo: \(trackpadMinimumFingerCount.wrappedValue)",
                    value: trackpadMinimumFingerCount,
                    in: 2...trackpadMaximumFingerCount.wrappedValue
                )
                Stepper(
                    "Máximo: \(trackpadMaximumFingerCount.wrappedValue)",
                    value: trackpadMaximumFingerCount,
                    in: trackpadMinimumFingerCount.wrappedValue...5
                )
            }
            Picker("Região inicial", selection: trackpadRegion) {
                ForEach(TrackpadRegion.allCases, id: \.self) { region in
                    Text(region.displayName).tag(region)
                }
            }
            if currentTrackpadSpec.gesture == .tap {
                Stepper(
                    "Quantidade de toques: \(trackpadTapCount.wrappedValue)",
                    value: trackpadTapCount,
                    in: 1...3
                )
                if trackpadTapCount.wrappedValue > 1 {
                    LabeledContent("Intervalo entre toques") {
                        HStack {
                            Slider(
                                value: trackpadMaximumTapInterval,
                                in: 0.15...1,
                                step: 0.05
                            )
                            .frame(width: 160)
                            Text(
                                trackpadMaximumTapInterval.wrappedValue,
                                format: .number.precision(.fractionLength(2))
                            )
                            .monospacedDigit()
                            Text("s")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if currentTrackpadSpec.gesture.requiresRawContacts {
                Stepper(
                    "Dedos âncora: \(trackpadAnchorFingerCount.wrappedValue)",
                    value: trackpadAnchorFingerCount,
                    in: 1...4
                )
            }
            if currentTrackpadSpec.gesture == .fingerChord {
                TextField("Ordem de entrada (ex.: 1,2,3)", text: trackpadEntryOrderText)
                TextField("Ordem de saída (ex.: 3,2,1)", text: trackpadExitOrderText)
            }
            VStack(alignment: .leading, spacing: 7) {
                Text("Modificadores mantidos durante o gesto")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                trackpadModifierToggles
            }
            trackpadCapabilityNotice
            DisclosureGroup(
                "Ajustes avançados",
                isExpanded: $session.advancedTrackpadOptionsAreExpanded
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Exigir região final", isOn: trackpadEndRegionIsEnabled)
                    if trackpadEndRegionIsEnabled.wrappedValue {
                        Picker("Região final", selection: trackpadEndRegion) {
                            ForEach(TrackpadRegion.allCases.filter { $0 != .any }, id: \.self) { region in
                                Text(region.displayName).tag(region)
                            }
                        }
                    }
                    LabeledContent("Sensibilidade") {
                        HStack {
                            Slider(value: trackpadSensitivity, in: 0.25...2, step: 0.05)
                                .frame(width: 180)
                            Text(
                                trackpadSensitivity.wrappedValue,
                                format: .number.precision(.fractionLength(2))
                            )
                            .monospacedDigit()
                            .frame(width: 38, alignment: .trailing)
                        }
                    }
                    optionalThreshold(
                        title: "Velocidade mínima",
                        value: trackpadMinimumVelocity,
                        enabled: trackpadMinimumVelocityIsEnabled,
                        range: 0...4
                    )
                    optionalThreshold(
                        title: "Velocidade máxima",
                        value: trackpadMaximumVelocity,
                        enabled: trackpadMaximumVelocityIsEnabled,
                        range: 0...8
                    )
                    optionalThreshold(
                        title: "Pressão mínima",
                        value: trackpadPressureThreshold,
                        enabled: trackpadPressureThresholdIsEnabled,
                        range: 0...1
                    )
                    Toggle("Usar faixa de pressão", isOn: trackpadPressureRangeIsEnabled)
                    if trackpadPressureRangeIsEnabled.wrappedValue {
                        HStack {
                            Text("De")
                            Slider(value: trackpadPressureMinimum, in: 0...trackpadPressureMaximum.wrappedValue, step: 0.02)
                            Text(
                                trackpadPressureMinimum.wrappedValue,
                                format: .number.precision(.fractionLength(2))
                            )
                            Text("até")
                            Slider(value: trackpadPressureMaximum, in: trackpadPressureMinimum.wrappedValue...1, step: 0.02)
                            Text(
                                trackpadPressureMaximum.wrappedValue,
                                format: .number.precision(.fractionLength(2))
                            )
                        }
                        .font(.caption)
                    }
                    Picker("Dispositivo", selection: trackpadDeviceSelection) {
                        Text("Qualquer trackpad").tag(Self.anyDeviceTag)
                        Text("Trackpad padrão").tag(Self.defaultDeviceTag)
                        Divider()
                        ForEach(detectedTrackpads) { trackpad in
                            Text(trackpad.name).tag(trackpad.id)
                        }
                    }
                    if case .device = currentTrackpadSpec.deviceScope {
                        Toggle(
                            "Usar o trackpad padrão se este dispositivo desaparecer",
                            isOn: trackpadAllowsDeviceFallback
                        )
                    }
                    pressureCapabilityNotice
                }
                .padding(.top, 8)
            }
            Text("Captura global avançada experimental. Gestos reservados pelo macOS podem continuar executando a ação do sistema.")
                .font(.caption)
                .foregroundStyle(.secondary)

        case let .customTrackpad(template):
            HStack(alignment: .top, spacing: 16) {
                GesturePathPreview(path: template.representativePath)
                    .frame(width: 180, height: 130)
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Nome do gesto", text: customGestureName)
                    LabeledContent("Dedos") {
                        Text(template.fingerCount.displayText)
                    }
                    LabeledContent("Amostras") {
                        Text("\(template.samplePaths.count)")
                    }
                    LabeledContent("Tolerância") {
                        HStack {
                            Slider(value: customGestureTolerance, in: 0.05...0.5, step: 0.01)
                                .frame(width: 150)
                            Text(
                                customGestureTolerance.wrappedValue,
                                format: .number.precision(.fractionLength(2))
                            )
                            .monospacedDigit()
                        }
                    }
                }
            }
            Text("A trajetória é comparada localmente; posição e tamanho são normalizados, mas a direção é preservada.")
                .font(.caption)
                .foregroundStyle(.secondary)

        case let .sequence(sequence):
            SequenceEditorView(
                sequence: Binding(
                    get: { sequence },
                    set: { draft.trigger = .sequence($0) }
                )
            )
        }
    }

    private func optionalThreshold(
        title: String,
        value: Binding<Double>,
        enabled: Binding<Bool>,
        range: ClosedRange<Double>
    ) -> some View {
        HStack {
            Toggle(title, isOn: enabled)
                .frame(width: 170, alignment: .leading)
            Slider(value: value, in: range, step: 0.05)
                .disabled(!enabled.wrappedValue)
            Text(value.wrappedValue, format: .number.precision(.fractionLength(2)))
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)
                .foregroundStyle(enabled.wrappedValue ? .primary : .secondary)
        }
    }

    private var modifierToggles: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Modificadores")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                ForEach(InputModifier.allCases, id: \.self) { modifier in
                    Toggle(modifier.symbol, isOn: modifierBinding(modifier))
                        .toggleStyle(.button)
                        .help(modifier.displayName)
                }
            }
        }
    }

    private var triggerKind: Binding<EditorTriggerKind> {
        Binding(
            get: {
                switch draft.trigger {
                case .keyboard: .keyboard
                case .mouseButton: .mouseButton
                case .trackpad: .trackpad
                case .customTrackpad: .customTrackpad
                case .sequence: .sequence
                }
            },
            set: { kind in
                switch kind {
                case .keyboard: draft.trigger = .keyboard(keyCode: 49, modifiers: [.command])
                case .mouseButton: draft.trigger = .mouseButton(button: 3, modifiers: [])
                case .trackpad:
                    draft.trigger = .trackpad(gesture: .tap, fingerCount: 3, region: .any)
                case .customTrackpad:
                    draft.trigger = .customTrackpad(
                        template: CustomGestureTemplate(
                            name: "Meu gesto",
                            fingerCount: 3...3,
                            samplePaths: []
                        )
                    )
                case .sequence:
                    draft.trigger = .sequence(
                        TriggerSequence(steps: [
                            .trackpad(spec: TrackpadTriggerSpec(gesture: .swipeUp, fingerCount: 3)),
                            .trackpad(spec: TrackpadTriggerSpec(gesture: .swipeRight, fingerCount: 3))
                        ])
                    )
                }
            }
        )
    }

    private var keyboardKeyCode: Binding<UInt16> {
        Binding(
            get: {
                if case let .keyboard(keyCode, _) = draft.trigger { return keyCode }
                return 0
            },
            set: { newValue in
                draft.trigger = .keyboard(keyCode: newValue, modifiers: currentModifiers)
            }
        )
    }

    private var mouseButton: Binding<Int> {
        Binding(
            get: {
                if case let .mouseButton(button, _) = draft.trigger { return button }
                return 0
            },
            set: { newValue in
                draft.trigger = .mouseButton(button: newValue, modifiers: currentModifiers)
            }
        )
    }

    private var trackpadGesture: Binding<TrackpadGesture> {
        Binding(
            get: {
                if case let .trackpad(spec) = draft.trigger { return spec.gesture }
                return .tap
            },
            set: { value in
                var spec = currentTrackpadSpec
                spec.gesture = value
                draft.trigger = .trackpad(spec: spec)
            }
        )
    }

    private var trackpadMinimumFingerCount: Binding<Int> {
        Binding(
            get: { currentTrackpadSpec.fingerCount.lowerBound },
            set: { value in
                var spec = currentTrackpadSpec
                spec.fingerCount = value...max(value, spec.fingerCount.upperBound)
                draft.trigger = .trackpad(spec: spec)
            }
        )
    }

    private var trackpadMaximumFingerCount: Binding<Int> {
        Binding(
            get: { currentTrackpadSpec.fingerCount.upperBound },
            set: { value in
                var spec = currentTrackpadSpec
                spec.fingerCount = min(value, spec.fingerCount.lowerBound)...value
                draft.trigger = .trackpad(spec: spec)
            }
        )
    }

    private var trackpadRegion: Binding<TrackpadRegion> {
        Binding(
            get: {
                if case let .trackpad(spec) = draft.trigger { return spec.startRegion }
                return .any
            },
            set: { value in
                var spec = currentTrackpadSpec
                spec.startRegion = value
                draft.trigger = .trackpad(spec: spec)
            }
        )
    }

    private var trackpadSensitivity: Binding<Double> {
        Binding(
            get: { currentTrackpadSpec.sensitivity },
            set: { value in
                var spec = currentTrackpadSpec
                spec.sensitivity = value
                draft.trigger = .trackpad(spec: spec)
            }
        )
    }

    private var trackpadTapCount: Binding<Int> {
        Binding(
            get: { currentTrackpadSpec.tapCount },
            set: { value in
                var spec = currentTrackpadSpec
                spec.tapCount = value
                draft.trigger = .trackpad(spec: spec)
            }
        )
    }

    private var trackpadMaximumTapInterval: Binding<Double> {
        Binding(
            get: { currentTrackpadSpec.effectiveMaximumTapInterval },
            set: { value in
                var spec = currentTrackpadSpec
                spec.maximumTapInterval = value
                draft.trigger = .trackpad(spec: spec)
            }
        )
    }

    private var trackpadAnchorFingerCount: Binding<Int> {
        Binding(
            get: { currentTrackpadSpec.anchorFingerCount ?? 2 },
            set: { value in
                var spec = currentTrackpadSpec
                spec.anchorFingerCount = value
                draft.trigger = .trackpad(spec: spec)
            }
        )
    }

    private var trackpadEntryOrderText: Binding<String> {
        chordOrderBinding(keyPath: \.entryOrder)
    }

    private var trackpadExitOrderText: Binding<String> {
        chordOrderBinding(keyPath: \.exitOrder)
    }

    private var trackpadEndRegionIsEnabled: Binding<Bool> {
        Binding(
            get: { currentTrackpadSpec.endRegion != nil },
            set: { isEnabled in
                var spec = currentTrackpadSpec
                spec.endRegion = isEnabled ? (spec.endRegion ?? .topRight) : nil
                draft.trigger = .trackpad(spec: spec)
            }
        )
    }

    private var trackpadEndRegion: Binding<TrackpadRegion> {
        Binding(
            get: { currentTrackpadSpec.endRegion ?? .topRight },
            set: { region in
                var spec = currentTrackpadSpec
                spec.endRegion = region
                draft.trigger = .trackpad(spec: spec)
            }
        )
    }

    private var trackpadMinimumVelocityIsEnabled: Binding<Bool> {
        optionalTrackpadValueIsEnabled(
            keyPath: \.minimumVelocity,
            defaultValue: 0.1
        )
    }

    private var trackpadMinimumVelocity: Binding<Double> {
        optionalTrackpadValue(keyPath: \.minimumVelocity, defaultValue: 0.1)
    }

    private var trackpadMaximumVelocityIsEnabled: Binding<Bool> {
        optionalTrackpadValueIsEnabled(
            keyPath: \.maximumVelocity,
            defaultValue: 2
        )
    }

    private var trackpadMaximumVelocity: Binding<Double> {
        optionalTrackpadValue(keyPath: \.maximumVelocity, defaultValue: 2)
    }

    private var trackpadPressureThresholdIsEnabled: Binding<Bool> {
        optionalTrackpadValueIsEnabled(
            keyPath: \.pressureThreshold,
            defaultValue: 0.25
        )
    }

    private var trackpadPressureThreshold: Binding<Double> {
        optionalTrackpadValue(keyPath: \.pressureThreshold, defaultValue: 0.25)
    }

    private var trackpadPressureRangeIsEnabled: Binding<Bool> {
        Binding(
            get: { currentTrackpadSpec.pressureRange != nil },
            set: { enabled in
                var spec = currentTrackpadSpec
                spec.pressureRange = enabled ? (spec.pressureRange ?? 0.15...0.75) : nil
                draft.trigger = .trackpad(spec: spec)
            }
        )
    }

    private var trackpadPressureMinimum: Binding<Double> {
        Binding(
            get: { currentTrackpadSpec.pressureRange?.lowerBound ?? 0.15 },
            set: { value in
                var spec = currentTrackpadSpec
                spec.pressureRange = value...max(
                    value,
                    spec.pressureRange?.upperBound ?? 0.75
                )
                draft.trigger = .trackpad(spec: spec)
            }
        )
    }

    private var trackpadPressureMaximum: Binding<Double> {
        Binding(
            get: { currentTrackpadSpec.pressureRange?.upperBound ?? 0.75 },
            set: { value in
                var spec = currentTrackpadSpec
                spec.pressureRange = min(
                    value,
                    spec.pressureRange?.lowerBound ?? 0.15
                )...value
                draft.trigger = .trackpad(spec: spec)
            }
        )
    }

    private static let anyDeviceTag = "__any_device__"
    private static let defaultDeviceTag = "__default_device__"

    private var trackpadDeviceSelection: Binding<String> {
        Binding(
            get: {
                switch currentTrackpadSpec.deviceScope {
                case .any: Self.anyDeviceTag
                case .defaultDevice: Self.defaultDeviceTag
                case let .device(id): id
                }
            },
            set: { value in
                var spec = currentTrackpadSpec
                if value == Self.anyDeviceTag {
                    spec.deviceScope = .any
                } else if value == Self.defaultDeviceTag {
                    spec.deviceScope = .defaultDevice
                } else {
                    spec.deviceScope = .device(id: value)
                }
                draft.trigger = .trackpad(spec: spec)
            }
        )
    }

    private var trackpadAllowsDeviceFallback: Binding<Bool> {
        Binding(
            get: { currentTrackpadSpec.allowsDeviceFallback },
            set: { value in
                var spec = currentTrackpadSpec
                spec.allowsDeviceFallback = value
                draft.trigger = .trackpad(spec: spec)
            }
        )
    }

    private var customGestureName: Binding<String> {
        Binding(
            get: {
                if case let .customTrackpad(template) = draft.trigger {
                    return template.name
                }
                return ""
            },
            set: { value in
                guard case var .customTrackpad(template) = draft.trigger else { return }
                template.name = value
                draft.trigger = .customTrackpad(template: template)
            }
        )
    }

    private var customGestureTolerance: Binding<Double> {
        Binding(
            get: {
                if case let .customTrackpad(template) = draft.trigger {
                    return template.tolerance
                }
                return 0.2
            },
            set: { value in
                guard case var .customTrackpad(template) = draft.trigger else { return }
                template.tolerance = min(max(value, 0.05), 0.5)
                draft.trigger = .customTrackpad(template: template)
            }
        )
    }

    private var currentTrackpadSpec: TrackpadTriggerSpec {
        if case let .trackpad(spec) = draft.trigger {
            return spec
        }
        return TrackpadTriggerSpec(gesture: .tap, fingerCount: 3)
    }

    private var currentModifiers: Set<InputModifier> {
        switch draft.trigger {
        case let .keyboard(_, modifiers), let .mouseButton(_, modifiers): modifiers
        case .trackpad, .customTrackpad, .sequence: []
        }
    }

    private func modifierBinding(_ modifier: InputModifier) -> Binding<Bool> {
        Binding(
            get: { currentModifiers.contains(modifier) },
            set: { isEnabled in
                var modifiers = currentModifiers
                if isEnabled { modifiers.insert(modifier) } else { modifiers.remove(modifier) }
                switch draft.trigger {
                case let .keyboard(keyCode, _):
                    draft.trigger = .keyboard(keyCode: keyCode, modifiers: modifiers)
                case let .mouseButton(button, _):
                    draft.trigger = .mouseButton(button: button, modifiers: modifiers)
                case .trackpad, .customTrackpad:
                    break
                case .sequence:
                    break
                }
            }
        )
    }

    private var trackpadModifierToggles: some View {
        HStack {
            ForEach(InputModifier.allCases, id: \.self) { modifier in
                Toggle(modifier.symbol, isOn: Binding(
                    get: { currentTrackpadSpec.requiredModifiers?.contains(modifier) ?? false },
                    set: { enabled in
                        var spec = currentTrackpadSpec
                        var modifiers = spec.requiredModifiers ?? []
                        if enabled {
                            modifiers.insert(modifier)
                        } else {
                            modifiers.remove(modifier)
                        }
                        spec.requiredModifiers = modifiers.isEmpty ? nil : modifiers
                        draft.trigger = .trackpad(spec: spec)
                    }
                ))
                .toggleStyle(.button)
                .help(modifier.displayName)
            }
        }
    }

    @ViewBuilder
    private var trackpadCapabilityNotice: some View {
        switch trackpadCaptureMode.availability(for: currentTrackpadSpec.gesture) {
        case .available:
            EmptyView()
        case let .degraded(message):
            Label(message, systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        case let .unavailable(message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    private func chordOrderBinding(
        keyPath: WritableKeyPath<TrackpadTriggerSpec, [Int]?>
    ) -> Binding<String> {
        Binding(
            get: {
                (currentTrackpadSpec[keyPath: keyPath] ?? [])
                    .map(String.init)
                    .joined(separator: ",")
            },
            set: { text in
                var spec = currentTrackpadSpec
                let values = text
                    .split(separator: ",")
                    .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                    .filter { (1...5).contains($0) }
                spec[keyPath: keyPath] = values.isEmpty ? nil : values
                draft.trigger = .trackpad(spec: spec)
            }
        )
    }

    private func optionalTrackpadValue(
        keyPath: WritableKeyPath<TrackpadTriggerSpec, Double?>,
        defaultValue: Double
    ) -> Binding<Double> {
        Binding(
            get: { currentTrackpadSpec[keyPath: keyPath] ?? defaultValue },
            set: { value in
                var spec = currentTrackpadSpec
                spec[keyPath: keyPath] = value
                draft.trigger = .trackpad(spec: spec)
            }
        )
    }

    private func optionalTrackpadValueIsEnabled(
        keyPath: WritableKeyPath<TrackpadTriggerSpec, Double?>,
        defaultValue: Double
    ) -> Binding<Bool> {
        Binding(
            get: { currentTrackpadSpec[keyPath: keyPath] != nil },
            set: { enabled in
                var spec = currentTrackpadSpec
                spec[keyPath: keyPath] = enabled
                    ? (spec[keyPath: keyPath] ?? defaultValue)
                    : nil
                draft.trigger = .trackpad(spec: spec)
            }
        )
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

private extension RuleEditorView {
    @ViewBuilder
    var pressureCapabilityNotice: some View {
        let capability: TrackpadDeviceCapability? = {
            switch currentTrackpadSpec.deviceScope {
            case .any, .defaultDevice:
                return deviceCapabilities["default"]
            case let .device(id):
                return deviceCapabilities[id]
            }
        }()
        if let capability, capability.hasReliablePressure {
            Label(
                "Pressão observada: \(capability.minimumObservedPressure ?? 0, format: .number.precision(.fractionLength(2)))–\(capability.maximumObservedPressure ?? 0, format: .number.precision(.fractionLength(2)))",
                systemImage: "checkmark.circle.fill"
            )
            .font(.caption)
            .foregroundStyle(.green)
        } else if currentTrackpadSpec.pressureThreshold != nil
                    || currentTrackpadSpec.pressureRange != nil {
            Label(
                "Ainda não há amostras suficientes para confirmar pressão confiável neste dispositivo.",
                systemImage: "exclamationmark.triangle"
            )
            .font(.caption)
            .foregroundStyle(.orange)
        }
    }
}

private enum EditorTriggerKind: String, CaseIterable, Identifiable {
    case keyboard
    case mouseButton
    case trackpad
    case customTrackpad
    case sequence

    var id: Self { self }

    var title: String {
        switch self {
        case .keyboard: "Teclado"
        case .mouseButton: "Mouse"
        case .trackpad: "Trackpad"
        case .customTrackpad: "Personalizado"
        case .sequence: "Sequência"
        }
    }

    var systemImage: String {
        switch self {
        case .keyboard: "keyboard"
        case .mouseButton: "computermouse"
        case .trackpad: "rectangle.and.hand.point.up.left"
        case .customTrackpad: "scribble.variable"
        case .sequence: "point.3.connected.trianglepath.dotted"
        }
    }
}
