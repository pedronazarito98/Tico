import SwiftUI

struct WorkflowReportView: View {
    let report: WorkflowExecutionReport
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(report.summary.message, systemImage: report.success ? "checkmark.circle" : "exclamationmark.circle")
                .foregroundStyle(report.success ? Color.green : Color.orange)
            ForEach(report.stepExecutions) { step in
                Label("\(step.index + 1). \(step.stepName): \(step.result.message)",
                      systemImage: step.result.success ? "checkmark" : "exclamationmark.triangle")
                    .font(.caption)
            }
        }.accessibilityElement(children: .contain)
    }
}
