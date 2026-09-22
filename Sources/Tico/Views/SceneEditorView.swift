import SwiftUI

struct SceneEditorView: View {
    let applications: [ApplicationChoice]
    let macOSShortcuts: [String]
    let onSave: (ActionWorkflow) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ActionWorkflow
    @State private var error: String?

    init(workflow: ActionWorkflow, applications: [ApplicationChoice], macOSShortcuts: [String],
         onSave: @escaping (ActionWorkflow) throws -> Void) {
        self.applications = applications
        self.macOSShortcuts = macOSShortcuts
        self.onSave = onSave
        _draft = State(initialValue: workflow)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Editar cena").font(.title.bold())
            TextField("Nome da cena", text: $draft.name).textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("tico.scene.name")
            Text("Escolha o aplicativo de cada ação de janela. Após abrir um app, adicione um pequeno atraso à próxima etapa para ele ficar pronto.")
                .foregroundStyle(.secondary)
            ScrollView {
                WorkflowEditorView(workflow: $draft, applications: applications,
                    macOSShortcuts: macOSShortcuts, reusableWorkflows: [], onSaveReusable: onSave, showsLibraryControls: false)
            }
            if let error { Text(error).foregroundStyle(.red) }
            HStack {
                Button("Cancelar") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Salvar cena") {
                    do { try onSave(draft); dismiss() } catch { self.error = error.localizedDescription }
                }.disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || WorkflowEditorValidation.issue(in: draft) != nil)
                    .keyboardShortcut(.defaultAction).accessibilityIdentifier("tico.scene.save")
            }
        }.padding(24).frame(width: 850, height: 620)
    }
}
