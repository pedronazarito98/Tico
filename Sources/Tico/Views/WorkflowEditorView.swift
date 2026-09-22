import SwiftUI

/// Editor sequencial compartilhado por regras e cenas. Identidade das ações é o UUID;
/// expandir, recolher e reordenar não recria os dados nem executa o workflow.
struct WorkflowEditorView: View {
    @Binding var workflow: ActionWorkflow
    let applications: [ApplicationChoice]
    let macOSShortcuts: [String]
    let reusableWorkflows: [ActionWorkflow]
    let onSaveReusable: (ActionWorkflow) throws -> Void
    var showsLibraryControls = true

    @State private var selectedStepID: UUID?
    @State private var showsActionPicker = false
    @State private var saveError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach($workflow.steps) { $step in
                let index = workflow.steps.firstIndex { $0.id == step.id } ?? 0
                WorkflowStepCard(step: $step, position: index + 1,
                    isExpanded: selectedStepID == step.id,
                    showsHeader: workflow.steps.count > 1,
                    canDelete: workflow.steps.count > 1, canMoveUp: index > 0,
                    canMoveDown: index < workflow.steps.count - 1,
                    applications: applications, macOSShortcuts: macOSShortcuts,
                    onToggle: { selectedStepID = selectedStepID == step.id ? nil : step.id },
                    onDelete: { deleteStep(step.id) }, onMove: { moveStep(step.id, offset: $0) })
            }
            HStack {
                Button("Adicionar ação", systemImage: "plus") { showsActionPicker = true }
                    .disabled(workflow.steps.count >= 20)
                    .accessibilityIdentifier("tico.workflow.add-action")
                Spacer()
                if showsLibraryControls {
                    Menu {
                        if !reusableWorkflows.isEmpty {
                            Section("Usar sequência salva") {
                                ForEach(reusableWorkflows) { reusable in
                                    Button(reusable.name.isEmpty ? "Sequência sem nome" : reusable.name) { use(reusable) }
                                }
                            }
                        }
                        Button("Salvar sequência na biblioteca", action: saveReusable)
                            .disabled(WorkflowEditorValidation.issue(in: workflow) != nil)
                    } label: { Label("Biblioteca", systemImage: "books.vertical") }
                        .menuStyle(.borderlessButton).fixedSize()
                }
            }.buttonStyle(.borderless).padding(.vertical, 4)

            DisclosureGroup("Opções da sequência") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Se uma ação falhar", selection: $workflow.failurePolicy) {
                        ForEach(WorkflowFailurePolicy.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }.pickerStyle(.radioGroup)
                    Stepper("Tempo limite total: \(workflow.timeout, format: .number) s", value: $workflow.timeout, in: 1...600, step: 5)
                }.padding(.top, 10)
            }.font(.callout)
            if workflow.enabledSteps.isEmpty {
                Label("Mantenha pelo menos uma ação ativa.", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.orange)
            }
        }
        .onChange(of: workflow.steps.map(\.id), initial: true) {
            if selectedStepID == nil || !workflow.steps.contains(where: { $0.id == selectedStepID }) {
                selectedStepID = workflow.steps.first?.id
            }
        }
        .sheet(isPresented: $showsActionPicker) {
            RuleActionPickerView(applications: applications) { action in
                guard workflow.steps.count < 20 else { return }
                let step = WorkflowStep(action: action)
                workflow.steps.append(step)
                selectedStepID = step.id
            }
        }
        .alert("Não foi possível salvar a sequência", isPresented: errorPresented) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "Erro desconhecido") }
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
    }

    private func use(_ reusable: ActionWorkflow) {
        workflow = ActionWorkflow(name: reusable.name, steps: reusable.steps.map {
            WorkflowStep(name: $0.name, action: $0.action, delayBefore: $0.delayBefore,
                         timeout: $0.timeout, isEnabled: $0.isEnabled)
        }, failurePolicy: reusable.failurePolicy, timeout: reusable.timeout)
        selectedStepID = workflow.steps.first?.id
    }

    private func deleteStep(_ id: UUID) {
        guard workflow.steps.count > 1, let index = workflow.steps.firstIndex(where: { $0.id == id }) else { return }
        workflow.steps.remove(at: index)
        if selectedStepID == id { selectedStepID = workflow.steps[min(index, workflow.steps.count - 1)].id }
    }

    private func moveStep(_ id: UUID, offset: Int) {
        guard let index = workflow.steps.firstIndex(where: { $0.id == id }), workflow.steps.indices.contains(index + offset) else { return }
        workflow.steps.swapAt(index, index + offset)
    }

    private func saveReusable() {
        var reusable = workflow
        if reusable.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            reusable.name = "Sequência \(reusableWorkflows.count + 1)"
        }
        do {
            try onSaveReusable(reusable)
            workflow.name = reusable.name
        } catch { saveError = error.localizedDescription }
    }
}
