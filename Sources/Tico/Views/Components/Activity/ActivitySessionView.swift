import SwiftUI

/// Reconhecimento e execução são apresentados separadamente: um movimento novo
/// sem regra não deve receber o resultado da execução anterior como se fossem um.
struct ActivitySessionView: View {
    let explanation: AutomationExplanation?
    let report: WorkflowExecutionReport?
    let onEdit: (UUID) -> Void
    let onExplore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let explanation {
                DisclosureGroup("Último reconhecimento · \(explanation.title)") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(explanation.detail).foregroundStyle(.secondary)
                        if let id = explanation.ruleIDs.first {
                            Button("Revisar atalho") { onEdit(id) }
                        } else {
                            Button("Explorar ideias", action: onExplore)
                        }
                    }.padding(.top, 8)
                }
            }
            if let report {
                DisclosureGroup("Última execução desta sessão") {
                    WorkflowReportView(report: report).padding(.top, 8)
                }
            }
        }.font(.callout)
    }
}
