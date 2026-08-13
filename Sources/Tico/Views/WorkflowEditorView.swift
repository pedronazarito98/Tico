import SwiftUI

struct WorkflowEditorView: View {
    @Binding var workflow: ActionWorkflow
    let applications: [ApplicationChoice]
    let macOSShortcuts: [String]
    let reusableWorkflows: [ActionWorkflow]
    let onSaveReusable: (ActionWorkflow) throws -> Void

    @State private var selectedStepID: UUID?
    @State private var saveError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Picker("Workflow reutilizável", selection: reusableSelection) {
                    Text("Personalizado nesta regra").tag(UUID?.none)
                    ForEach(reusableWorkflows) { reusable in
                        Text(reusable.name.isEmpty ? "Workflow sem nome" : reusable.name)
                            .tag(Optional(reusable.id))
                    }
                }

                Button("Salvar na biblioteca") {
                    saveReusable()
                }
                .disabled(!workflow.isValid)
            }

            HStack {
                Picker("Em caso de erro", selection: $workflow.failurePolicy) {
                    ForEach(WorkflowFailurePolicy.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
                Stepper(
                    "Timeout: \(workflow.timeout.safeWholeSeconds(default: 60, range: 1...600)) s",
                    value: $workflow.timeout,
                    in: 1...600,
                    step: 5
                )
            }

            HSplitView {
                VStack(spacing: 8) {
                    List(selection: $selectedStepID) {
                        ForEach(Array(workflow.steps.enumerated()), id: \.element.id) { index, step in
                            HStack(spacing: 8) {
                                Text("\(index + 1)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 18)
                                Image(systemName: step.isEnabled ? "bolt.fill" : "bolt.slash")
                                    .foregroundStyle(step.isEnabled ? .blue : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(step.displayName)
                                        .lineLimit(1)
                                    if step.delayBefore > 0 {
                                        Text("Aguardar \(step.delayBefore, format: .number) s")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .tag(step.id)
                        }
                    }
                    .frame(minHeight: 170)

                    HStack {
                        Button {
                            addStep()
                        } label: {
                            Label("Etapa", systemImage: "plus")
                        }
                        .disabled(workflow.steps.count >= 20)
                        Button {
                            deleteSelectedStep()
                        } label: {
                            Image(systemName: "minus")
                        }
                        .disabled(selectedStep == nil || workflow.steps.count <= 1)
                        Spacer()
                        Button {
                            moveSelectedStep(offset: -1)
                        } label: {
                            Image(systemName: "chevron.up")
                        }
                        .disabled(!canMoveSelectedStep(offset: -1))
                        Button {
                            moveSelectedStep(offset: 1)
                        } label: {
                            Image(systemName: "chevron.down")
                        }
                        .disabled(!canMoveSelectedStep(offset: 1))
                    }
                }
                .frame(minWidth: 220, idealWidth: 250)

                if let selectedStepBinding {
                    WorkflowStepEditor(
                        step: selectedStepBinding,
                        applications: applications,
                        macOSShortcuts: macOSShortcuts
                    )
                    .padding(.leading, 12)
                    .frame(minWidth: 350)
                } else {
                    ContentUnavailableView(
                        "Selecione uma etapa",
                        systemImage: "point.topleft.down.to.point.bottomright.curvepath"
                    )
                    .frame(minWidth: 350)
                }
            }
            .frame(minHeight: 280)
        }
        .onAppear {
            selectedStepID = selectedStepID ?? workflow.steps.first?.id
        }
        .alert("Não foi possível salvar o workflow", isPresented: errorPresented) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "Erro desconhecido")
        }
    }

    private var selectedStep: WorkflowStep? {
        guard let selectedStepID else { return nil }
        return workflow.steps.first { $0.id == selectedStepID }
    }

    private var selectedStepBinding: Binding<WorkflowStep>? {
        guard let selectedStepID,
              let index = workflow.steps.firstIndex(where: { $0.id == selectedStepID }) else {
            return nil
        }
        return $workflow.steps[index]
    }

    private var reusableSelection: Binding<UUID?> {
        Binding(
            get: {
                reusableWorkflows.first(where: {
                    $0.steps == workflow.steps
                        && $0.failurePolicy == workflow.failurePolicy
                        && $0.timeout == workflow.timeout
                })?.id
            },
            set: { id in
                guard let id,
                      let reusable = reusableWorkflows.first(where: { $0.id == id }) else {
                    return
                }
                workflow = ActionWorkflow(
                    name: reusable.name,
                    steps: reusable.steps.map {
                        WorkflowStep(
                            name: $0.name,
                            action: $0.action,
                            delayBefore: $0.delayBefore,
                            timeout: $0.timeout,
                            isEnabled: $0.isEnabled
                        )
                    },
                    failurePolicy: reusable.failurePolicy,
                    timeout: reusable.timeout
                )
                selectedStepID = workflow.steps.first?.id
            }
        )
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )
    }

    private func addStep() {
        let step = WorkflowStep(
            action: .notification(title: TicoBrand.displayName, body: "Etapa executada")
        )
        workflow.steps.append(step)
        selectedStepID = step.id
    }

    private func deleteSelectedStep() {
        guard let selectedStepID,
              workflow.steps.count > 1,
              let index = workflow.steps.firstIndex(where: { $0.id == selectedStepID }) else {
            return
        }
        workflow.steps.remove(at: index)
        self.selectedStepID = workflow.steps.indices.contains(index)
            ? workflow.steps[index].id
            : workflow.steps.last?.id
    }

    private func canMoveSelectedStep(offset: Int) -> Bool {
        guard let selectedStepID,
              let index = workflow.steps.firstIndex(where: { $0.id == selectedStepID }) else {
            return false
        }
        return workflow.steps.indices.contains(index + offset)
    }

    private func moveSelectedStep(offset: Int) {
        guard let selectedStepID,
              let index = workflow.steps.firstIndex(where: { $0.id == selectedStepID }),
              workflow.steps.indices.contains(index + offset) else {
            return
        }
        workflow.steps.swapAt(index, index + offset)
    }

    private func saveReusable() {
        var reusable = workflow
        if reusable.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            reusable.name = "Workflow \(reusableWorkflows.count + 1)"
        }
        do {
            try onSaveReusable(reusable)
            workflow.name = reusable.name
        } catch {
            saveError = error.localizedDescription
        }
    }
}

private struct WorkflowStepEditor: View {
    @Binding var step: WorkflowStep
    let applications: [ApplicationChoice]
    let macOSShortcuts: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Nome opcional da etapa", text: $step.name)
                Toggle("Ativa", isOn: $step.isEnabled)
                    .toggleStyle(.switch)
            }

            HStack {
                Stepper(
                    "Atraso: \(step.delayBefore, format: .number.precision(.fractionLength(1))) s",
                    value: $step.delayBefore,
                    in: 0...300,
                    step: 0.5
                )
                Toggle("Timeout próprio", isOn: timeoutEnabled)
                if step.timeout != nil {
                    Stepper(
                        "\((step.timeout ?? 15).safeWholeSeconds(default: 15, range: 1...300)) s",
                        value: timeoutValue,
                        in: 1...300
                    )
                }
            }
            .font(.caption)

            Divider()

            RuleActionEditorView(
                action: $step.action,
                urlText: urlText,
                applications: applications,
                macOSShortcuts: macOSShortcuts
            )
        }
    }

    private var timeoutEnabled: Binding<Bool> {
        Binding(
            get: { step.timeout != nil },
            set: { step.timeout = $0 ? (step.timeout ?? 15) : nil }
        )
    }

    private var timeoutValue: Binding<Double> {
        Binding(
            get: { step.timeout ?? 15 },
            set: { step.timeout = $0 }
        )
    }

    private var urlText: Binding<String> {
        Binding(
            get: {
                if case let .openURL(url) = step.action {
                    return url.absoluteString
                }
                return "https://"
            },
            set: { value in
                guard case .openURL = step.action, let url = URL(string: value) else { return }
                step.action = .openURL(url: url)
            }
        )
    }
}

private extension Double {
    func safeWholeSeconds(default fallback: Double, range: ClosedRange<Double>) -> Int {
        let value = isFinite ? min(max(self, range.lowerBound), range.upperBound) : fallback
        return Int(value)
    }
}
