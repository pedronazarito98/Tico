import SwiftUI

/// Criação visual e edição compartilham uma única sessão de rascunho. A captura
/// pertence ao controller; esta composição possui apenas o token da sua prática.
/// Paralelo com React: o formulário controla filhos por Binding e efeitos por callbacks.
struct ShortcutComposerView: View {
    @ObservedObject var session: RuleEditingSession
    @ObservedObject var practiceSession: GesturePracticeSession
    let applications: [ApplicationChoice]
    let macOSShortcuts: [String]
    let profiles: [ShortcutProfile]
    let reusableWorkflows: [ActionWorkflow]
    let presets: [GesturePreset]
    let displays: [DisplayCatalogService.Choice]
    let latestEvent: InputEventDescriptor?
    let recordingIsActive: Bool
    let captureMode: TrackpadCaptureMode
    let startupError: String?
    let snapshot: TrackpadLaboratorySnapshot?
    let detectedTrackpads: [TrackpadHardwareInfo]
    let deviceCapabilities: [String: TrackpadDeviceCapability]
    let onStartRecording: () -> Bool
    let onStopRecording: () -> Void
    let onStartPreview: (ShortcutRule) -> UUID?
    let onStopPreview: (UUID) -> Void
    let onSaveReusableWorkflow: (ActionWorkflow) throws -> Void
    let onSavePreset: (GesturePreset) throws -> Void
    let conflictsForRule: (ShortcutRule) -> [RuleConflict]
    let onSave: (ShortcutRule, Bool) throws -> Void
    let onCancel: () -> Void

    @State private var panel = Panel.preview
    @State private var presentedSheet: Sheet?
    @State private var showsScope = false
    @State private var showsTriggerPicker = false
    @State private var previewID: UUID?
    @State private var recognizedCount = 0
    @State private var ownsRecording = false
    @State private var captureError: String?
    @State private var asksToReplace = false

    private enum Panel { case preview, options, workflow }
    private enum Sheet: String, Identifiable {
        case gesture, standard, custom, actions
        var id: Self { self }
    }
    private var canSave: Bool { session.composerValidationMessage == nil }
    private var conflicts: [RuleConflict] { canSave ? conflictsForRule(session.draft) : [] }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TicoMarkView().frame(width: 24, height: 24).accessibilityHidden(true)
                Text("Tico").font(.headline)
                Spacer()
                Text(session.isNew ? "Novo atalho" : "Editar atalho").font(.headline)
                Spacer()
                Menu {
                    if !session.isNew { Button("Reverter alterações") { stopPreview(); session.revert() } }
                    Button("Salvar como modelo") {
                        do { try onSavePreset(session.makePreset()) } catch { session.recordSaveError(error) }
                    }.disabled(!canSave)
                    ForEach(presets) { preset in
                        Button("Usar modelo: \(preset.name)") {
                            stopPreview()
                            session.applyPreset(preset)
                            session.chooseTrigger(preset.trigger)
                            session.chooseAction(session.draft.action, title: preset.name)
                        }
                    }
                } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Mais opções do atalho")
            }.padding(.horizontal, 20).padding(.vertical, 12)
            Divider()
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    ShortcutActionCatalogView(applications: applications,
                        selectedAction: session.hasChosenAction ? session.draft.action : nil,
                        onSelect: chooseAction, onMoreActions: { presentedSheet = .actions })
                    Divider()
                    gestureSection
                    if panel == .options {
                        Divider()
                        Button("Cancelar") { stopRecording(); stopPreview(); onCancel() }
                            .keyboardShortcut(.cancelAction).padding(.top, 6)
                    }
                }.padding(18).frame(width: 305)
                Divider()
                Group {
                    switch panel {
                    case .preview: preview
                    case .options:
                        ShortcutOptionsView(session: session, applications: applications, profiles: profiles,
                            displays: displays, onClose: { panel = .preview })
                    case .workflow:
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Configurar ações").font(.title3.bold())
                                Spacer()
                                Button("Concluir") { panel = .preview }.buttonStyle(.borderedProminent)
                            }
                            ScrollView {
                                WorkflowEditorView(workflow: $session.draft.workflow, applications: applications,
                                    macOSShortcuts: macOSShortcuts, reusableWorkflows: reusableWorkflows,
                                    onSaveReusable: onSaveReusableWorkflow)
                            }
                        }.padding(20)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if panel != .options {
                Divider()
                footer
            }
        }
        .frame(width: 960, height: 680)
        .background(TicoBrand.Palette.background)
        .tint(TicoBrand.Palette.primary)
        .sheet(item: $presentedSheet, onDismiss: stopRecording) { sheet in sheetContent(sheet) }
        .onChange(of: practiceSession.completedCount) {
            guard previewID != nil, previewID == practiceSession.sessionID else { return }
            recognizedCount = practiceSession.completedCount
        }
        .onChange(of: session.draft.trigger) { stopPreview(); recognizedCount = 0 }
        .onChange(of: session.draft.workflow) { stopPreview(); recognizedCount = 0 }
        .onDisappear { stopRecording(); stopPreview() }
        .alert("Não foi possível concluir", isPresented: Binding(
            get: { session.saveError != nil || captureError != nil },
            set: { if !$0 { session.clearSaveError(); captureError = nil } }
        )) {
            Button("OK", role: .cancel) { session.clearSaveError(); captureError = nil }
        } message: { Text(session.saveError ?? captureError ?? "") }
        .confirmationDialog("Este gatilho já está em uso", isPresented: $asksToReplace, titleVisibility: .visible) {
            Button("Substituir atalho existente", role: .destructive) { persist(replacing: true) }
            Button("Cancelar", role: .cancel) { }
        } message: { Text(conflicts.map(\.message).joined(separator: "\n")) }
    }

    private var gestureSection: some View {
        VStack(spacing: 4) {
            Text("Seu gesto").font(.headline).frame(maxWidth: .infinity, alignment: .leading)
            ShortcutGesturePreview(trigger: session.hasChosenTrigger ? session.draft.trigger : nil, height: 92)
                .padding(.horizontal, 24)
            if session.hasChosenTrigger {
                Text(RuleEditorSummary.trigger(session.draft.trigger)).font(.callout).lineLimit(2)
                    .multilineTextAlignment(.center)
                Label(recognizedCount > 0 ? "Reconhecido agora" : "Acionamento definido", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(.green)
            }
            Button(session.hasChosenTrigger ? "Gravar novamente" : "Gravar gesto", systemImage: "record.circle") {
                beginRecording(.gesture)
            }.accessibilityIdentifier("tico.composer.record")
            Menu("Outros acionamentos") {
                Button("Escolher acionamento…") { stopPreview(); showsTriggerPicker = true }
                Button("Gravar teclado ou mouse…") { beginRecording(.standard) }
                Button("Desenhar meu gesto…") { beginRecording(.custom) }
            }.menuStyle(.borderlessButton).fixedSize().font(.caption)
                .popover(isPresented: $showsTriggerPicker) {
                    ShortcutTriggerPicker(trigger: session.draft.trigger, captureMode: captureMode,
                        detectedTrackpads: detectedTrackpads, deviceCapabilities: deviceCapabilities,
                        onChoose: session.chooseTrigger)
                }
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(previewID == nil ? "Veja o resultado" : "Experimente seu atalho").font(.headline)
                Spacer()
                if previewID != nil { Label("Teste na prévia", systemImage: "play.fill").font(.caption).foregroundStyle(.secondary) }
            }
            if session.hasChosenAction {
                ShortcutResultPreview(workflow: session.draft.workflow, applications: applications, recognitionCount: recognizedCount)
                if recognizedCount > 0 {
                    Label("Funcionou! O gesto foi reconhecido na prévia.", systemImage: "checkmark.circle.fill")
                        .font(.callout).foregroundStyle(.green).padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.green.opacity(0.09), in: .rect(cornerRadius: 8))
                }
                HStack {
                    Text(RuleEditorSummary.action(session.draft.action, applications: applications)).font(.callout)
                    Spacer()
                    Button("Configurar ações") { stopPreview(); panel = .workflow }.buttonStyle(.borderless)
                }
            } else {
                ContentUnavailableView("O que vamos automatizar?", systemImage: "cursorarrow.rays",
                    description: Text("Escolha um aplicativo ou uma ação ao lado para ver o resultado."))
                    .frame(maxWidth: .infinity, minHeight: 230)
            }
            HStack(spacing: 16) {
                if session.hasChosenTrigger {
                    Image(systemName: RuleEditorSummary.symbol(session.draft.trigger))
                        .font(.title2).foregroundStyle(TicoBrand.Palette.primary)
                    Text(RuleEditorSummary.trigger(session.draft.trigger)).font(.callout).lineLimit(2)
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    ShortcutActionIcon(action: session.draft.action, applications: applications, size: 30)
                } else {
                    Image(systemName: "hand.draw").font(.title2).foregroundStyle(.secondary)
                    Text("Grave um gesto para completar o atalho.").font(.callout)
                }
                Spacer(minLength: 0)
            }
            .padding(16).frame(maxWidth: .infinity, minHeight: 80)
            .background(TicoBrand.Palette.surface.opacity(0.5), in: .rect(cornerRadius: 9))
            .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(.quaternary) }
            if previewID != nil {
                Text("Repita o gesto. As ações serão mostradas somente na prévia.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let issue = session.hasChosenAction && session.hasChosenTrigger ? session.validationMessage : nil {
                Label(issue, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.orange)
            }
            if let conflict = conflicts.first {
                Label(conflict.message, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
            }
            Spacer(minLength: 0)
            HStack {
                Button { showsScope = true } label: {
                    Label(session.draft.scope.displayName(applications: applications), systemImage: "globe")
                        .lineLimit(2)
                }.buttonStyle(.borderless).accessibilityIdentifier("tico.composer.scope")
                    .popover(isPresented: $showsScope) {
                        ShortcutScopePicker(scope: $session.draft.scope, applications: applications)
                    }
                Spacer()
                Button("Mais ajustes", systemImage: "slider.horizontal.3") { stopPreview(); panel = .options }
                    .buttonStyle(.borderless).accessibilityIdentifier("tico.composer.options")
            }
        }.padding(20)
    }

    private var footer: some View {
        HStack {
            Button("Cancelar") { stopRecording(); stopPreview(); onCancel() }.keyboardShortcut(.cancelAction)
            Spacer()
            Button(previewID == nil ? "Experimentar gesto" : "Encerrar teste",
                   systemImage: previewID == nil ? "play.fill" : "stop.fill", action: togglePreview)
                .buttonStyle(.glass).disabled(!canSave)
                .accessibilityIdentifier("tico.composer.preview")
            Spacer()
            Button(session.isNew ? "Criar atalho" : "Salvar alterações", action: save)
                .buttonStyle(.glassProminent).disabled(!canSave)
                .keyboardShortcut("s", modifiers: .command)
                .accessibilityIdentifier("tico.composer.save")
        }.controlSize(.large).padding(.horizontal, 20).padding(.vertical, 13)
    }

    @ViewBuilder private func sheetContent(_ sheet: Sheet) -> some View {
        switch sheet {
        case .actions:
            RuleActionPickerView(applications: applications) { action in
                chooseAction(action, RuleEditorSummary.action(action, applications: applications))
                if case .openApplication = action { return }
                if case .window = action { return }
                panel = .workflow
            }
        case .gesture:
            ShortcutGestureRecorder(latestEvent: latestEvent, snapshot: snapshot, isRecording: recordingIsActive,
                startupError: startupError, onCancel: { presentedSheet = nil }, onUseTrigger: useRecording)
        case .standard, .custom:
            TriggerRecorderView(mode: sheet == .standard ? .standard : .customTrackpad,
                suggestedName: session.draft.name, isRecording: recordingIsActive,
                latestEvent: latestEvent, captureMode: captureMode, startupError: startupError,
                snapshot: snapshot, onCancel: { presentedSheet = nil }, onUseTrigger: useRecording)
        }
    }

    private func chooseAction(_ action: ShortcutAction, _ title: String) {
        stopPreview()
        session.chooseAction(action, title: title)
        recognizedCount = 0
    }
    private func beginRecording(_ sheet: Sheet) {
        stopPreview()
        guard onStartRecording() else { captureError = "Não foi possível iniciar a captura. Verifique as permissões ou encerre outra gravação."; return }
        ownsRecording = true
        presentedSheet = sheet
    }
    private func useRecording(_ trigger: TriggerDefinition) {
        session.chooseTrigger(trigger)
        presentedSheet = nil
        stopRecording()
    }
    private func stopRecording() {
        guard ownsRecording else { return }
        onStopRecording()
        ownsRecording = false
    }
    private func togglePreview() {
        if previewID != nil { stopPreview(); return }
        guard canSave else { return }
        recognizedCount = 0
        previewID = onStartPreview(session.draft)
        if previewID == nil { captureError = "A captura não está disponível. Verifique as permissões e tente novamente." }
    }
    private func stopPreview() {
        guard let previewID else { return }
        onStopPreview(previewID)
        self.previewID = nil
    }
    private func save() {
        guard canSave else { return }
        stopPreview()
        if conflicts.contains(where: { $0.severity == .replacementRequired }) { asksToReplace = true }
        else { persist(replacing: false) }
    }
    private func persist(replacing: Bool) {
        do { try onSave(session.draftForPersistence, replacing) }
        catch { session.recordSaveError(error) }
    }
}
