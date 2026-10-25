import SwiftUI

/// Fluxo guiado com um único rascunho persistível e um candidato de captura.
/// O controller possui os monitores; esta view conserva apenas seu token de prática.
/// Paralelo com React: filhos controlados recebem Binding e callbacks, sem IO no body.
struct ShortcutComposerView: View {
    @ObservedObject var session: RuleEditingSession
    @ObservedObject var practiceSession: GesturePracticeSession
    @ObservedObject var localInput: LocalInputCaptureService
    let applications: [ApplicationChoice]
    let macOSShortcuts: [String]

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
    let canCaptureGlobalInput: Bool
    let onOpenPermissions: () -> Void
    let onStartLocalRecording: () -> Bool
    let onStartRecording: () -> Bool
    let onStopRecording: () -> Void
    let onStartPreview: (ShortcutRule) -> UUID?
    let onStopPreview: (UUID) -> Void
    let onSaveReusableWorkflow: (ActionWorkflow) throws -> Void
    let onSavePreset: (GesturePreset) throws -> Void
    let conflictsForRule: (ShortcutRule) -> [RuleConflict]
    let onSave: (ShortcutRule, Bool) throws -> Void
    let onCancel: () -> Void

    @StateObject private var capture = TriggerCaptureSession(trigger: nil)
    @State private var step = Step.action
    @State private var presentedSheet: Sheet?
    @State private var previewID: UUID?
    @State private var ownsRecording = false
    @State private var captureError: String?
    @State private var asksToReplace = false
    @State private var asksToDiscard = false
    @State private var initialized = false
    @State private var actionSearch = ""
    @State private var actionSelectionRevision = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Step: Int, CaseIterable { case action, trigger, review
        var title: String { switch self { case .action: "Resultado"; case .trigger: "Como ativar"; case .review: "Conferir" } }
    }
    private enum Sheet: String, Identifiable { case actions, options, trigger; var id: Self { self } }
    private var actionIssue: String? { WorkflowEditorValidation.issue(in: session.draft.workflow) }
    private var canSave: Bool { session.composerValidationMessage == nil }
    private var conflicts: [RuleConflict] { canSave ? conflictsForRule(session.draft) : [] }

    var body: some View {
      GeometryReader { geometry in
        let contentWidth = max(0, geometry.size.width - 40)
        VStack(spacing: 0) {
            header
            Divider()
            stepper.padding(.vertical, 12)
            ScrollViewReader { scroll in
              ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if step == .trigger { actionSummary }
                    switch step {
                    case .action:
                        ComposerActionStep(session: session, applications: applications,
                            macOSShortcuts: macOSShortcuts, reusableWorkflows: reusableWorkflows,
                            search: $actionSearch, onChoose: chooseAction,
                            onMoreActions: { presentedSheet = .actions },
                            onSaveReusableWorkflow: onSaveReusableWorkflow, availableWidth: contentWidth)
                    case .trigger:
                        TriggerCaptureEditor(capture: capture, localInput: localInput, snapshot: snapshot,
                            captureMode: captureMode, isRecording: ownsRecording && recordingIsActive,
                            canCaptureGlobalInput: canCaptureGlobalInput, onRecord: beginRecording,
                            onStop: stopRecording, onOpenPermissions: onOpenPermissions,
                            onAdvanced: { presentedSheet = .trigger }, availableWidth: contentWidth)
                    case .review:
                        ComposerReviewStep(session: session, practice: practiceSession, applications: applications,
                            conflicts: conflicts, isPracticing: previewID != nil,
                            canCaptureGlobalInput: canCaptureGlobalInput, onOpenPermissions: onOpenPermissions,
                            onEditTrigger: { navigate(.trigger) }, onEditAction: { navigate(.action) },
                            onOptions: { presentedSheet = .options }, availableWidth: contentWidth)
                    }
                }.padding(.horizontal, 20).padding(.vertical, 14).frame(maxWidth: .infinity)
                    .id("composer-content-top")
              }
              .onChange(of: step) { scroll.scrollTo("composer-content-top", anchor: .top) }
              .onChange(of: capture.mode) { scroll.scrollTo("composer-content-top", anchor: .top) }
              .onChange(of: capture.device) { scroll.scrollTo("composer-content-top", anchor: .top) }
              .onChange(of: actionSelectionRevision) {
                  if contentWidth < 720 { scroll.scrollTo("composer-action-parameters", anchor: .top) }
              }
              .onChange(of: contentWidth < 720) { _, compact in
                  // Ao empilhar, mantém a configuração em edição visível. O
                  // campo conserva foco e valor; só a posição da rolagem muda.
                  if compact, step == .action, session.hasChosenAction {
                      scroll.scrollTo("composer-action-parameters", anchor: .top)
                  }
              }
            }
            Divider()
            footer(availableWidth: geometry.size.width)
        }
      }
        .adaptiveSheetFrame(idealWidth: 980, idealHeight: 740)
        .background(TicoBrand.Palette.background).tint(TicoBrand.Palette.primary)
        .sheet(item: $presentedSheet) { sheetContent($0) }
        .onAppear {
            guard !initialized else { return }; initialized = true
            if session.hasChosenTrigger { capture.load(session.draft.trigger) }
            if !session.isNew { step = .review }
        }
        .onChange(of: latestEvent) {
            guard ownsRecording, recordingIsActive, let latestEvent else { return }
            capture.receive(latestEvent)
        }
        .onChange(of: localInput.issue) {
            if ownsRecording, let issue = localInput.issue { capture.issue = issue }
        }
        .onChange(of: recordingIsActive) {
            if !recordingIsActive { ownsRecording = false; previewID = nil }
        }
        .onChange(of: session.draft.workflow) { stopPreview() }
        .onDisappear { stopRecording(); stopPreview() }
        .alert("Não foi possível concluir", isPresented: Binding(
            get: { session.saveError != nil || captureError != nil },
            set: { if !$0 { session.clearSaveError(); captureError = nil } }
        )) {
            Button("OK", role: .cancel) { session.clearSaveError(); captureError = nil }
        } message: { Text(session.saveError ?? captureError ?? "") }
        .confirmationDialog("Este gatilho já está em uso", isPresented: $asksToReplace, titleVisibility: .visible) {
            Button("Alterar acionamento") { navigate(.trigger) }
            Button("Revisar aplicativos") { presentedSheet = .options }
            Button("Substituir atalho existente", role: .destructive) { persist(replacing: true) }
            Button("Voltar", role: .cancel) { }
        } message: { Text(conflicts.map(\.message).joined(separator: "\n")) }
        .confirmationDialog("Descartar as alterações deste atalho?", isPresented: $asksToDiscard, titleVisibility: .visible) {
            Button("Descartar alterações", role: .destructive) { session.revert(); onCancel() }
            Button("Continuar editando", role: .cancel) { }
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 9) { TicoMarkView().frame(width: 25, height: 25); Text("Tico").font(.title3.bold()) }
            Spacer()
            Text(session.isNew ? "Novo atalho" : "Editar atalho").font(.headline)
            Spacer()
            Menu {
                if !session.isNew { Button("Reverter alterações") { stopRecording(); stopPreview(); session.revert(); capture.load(session.draft.trigger) } }
                Button("Salvar como modelo") {
                    do { try onSavePreset(session.makePreset()) } catch { session.recordSaveError(error) }
                }.disabled(!canSave)
                ForEach(presets) { preset in
                    Button("Usar modelo: \(preset.name)") {
                        stopRecording(); stopPreview(); session.applyPreset(preset)
                        capture.load(preset.trigger)
                        step = .review
                    }
                }
            } label: { Image(systemName: "ellipsis.circle") }
                .menuStyle(.borderlessButton).fixedSize()
                .accessibilityLabel("Mais opções do atalho").help("Modelos e opções do atalho")
        }.padding(.horizontal, 20).padding(.vertical, 11)
    }
    private var stepper: some View {
        HStack(spacing: 12) {
            ForEach(Step.allCases, id: \.rawValue) { item in
                if item != .action { Rectangle().fill(item.rawValue <= step.rawValue ? TicoBrand.Palette.primary : .secondary.opacity(0.2)).frame(minWidth: 12, maxWidth: 80).frame(height: 1) }
                Button { navigate(item) } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.rawValue < step.rawValue ? "checkmark.circle.fill" : item == step ? "circle.inset.filled" : "circle")
                            .font(.system(size: 17))
                        Text(item.title).font(.caption.weight(item == step ? .semibold : .regular))
                    }.foregroundStyle(item.rawValue <= step.rawValue ? TicoBrand.Palette.primary : Color.secondary)
                }.buttonStyle(.plain)
                    .disabled(item == .trigger && (!session.hasChosenAction || actionIssue != nil) || item == .review && !canSave)
                    .accessibilityLabel("Etapa \(item.rawValue + 1): \(item.title)")
                    .accessibilityAddTraits(item == step ? [.isSelected] : [])
            }
        }.padding(.horizontal, 20)
    }
    private var actionSummary: some View {
        HStack(spacing: 12) {
            if session.draft.workflow.steps.isEmpty, let layout = session.draft.workflow.sceneLayout {
                Label("Organizar \(layout.windows.count) janelas", systemImage: "rectangle.3.group")
                    .font(.callout.weight(.medium))
            } else {
                ShortcutActionIcon(action: session.draft.action, applications: applications, size: 28)
                Text(RuleEditorSummary.action(session.draft.action, applications: applications))
                    .font(.callout.weight(.medium)).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button("Alterar ação") { navigate(.action) }.buttonStyle(.borderless).fixedSize()
        }.padding(12).background(TicoBrand.Palette.surface.opacity(0.6), in: .rect(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.1)) }
    }
    /// AnyLayout reorganiza os mesmos controles, sem substituir sua identidade.
    /// Paralelo com React: muda a direção do flex, mantendo os mesmos filhos.
    private func footer(availableWidth: CGFloat) -> some View {
        let compact = availableWidth < 760
        return (compact ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                        : AnyLayout(HStackLayout(spacing: 12))) {
          HStack(spacing: 12) {
            Button("Cancelar", action: cancel).keyboardShortcut(.cancelAction)
            if step != .action { Button("Voltar") { navigate(step == .review ? .trigger : .action) } }
          }.frame(maxWidth: .infinity, alignment: .leading)
          HStack(spacing: 12) {
            if step == .review {
                Button(previewID == nil ? "Testar acionamento" : "Encerrar teste", systemImage: previewID == nil ? "play.fill" : "stop.fill", action: togglePreview)
                    .disabled(!canSave).accessibilityIdentifier("tico.composer.preview")
                Button(session.isNew ? "Criar atalho" : "Salvar alterações", action: save)
                    .buttonStyle(.borderedProminent).disabled(!canSave).accessibilityIdentifier("tico.composer.save")
            } else {
                Button(step == .action ? "Escolher acionamento" : "Usar acionamento") {
                    if step == .action { navigate(.trigger) }
                    else if let trigger = capture.result { stopRecording(); session.chooseTrigger(trigger); navigate(.review) }
                }.buttonStyle(.borderedProminent)
                    .disabled(step == .action ? (!session.hasChosenAction || actionIssue != nil) : capture.result == nil || capture.issue != nil || (ownsRecording && localInput.issue != nil))
                    .accessibilityIdentifier("tico.composer.continue")
            }
          }.frame(maxWidth: .infinity, alignment: .trailing)
        }.controlSize(.large).padding(.horizontal, 20).padding(.vertical, compact ? 10 : 14)
    }
    @ViewBuilder private func sheetContent(_ sheet: Sheet) -> some View {
        switch sheet {
        case .actions:
            RuleActionPickerView(applications: applications, initialSearch: actionSearch) {
                chooseAction($0, RuleEditorSummary.action($0, applications: applications))
            }
        case .options:
            ShortcutOptionsView(session: session, applications: applications, displays: displays,
                onClose: { presentedSheet = nil })
        case .trigger:
            ShortcutTriggerPicker(trigger: capture.result ?? capture.input ?? session.draft.trigger, captureMode: captureMode,
                detectedTrackpads: detectedTrackpads, deviceCapabilities: deviceCapabilities, onChoose: capture.load)
        }
    }
    private func chooseAction(_ action: ShortcutAction, _ title: String) {
        stopPreview()
        session.chooseAction(action, title: title)
        actionSelectionRevision += 1
    }
    private func navigate(_ next: Step) {
        stopRecording(); stopPreview()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { step = next }
    }
    private func beginRecording() {
        stopPreview(); capture.beginCapture()
        let started = capture.requiresTrackpad ? onStartRecording() : onStartLocalRecording()
        if started { ownsRecording = true }
        else { captureError = startupError ?? "Não foi possível gravar. Verifique as permissões ou encerre outra sessão de captura." }
    }
    private func stopRecording() {
        guard ownsRecording else { return }
        if let issue = localInput.issue { capture.issue = issue }
        onStopRecording(); ownsRecording = false
    }
    private func togglePreview() {
        if previewID != nil { stopPreview(); return }
        guard canSave else { return }
        stopRecording(); previewID = onStartPreview(session.draft)
        if previewID == nil { captureError = "A captura não está disponível. Verifique as permissões e tente novamente." }
    }
    private func stopPreview() { if let id = previewID { onStopPreview(id); previewID = nil } }
    private func cancel() {
        if ownsRecording { stopRecording(); return }
        if previewID != nil { stopPreview(); return }
        let candidateChanged = capture.result.map { !session.hasChosenTrigger || $0 != session.draft.trigger }
            ?? (capture.mode == .custom && !capture.samples.isEmpty)
        if session.hasUnsavedChanges || candidateChanged { asksToDiscard = true } else { onCancel() }
    }
    private func save() {
        guard canSave else { return }; stopPreview()
        if conflicts.contains(where: { $0.severity == .replacementRequired }) { asksToReplace = true }
        else { persist(replacing: false) }
    }
    private func persist(replacing: Bool) {
        do { try onSave(session.draftForPersistence, replacing) } catch { session.recordSaveError(error) }
    }
}
