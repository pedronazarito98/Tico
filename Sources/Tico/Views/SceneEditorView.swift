import SwiftUI

/// A cena começa pela intenção. Rascunho, cancelar e salvar continuam locais;
/// capturar consulta o serviço apenas após a escolha explícita da pessoa.
struct SceneEditorView: View {
    let applications: [ApplicationChoice]
    let macOSShortcuts: [String]
    let onSave: (ActionWorkflow) throws -> Void
    let sceneLayouts: SceneLayoutSession?
    private let original: ActionWorkflow
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ActionWorkflow
    @State private var error: String?
    @State private var showsActions: Bool
    @State private var confirmsDiscard = false

    init(workflow: ActionWorkflow, applications: [ApplicationChoice], macOSShortcuts: [String],
         onSave: @escaping (ActionWorkflow) throws -> Void, sceneLayouts: SceneLayoutSession? = nil) {
        self.applications = applications
        self.macOSShortcuts = macOSShortcuts
        self.onSave = onSave
        self.sceneLayouts = sceneLayouts
        original = workflow
        _draft = State(initialValue: workflow)
        _showsActions = State(initialValue: !workflow.steps.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text(original.steps.isEmpty && original.sceneLayout == nil ? "Nova cena" : "Editar cena").font(.title.bold())
                Text("Seu espaço, pronto para o que você quer fazer.").foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if draft.sceneLayout != nil || showsActions {
                        LabeledContent("Nome") {
                            TextField(suggestedName, text: $draft.name).textFieldStyle(.roundedBorder)
                                .accessibilityLabel("Nome da cena").accessibilityIdentifier("tico.scene.name")
                        }
                    }
                    if let sceneLayouts {
                        SceneLayoutConfigurationView(plan: $draft.sceneLayout, session: sceneLayouts, applications: applications)
                    }
                    if showsActions {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("O que preparar").font(.headline)
                            WorkflowEditorView(workflow: $draft, applications: applications,
                                macOSShortcuts: macOSShortcuts, reusableWorkflows: [], onSaveReusable: onSave,
                                showsLibraryControls: false, showsEmptyGuidance: false)
                            if draft.sceneLayout == nil, !layoutApplications.isEmpty {
                                Button("Organizar estes aplicativos", systemImage: "rectangle.3.group") {
                                    draft.sceneLayout = plannedLayout
                                }
                                .help("Planejar posições; as janelas reais serão conferidas antes de aplicar.")
                            }
                        }
                    } else {
                        Button { showsActions = true } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "app.badge").font(.title2)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(draft.sceneLayout == nil ? "Montar uma cena" : "Abrir apps e fazer mais").font(.headline)
                                    Text("Escolha aplicativos, links e outras ações.").foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                            }.padding(18).contentShape(.rect)
                        }.buttonStyle(.plain)
                            .background(TicoBrand.Palette.surface, in: .rect(cornerRadius: 12))
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            if let error {
                ScrollView {
                    Text(error).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }.frame(maxHeight: 60)
            }
            HStack {
                Button("Cancelar", action: cancel).keyboardShortcut(.cancelAction)
                Spacer()
                Button("Salvar cena") {
                    var candidate = draft
                    if candidate.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { candidate.name = suggestedName }
                    do { try onSave(candidate); dismiss() } catch { self.error = error.localizedDescription }
                }.disabled(WorkflowEditorValidation.issue(in: draft) != nil)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction).accessibilityIdentifier("tico.scene.save")
            }
        }
            .padding(20)
            // A sheet limita a área; o mesmo rascunho permanece montado enquanto
            // apenas o conteúdo rola, mantendo Salvar e Cancelar alcançáveis.
            .adaptiveSheetFrame(idealWidth: 850, idealHeight: 720)
            .confirmationDialog("Descartar as alterações da cena?", isPresented: $confirmsDiscard, titleVisibility: .visible) {
                Button("Descartar alterações", role: .destructive) { dismiss() }
                Button("Continuar editando", role: .cancel) { }
            }
    }

    private var suggestedName: String {
        let names = draft.sceneLayout?.windows.map(\.applicationName) ?? draft.enabledSteps.compactMap { step in
            if case let .openApplication(id) = step.action {
                return applications.first { $0.bundleIdentifier == id }?.name
            }
            return nil
        }
        var seen: Set<String> = []
        let uniqueNames = names.filter { seen.insert($0).inserted }
        return uniqueNames.isEmpty ? "Meu espaço" : uniqueNames.prefix(3).joined(separator: " + ")
    }

    private var layoutApplications: [ApplicationChoice] {
        var seen: Set<String> = []
        return draft.enabledSteps.compactMap { step in
            let identifier: String
            switch step.action {
            case let .openApplication(id): identifier = id
            case let .application(.bundleIdentifier(id), .open): identifier = id
            default: return nil
            }
            guard !identifier.isEmpty, seen.insert(identifier).inserted else { return nil }
            return applications.first { $0.bundleIdentifier == identifier }
                ?? ApplicationChoice(bundleIdentifier: identifier, name: identifier, isRunning: false)
        }
    }

    /// Sugestão portátil explícita: não consulta AX e não vincula documentos.
    /// Aplicar a cena continuará exigindo resolver janelas ambíguas na revisão.
    private var plannedLayout: SceneLayoutPlan {
        let apps = layoutApplications
        return SceneLayoutPlan(windows: apps.enumerated().map { index, app in
            let count = Double(min(apps.count, 3))
            let frame = apps.count <= 3
                ? SceneLayoutRect(x: Double(index) / count, y: 0, width: 1 / count, height: 1)
                : .full
            return SceneLayoutWindow(bundleIdentifier: app.bundleIdentifier, applicationName: app.name,
                                     selection: .chooseInPreview, display: .primary, frame: frame)
        })
    }

    private func cancel() {
        if draft != original { confirmsDiscard = true } else { dismiss() }
    }
}
