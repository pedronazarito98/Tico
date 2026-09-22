import SwiftUI

/// Cenas são workflows reutilizáveis, com a mesma identidade e persistência existentes.
struct ScenesView: View {
    let workflows: [ActionWorkflow]
    let applications: [ApplicationChoice]
    let macOSShortcuts: [String]
    let runningIDs: Set<UUID>
    let lastReport: WorkflowExecutionReport?
    let onSave: (ActionWorkflow) throws -> Void
    let onDelete: (UUID) throws -> Void
    let onRun: (ActionWorkflow) -> Void
    let onCancel: (UUID) -> Void
    let onCreateRule: (ActionWorkflow) -> Void
    @State private var editing: ActionWorkflow?
    @State private var pendingDeletion: ActionWorkflow?
    @State private var pendingRun: ActionWorkflow?
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Prepare seu espaço").font(.largeTitle.bold())
                        Text("Reúna apps, links e janelas numa sequência que você controla.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Nova cena", systemImage: "plus") {
                        editing = ActionWorkflow(name: "Minha cena", steps: [
                            WorkflowStep(action: .openApplication(bundleIdentifier: "com.apple.Safari"))
                        ])
                    }.accessibilityIdentifier("tico.scenes.new")
                }
                if workflows.isEmpty {
                    ContentUnavailableView("Como você começa a trabalhar?", systemImage: "rectangle.3.group",
                        description: Text("Crie uma cena com os aplicativos e a disposição de janelas que você usa."))
                }
                ForEach(workflows) { workflow in
                    GroupBox {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text(workflow.name.isEmpty ? "Cena sem nome" : workflow.name).font(.title3.bold())
                                Spacer()
                                Button("Editar") { editing = workflow }
                                Button("Excluir", role: .destructive) { pendingDeletion = workflow }
                            }
                            ForEach(Array(workflow.enabledSteps.enumerated()), id: \.element.id) { index, step in
                                Label("\(index + 1). \(step.displayName)", systemImage: "checklist")
                                    .font(.callout)
                            }
                            HStack {
                                Button("Usar em um atalho") { onCreateRule(workflow) }
                                Spacer()
                                if runningIDs.contains(workflow.id) {
                                    ProgressView().controlSize(.small)
                                    Button("Cancelar execução") { onCancel(workflow.id) }
                                } else {
                                    Button("Preparar cena", systemImage: "play.fill") { pendingRun = workflow }
                                        .buttonStyle(.borderedProminent)
                                        .disabled(!workflow.isValid)
                                }
                            }
                            if let lastReport, lastReport.workflowID == workflow.id {
                                WorkflowReportView(report: lastReport)
                            }
                        }.padding(10)
                    }
                }
                if let error { Text(error).foregroundStyle(.red) }
            }.padding(28)
        }.navigationTitle("Cenas")
            .sheet(item: $editing) { workflow in
                SceneEditorView(workflow: workflow, applications: applications,
                    macOSShortcuts: macOSShortcuts, onSave: onSave)
            }
            .confirmationDialog("Excluir esta cena?", isPresented: deletionPresented, titleVisibility: .visible) {
                Button("Excluir da biblioteca", role: .destructive) {
                    guard let pendingDeletion else { return }
                    do { try onDelete(pendingDeletion.id) } catch { self.error = error.localizedDescription }
                    self.pendingDeletion = nil
                }
            } message: { Text("Atalhos que já usam uma cópia desta cena serão preservados.") }
            .confirmationDialog("Preparar \(pendingRun?.name ?? "cena")?", isPresented: runPresented, titleVisibility: .visible) {
                Button("Executar as etapas") {
                    guard let pendingRun else { return }
                    onRun(pendingRun)
                    self.pendingRun = nil
                }
            } message: { Text("Os aplicativos, links e janelas listados serão alterados. Scripts ainda exigem a aprovação habitual.") }
    }

    private var deletionPresented: Binding<Bool> {
        Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })
    }
    private var runPresented: Binding<Bool> {
        Binding(get: { pendingRun != nil }, set: { if !$0 { pendingRun = nil } })
    }
}
