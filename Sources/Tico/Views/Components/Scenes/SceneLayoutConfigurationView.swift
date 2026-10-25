import SwiftUI

struct SceneLayoutConfigurationView: View {
    @Binding var plan: SceneLayoutPlan?
    @ObservedObject var session: SceneLayoutSession
    var applications: [ApplicationChoice] = []
    @State private var confirmsRecapture = false
    @State private var confirmsRemoval = false
    @State private var operationOwner = UUID()

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Disposição das janelas", systemImage: "rectangle.3.group").font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), alignment: .leading)], alignment: .leading, spacing: 8) {
                        Button(plan == nil ? "Guardar disposição atual" : "Usar janelas abertas", systemImage: "viewfinder") {
                            if plan == nil { capture() } else { confirmsRecapture = true }
                        }.disabled(session.isBusy)
                            .accessibilityIdentifier("tico.scene.layout.capture")
                        if plan != nil {
                            Button("Remover layout", role: .destructive) { confirmsRemoval = true }.disabled(session.isBusy)
                        }
                    }
                }
                if let current = plan {
                    SceneLayoutPlanEditor(plan: Binding(get: { plan ?? current }, set: { value in
                        plan = value.windows.isEmpty ? nil : value
                    }), applications: applications)
                    DisclosureGroup("Se uma tela não estiver disponível") {
                        Picker("Ao faltar uma tela", selection: fallback) {
                            ForEach(SceneLayoutMissingDisplayPolicy.allCases, id: \.self) { Text($0.label).tag($0) }
                        }.pickerStyle(.radioGroup).padding(.top, 8)
                        Text("Telas externas seguem a posição na mesa, da esquerda para a direita. O destino real será conferido antes de aplicar.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let issue = current.validationIssue { Text(issue).font(.caption).foregroundStyle(.orange) }
                } else {
                    Text("Guarde a disposição atual para prepará-la de novo quando precisar.")
                        .foregroundStyle(.secondary)
                }
                if session.isPerforming(ownerID: operationOwner) {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("Consultando janelas…")
                        Button("Cancelar") { session.cancelOperation(ownerID: operationOwner) }
                    }
                        .font(.caption)
                }
                ForEach(session.captureNotices, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                if let message = session.message { Text(message).font(.caption).foregroundStyle(.orange) }
            }.padding(8)
        }
        .onDisappear { session.cancelOperation(ownerID: operationOwner) }
        .confirmationDialog("Substituir a disposição em edição?", isPresented: $confirmsRecapture, titleVisibility: .visible) {
            Button("Usar disposição atual") { capture() }
        } message: { Text("As janelas abertas substituirão a seleção e as posições deste rascunho. A cena salva só muda ao salvar.") }
        .confirmationDialog("Remover a disposição de janelas?", isPresented: $confirmsRemoval, titleVisibility: .visible) {
            Button("Remover do rascunho", role: .destructive) { plan = nil }
        }
    }

    private var fallback: Binding<SceneLayoutMissingDisplayPolicy> {
        Binding(get: { plan?.missingDisplayPolicy ?? .stop }, set: { plan?.missingDisplayPolicy = $0 })
    }

    private func capture() {
        session.perform(ownerID: operationOwner) { if let captured = await session.capture() { plan = captured } }
    }

}
