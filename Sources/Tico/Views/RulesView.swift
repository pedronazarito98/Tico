import SwiftUI

/// Biblioteca com lista e prévia. Rascunhos pertencem à janela e a edição visual
/// abre sob demanda; o editor completo permanece disponível no menu contextual.
struct RulesView: View {
    @ObservedObject var store: ShortcutStore
    @ObservedObject var workspace: RuleWorkspaceSession
    @Binding var selectedRuleID: ShortcutRule.ID?
    let searchText: String
    let applicationFilter: String?
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
    let onStartRecording: () -> Bool
    let onStopRecording: () -> Void
    let onSaveReusableWorkflow: (ActionWorkflow) throws -> Void
    let onSavePreset: (GesturePreset) throws -> Void
    let onPractice: (ShortcutRule) -> Void

    @State private var presentedError: String?
    @State private var rulePendingDeletion: ShortcutRule?
    @State private var inputFilter = RuleInputFilter.all
    @State private var detailedEditorPresented = false

    var body: some View {
        HSplitView {
          VStack(spacing: 0) {
            // O filtro vira menu quando os quatro segmentos não cabem na coluna.
            // ViewThatFits escolhe pelo tamanho real dos controles, sem medir texto.
            ViewThatFits(in: .horizontal) {
                inputTypePicker
                    .pickerStyle(.segmented)
                    .fixedSize(horizontal: true, vertical: false)
                inputTypePicker
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            List(selection: $selectedRuleID) {
                ForEach(visibleRules) { rule in
                    HStack(spacing: 10) {
                        ShortcutActionIcon(action: rule.action, applications: applications, size: 30)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(rule.name).font(.callout.weight(.medium)).lineLimit(1)
                            Text(RuleEditorSummary.trigger(rule.trigger)).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                        Spacer(minLength: 0)
                        if !rule.isEnabled { Image(systemName: "pause.circle").foregroundStyle(.secondary) }
                    }
                    .padding(.vertical, 5).tag(rule.id)
                    .accessibilityIdentifier("tico.rule.row.\(rule.id)")
                    .contextMenu {
                        Button("Editar atalho") { workspace.edit(rule) }
                        Button("Editor completo…") { selectedRuleID = rule.id; detailedEditorPresented = true }
                        Button("Praticar gesto") { onPractice(rule) }
                        Button(rule.isEnabled ? "Desativar" : "Ativar") { setEnabled(rule.id, !rule.isEnabled) }
                        Divider()
                        Button("Excluir atalho…", role: .destructive) { requestDeletion(rule.id) }
                    }
                }
            }.listStyle(.inset).accessibilityIdentifier("tico.rules.list")
                .overlay {
                    if visibleRules.isEmpty {
                        ContentUnavailableView(searchText.isEmpty ? "Nenhum atalho" : "Nenhum resultado",
                            systemImage: "bolt.badge.clock",
                            description: Text("Crie um atalho no botão + ou ajuste os filtros."))
                            .allowsHitTesting(false)
                    }
                }
            Divider()
            HStack {
                Text(listStatus)
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
            }.padding(.horizontal, 16).padding(.vertical, 8)
          }.frame(minWidth: 245, idealWidth: 285, maxWidth: 340)
          Group {
            if let rule = selectedRule {
                ShortcutLibraryDetailView(rule: rule, applications: applications,
                    wasJustCreated: workspace.recentlyCreatedID == rule.id,
                    onSetEnabled: { setEnabled(rule.id, $0) },
                    onEdit: { workspace.edit(rule) }, onPractice: { onPractice(rule) })
                    .id(rule.id)
            } else {
                ContentUnavailableView("Seus atalhos, do seu jeito", systemImage: "hand.draw",
                    description: Text("Crie um atalho para conectar um gesto a uma ação."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
          }.frame(minWidth: 460, maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $detailedEditorPresented) {
            VStack(spacing: 0) {
                HStack { Text("Editor completo").font(.headline); Spacer(); Button("Concluir") { detailedEditorPresented = false } }.padding(16)
                Divider()
                inspector
            }.frame(width: 600, height: 720)
        }
        .onChange(of: selectedRuleID, initial: true) {
            prepareSelectedSession()
            // Uma regra criada por comando deve aparecer mesmo com filtro de outro dispositivo.
            if let rule = selectedRule, !inputFilter.includes(rule.trigger) { inputFilter = .all }
        }
        .onChange(of: store.rules) {
            workspace.synchronize(with: store.rules)
            prepareSelectedSession()
            if selectedRule == nil { selectVisibleRule() }
        }
        .onChange(of: inputFilter) { selectVisibleRule() }
        .onChange(of: applicationFilter) { selectVisibleRule() }
        .onChange(of: searchText) { selectVisibleRule() }
        .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Meus atalhos")
        .alert("Não foi possível salvar", isPresented: errorIsPresented) {
            Button("OK", role: .cancel) { presentedError = nil }
        } message: {
            Text(presentedError ?? "Erro desconhecido")
        }
        .confirmationDialog(
            "Excluir \(rulePendingDeletion?.name ?? "esta regra")?",
            isPresented: deletionIsPresented
        ) {
            Button("Excluir regra", role: .destructive, action: deletePendingRule)
            Button("Cancelar", role: .cancel) { rulePendingDeletion = nil }
        } message: {
            Text("Esta ação não pode ser desfeita.")
        }
    }

    private var inputTypePicker: some View {
        Picker("Tipo de acionamento", selection: $inputFilter) {
            ForEach(RuleInputFilter.allCases) { Text($0.rawValue).tag($0) }
        }
        .labelsHidden()
        .accessibilityIdentifier("tico.rules.input-filter")
    }

    @ViewBuilder
    private var inspector: some View {
        if let rule = selectedRule, let session = workspace.sessions[rule.id] {
            RuleEditorView(
                latestRecordedEvent: latestRecordedEvent,
                recordingIsActive: recordingIsActive,
                trackpadCaptureMode: trackpadCaptureMode,
                trackpadStartupError: trackpadStartupError,
                trackpadSnapshot: trackpadSnapshot,
                applications: applications,
                macOSShortcuts: macOSShortcuts,
                profiles: profiles,
                reusableWorkflows: reusableWorkflows,
                presets: presets,
                detectedTrackpads: detectedTrackpads,
                deviceCapabilities: deviceCapabilities,
                currentContext: currentContext,
                onStartRecording: onStartRecording,
                onStopRecording: onStopRecording,
                onSaveReusableWorkflow: onSaveReusableWorkflow,
                onSavePreset: onSavePreset,
                onPractice: onPractice,
                conflictsForRule: store.conflicts,
                onSave: save,
                onReplaceConflicts: replaceConflicts,
                onDelete: { rulePendingDeletion = rule },
                session: session
            )
            .id(rule.id)
        } else {
            ContentUnavailableView(
                "Selecione um atalho",
                systemImage: "bolt.badge.clock",
                description: Text("Escolha uma linha para editar seus detalhes.")
            )
        }
    }

    private var visibleRules: [ShortcutRule] {
        store.rules.filter { rule in
            let matchesApp = applicationFilter.map { rule.scope.bundleIdentifiers.contains($0) } ?? true
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesSearch = query.isEmpty || [rule.name, RuleEditorSummary.trigger(rule.trigger),
                rule.scope.displayName(applications: applications)].contains { $0.localizedStandardContains(query) }
            return matchesApp && matchesSearch && inputFilter.includes(rule.trigger)
        }
    }

    private var listStatus: String {
        let count = visibleRules.count
        let active = visibleRules.filter(\.isEnabled).count
        return "\(count) \(count == 1 ? "atalho" : "atalhos") · \(active) \(active == 1 ? "ativo" : "ativos")"
    }

    private func prepareSelectedSession() {
        guard let rule = selectedRule else { return }
        _ = workspace.session(for: rule)
    }

    private func selectVisibleRule() {
        if !visibleRules.contains(where: { $0.id == selectedRuleID }) {
            selectedRuleID = visibleRules.first?.id
        }
    }

    private func setEnabled(_ id: UUID, _ enabled: Bool) {
        do { try store.setEnabled(enabled, for: id) }
        catch { presentedError = error.localizedDescription }
    }

    private func requestDeletion(_ id: UUID) {
        rulePendingDeletion = store.rules.first { $0.id == id }
    }

    private var selectedRule: ShortcutRule? {
        guard let selectedRuleID else { return nil }
        return store.rules.first { $0.id == selectedRuleID }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { presentedError != nil },
            set: { if !$0 { presentedError = nil } }
        )
    }

    private var deletionIsPresented: Binding<Bool> {
        Binding(
            get: { rulePendingDeletion != nil },
            set: { if !$0 { rulePendingDeletion = nil } }
        )
    }

    private func save(_ rule: ShortcutRule) throws {
        try store.update(rule)
        detailedEditorPresented = false
    }

    private func replaceConflicts(_ rule: ShortcutRule) throws {
        try store.replaceConflictingRules(with: rule)
    }

    private func deletePendingRule() {
        guard let rulePendingDeletion else { return }
        do {
            try store.delete(id: rulePendingDeletion.id)
            if selectedRuleID == rulePendingDeletion.id {
                selectedRuleID = store.rules.first?.id
            }
            self.rulePendingDeletion = nil
        } catch {
            presentedError = error.localizedDescription
        }
    }
}
