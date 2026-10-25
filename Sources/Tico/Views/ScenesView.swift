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
    var sceneLayouts: SceneLayoutSession? = nil
    var routineSection: DisplayRoutineSectionView? = nil
    var searchText = ""
    var newSceneRequest: UUID? = nil
    var onConfigureRoutine: ((ActionWorkflow) -> Void)? = nil
    var hasPendingRecovery = false
    @State private var editing: ActionWorkflow?
    @State private var pendingDeletion: ActionWorkflow?
    @State private var pendingRun: ActionWorkflow?
    @State private var error: String?

    var body: some View {
        GeometryReader { geometry in
            let inset: CGFloat = geometry.size.width < 600 ? 16 : 32
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Prepare seu espaço").font(.largeTitle.bold()).fixedSize(horizontal: false, vertical: true)
                            Text("Reúna apps, links e janelas numa sequência que você controla.")
                                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    if let sceneLayouts { SceneLayoutRecoveryView(session: sceneLayouts, workflows: workflows) }
                    if workflows.isEmpty {
                        ContentUnavailableView {
                            Label("Seu espaço, do seu jeito", systemImage: "rectangle.3.group")
                        } description: {
                            Text("Guarde as janelas desta tela ou monte uma cena com seus aplicativos.")
                        } actions: {
                            Button("Criar minha primeira cena", action: createScene).buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("tico.scenes.new")
                        }
                        .frame(maxWidth: .infinity, minHeight: 280, maxHeight: .infinity)
                    } else {
                        LazyVGrid(columns: sceneColumns(availableWidth: geometry.size.width - inset * 2),
                                  alignment: .leading, spacing: 16) {
                            ForEach(filteredWorkflows) { workflow in
                                SceneCardView(workflow: workflow, applications: applications,
                                    isRunning: runningIDs.contains(workflow.id),
                                    hasPendingRecovery: workflow.sceneLayout != nil && hasPendingRecovery,
                                    report: lastReport?.workflowID == workflow.id ? lastReport : nil,
                                    onEdit: { editing = workflow }, onDelete: { pendingDeletion = workflow },
                                    onRun: { pendingRun = workflow }, onCancel: { onCancel(workflow.id) },
                                    onCreateRule: { onCreateRule(workflow) },
                                    onConfigureRoutine: onConfigureRoutine.map { configure in { configure(workflow) } })
                            }
                        }
                        if filteredWorkflows.isEmpty {
                            ContentUnavailableView.search(text: searchText)
                                .frame(maxWidth: .infinity, minHeight: 280, maxHeight: .infinity)
                        }
                        if let routineSection { routineSection }
                    }
                    if let error { Text(error).foregroundStyle(.red) }
                }
                .frame(maxWidth: 1_080, minHeight: max(0, geometry.size.height - inset * 2), alignment: .topLeading)
                .frame(maxWidth: .infinity)
                .padding(inset)
            }
        }.navigationTitle("Cenas")
            .onChange(of: newSceneRequest) { if newSceneRequest != nil { createScene() } }
            .sheet(item: $editing) { workflow in
                SceneEditorView(workflow: workflow, applications: applications,
                    macOSShortcuts: macOSShortcuts, onSave: onSave, sceneLayouts: sceneLayouts)
            }
            .confirmationDialog("Excluir esta cena?", isPresented: deletionPresented, titleVisibility: .visible) {
                Button("Excluir da biblioteca", role: .destructive) {
                    guard let pendingDeletion else { return }
                    do { try onDelete(pendingDeletion.id) } catch { self.error = error.localizedDescription }
                    self.pendingDeletion = nil
                }
            } message: { Text("Atalhos que já usam uma cópia desta cena serão preservados.") }
            .confirmationDialog("Preparar \(pendingRun?.name ?? "cena")?", isPresented: runPresented, titleVisibility: .visible) {
                Button(pendingRun?.sceneLayout == nil ? "Executar as etapas" : "Iniciar e revisar layout") {
                    guard let pendingRun else { return }
                    onRun(pendingRun)
                    self.pendingRun = nil
                }
            } message: {
                Text(pendingRun?.sceneLayout == nil
                     ? "Os aplicativos, links e janelas listados serão alterados. Scripts ainda exigem a aprovação habitual."
                     : "As ações configuradas serão executadas primeiro. Depois você revisará as janelas disponíveis e confirmará apenas o layout. Cancelar nessa revisão preserva as ações já executadas.")
            }
    }

    /// A largura disponível pertence à área de conteúdo, já sem a sidebar.
    /// O estado vazio ocupa essa área; coleções ganham duas colunas apenas quando
    /// cada cartão continua legível. A rolagem mantém tudo acessível em pouca altura.
    /// Paralelo com React: um container fluido com max-width e uma grade adaptável.
    private func sceneColumns(availableWidth: CGFloat) -> [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16, alignment: .top),
              count: availableWidth >= 820 ? 2 : 1)
    }

    private var filteredWorkflows: [ActionWorkflow] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return workflows.filter { query.isEmpty || $0.name.localizedStandardContains(query)
            || $0.enabledSteps.contains { RuleEditorSummary.action($0.action, applications: applications).localizedStandardContains(query) } }
    }

    private func createScene() {
        editing = ActionWorkflow(name: "", steps: [])
    }

    private var deletionPresented: Binding<Bool> {
        Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })
    }
    private var runPresented: Binding<Bool> {
        Binding(get: { pendingRun != nil }, set: { if !$0 { pendingRun = nil } })
    }
}
