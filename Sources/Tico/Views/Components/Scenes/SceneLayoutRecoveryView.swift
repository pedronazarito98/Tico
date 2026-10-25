import SwiftUI

/// Recuperação fica fora de cada card: excluir ou editar uma cena não oculta
/// handles ainda recuperáveis de uma execução anterior.
struct SceneLayoutRecoveryView: View {
    @ObservedObject var session: SceneLayoutSession
    let workflows: [ActionWorkflow]
    @State private var pendingDiscard: UUID?
    @State private var expandedResults: [UUID: Bool] = [:]
    @State private var usesCompactLayout = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let workflow = session.pendingReviewWorkflow {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Revisão pausada · \(workflow.name)", systemImage: "pause.circle").font(.headline)
                    Text("Retome para conferir as janelas atuais. Aplicativos e outras ações não serão executados novamente.")
                        .font(.callout).foregroundStyle(.secondary)
                    actionLayout {
                        Button("Retomar revisão", action: session.resumePendingReview)
                            .disabled(session.isBusy || session.hasPendingRecovery)
                        Button("Encerrar revisão", action: session.discardPendingReview).buttonStyle(.borderless)
                    }
                }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(TicoBrand.Palette.surface, in: .rect(cornerRadius: 12))
            }
            ForEach(session.recoveries.values.sorted { $0.workflowID.uuidString < $1.workflowID.uuidString }) { recovery in
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(name(for: recovery.workflowID), systemImage: "arrow.uturn.backward").font(.headline)
                        if recovery.pendingWindowCount > 0 {
                            Text("Você pode voltar à disposição anterior ou manter as janelas como estão.")
                                .font(.callout).foregroundStyle(.secondary)
                            actionLayout {
                                HStack {
                                    Button("Voltar à disposição anterior") {
                                        session.perform { await session.restore(workflowID: recovery.workflowID) }
                                    }.disabled(session.isBusy)
                                        .accessibilityIdentifier("tico.scene.layout.restore")
                                    if session.isBusy {
                                        ProgressView().controlSize(.small)
                                        Button("Cancelar", action: session.cancelOperation)
                                    }
                                }
                                Button("Manter esta disposição") { pendingDiscard = recovery.workflowID }
                                    .disabled(session.isBusy)
                            }
                        }
                        DisclosureGroup("Resultado por janela", isExpanded: details(for: recovery)) {
                            ForEach(recovery.results) { result in
                                Label("\(result.stepName): \(result.result.message)",
                                    systemImage: result.result.success ? "checkmark.circle" : "exclamationmark.triangle")
                                    .font(.caption).foregroundStyle(result.result.success ? Color.secondary : Color.orange)
                            }
                        }
                        if recovery.pendingWindowCount == 0 {
                            Button("Fechar resultado") { session.perform { await session.discardRecovery(workflowID: recovery.workflowID) } }
                                .buttonStyle(.borderless)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }
            }
            if let message = session.message { Text(message).font(.callout).foregroundStyle(.secondary) }
        }
        .onGeometryChange(for: Bool.self) { $0.size.width < 620 } action: { usesCompactLayout = $0 }
        .confirmationDialog("Manter esta disposição?", isPresented: discardPresented, titleVisibility: .visible) {
            Button("Manter e encerrar recuperação") {
                guard let id = pendingDiscard else { return }
                session.perform { await session.discardRecovery(workflowID: id) }
                pendingDiscard = nil
            }
        } message: { Text("As janelas ficam como estão e novas cenas ficam disponíveis. A disposição anterior deixa de poder ser restaurada pelo Tico.") }
    }

    private var actionLayout: AnyLayout {
        usesCompactLayout ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 12))
    }

    private func details(for recovery: SceneLayoutRecovery) -> Binding<Bool> {
        Binding(get: { expandedResults[recovery.id] ?? recovery.results.contains { !$0.result.success } },
                set: { expandedResults[recovery.id] = $0 })
    }

    private var discardPresented: Binding<Bool> {
        Binding(get: { pendingDiscard != nil }, set: { if !$0 { pendingDiscard = nil } })
    }
    private func name(for id: UUID) -> String {
        workflows.first(where: { $0.id == id })?.name ?? "Disposição anterior"
    }
}
