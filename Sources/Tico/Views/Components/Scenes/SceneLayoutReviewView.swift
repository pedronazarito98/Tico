import SwiftUI

/// Segunda fase da mesma execução: as ações anteriores já terminaram. Os botões
/// só revisam/aprovam o layout; nunca disparam novamente o workflow ou seus apps.
struct SceneLayoutReviewView: View {
    let workflow: ActionWorkflow
    @ObservedObject var session: SceneLayoutSession
    let deadline: Date
    @State private var usesCompactLayout = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(workflow.name.isEmpty ? "Revisar layout" : workflow.name).font(.title2.bold())
                        .lineLimit(2).help(workflow.name)
                    Text(workflow.enabledSteps.isEmpty
                         ? "Confira as janelas e confirme a disposição."
                         : "As ações anteriores terminaram. Confira agora as janelas disponíveis.")
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button("Atualizar", systemImage: "arrow.clockwise") {
                    session.perform { await session.prepare(workflow: workflow) }
                }.disabled(session.reviewIsBusy).fixedSize()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let preview = session.preview, preview.workflowID == workflow.id {
                        canvasLayout {
                            SceneLayoutCanvas(preview: preview, showsTarget: false)
                            SceneLayoutCanvas(preview: preview, showsTarget: true)
                        }
                        ForEach(Array(preview.windows.enumerated()), id: \.element.id) { index, window in
                            VStack(alignment: .leading, spacing: 6) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(index + 1). \(window.applicationName)").font(.headline)
                                    Text(window.targetDisplay?.label ?? "Monitor indisponível")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                if window.choices.count > 1 || window.selectedWindowID == nil {
                                    Picker("Qual janela?", selection: selection(for: window)) {
                                        Text("Escolher janela").tag(UUID?.none)
                                        ForEach(window.choices) { choice in Text(choice.label).tag(Optional(choice.id)) }
                                    }.disabled(session.reviewIsBusy || window.choices.isEmpty)
                                } else if window.issue == nil {
                                    Label("Pronta para organizar", systemImage: "checkmark.circle")
                                        .font(.callout).foregroundStyle(.secondary)
                                }
                                if window.selectedWindowID != nil {
                                    Button("Mostrar no aplicativo", systemImage: "arrow.up.forward.app") {
                                        session.perform { await session.identify(workflowID: workflow.id, slotID: window.id) }
                                    }.buttonStyle(.borderless).font(.caption).disabled(session.reviewIsBusy)
                                }
                                if let issue = window.issue {
                                    Label(issue, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
                                }
                            }.padding(.vertical, 4)
                        }
                        ForEach(preview.notices, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                    }
                    if session.preview == nil {
                        Text("A prévia ainda não está disponível. Atualize depois que as janelas abrirem.")
                            .foregroundStyle(.secondary)
                    }
                    if let message = session.message { Text(message).foregroundStyle(.orange) }
                    Text("A revisão pausa após 5 minutos. Você poderá retomar.")
                        .font(.caption).foregroundStyle(.secondary)
                    if !workflow.enabledSteps.isEmpty {
                        Text("Cancelar o layout preserva as ações já executadas. Apenas posição e tamanho das janelas têm restauração pelo Tico.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack {
                Button("Cancelar layout") { session.resolveReview(workflowID: workflow.id, accepted: false) }
                    .keyboardShortcut(.cancelAction).fixedSize()
                if session.reviewIsBusy { ProgressView().controlSize(.small) }
                Spacer()
                Button("Aplicar disposição", systemImage: "rectangle.3.group") {
                    session.resolveReview(workflowID: workflow.id, accepted: true)
                }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(!session.canApproveReview)
                    .accessibilityIdentifier("tico.scene.layout.apply").fixedSize()
            }
        }.padding(20).frame(maxWidth: .infinity, maxHeight: .infinity)
            .onGeometryChange(for: Bool.self) { $0.size.width < 680 } action: { usesCompactLayout = $0 }
    }

    /// Agora/Depois preservam a identidade ao empilhar. O panel controla a área;
    /// a view não impõe um tamanho mínimo maior que o espaço oferecido.
    private var canvasLayout: AnyLayout {
        usesCompactLayout ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 16))
    }

    private func selection(for window: SceneLayoutPreviewWindow) -> Binding<UUID?> {
        Binding(get: { window.selectedWindowID }, set: { value in
            session.perform { await session.selectWindow(workflowID: workflow.id, slotID: window.id, windowID: value) }
        })
    }
}
