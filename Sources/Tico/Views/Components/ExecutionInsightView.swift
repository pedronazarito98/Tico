import SwiftUI

struct ExecutionInsightView: View {
    let explanation: AutomationExplanation?
    let report: WorkflowExecutionReport?
    let onEdit: (UUID) -> Void
    let onExplore: () -> Void

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("O que aconteceu?", systemImage: "text.bubble").font(.headline)
                if let explanation {
                    Text(explanation.title).font(.title3.weight(.medium))
                    Text(explanation.detail).foregroundStyle(.secondary)
                    if let id = explanation.ruleIDs.first {
                        Button("Revisar atalho") { onEdit(id) }
                    } else {
                        Button("Explorar receitas", action: onExplore)
                    }
                } else {
                    Text("Use um atalho com a captura ativa para acompanhar o reconhecimento e a execução.")
                        .foregroundStyle(.secondary)
                }
                if let report {
                    DisclosureGroup("Última execução") { WorkflowReportView(report: report) }
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
        }.padding(.horizontal, 28).padding(.top, 20)
    }
}
