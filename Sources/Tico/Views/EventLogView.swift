import SwiftUI

struct EventLogPresentation: Identifiable {
    let id: UUID
    let date: Date
    let title: String
    let detail: String?
    let isError: Bool
    let steps: [WorkflowStepExecution]
}

struct EventLogView: View {
    let entries: [EventLogPresentation]
    let onClear: () -> Void

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    "Log vazio",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Eventos, execuções e erros aparecerão aqui.")
                )
            } else {
                List(entries) { entry in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: entry.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(entry.isError ? .red : .green)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.title)
                            if let detail = entry.detail, !detail.isEmpty {
                                Text(detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if !entry.steps.isEmpty {
                                DisclosureGroup("\(entry.steps.count) etapa(s)") {
                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(entry.steps) { step in
                                            HStack {
                                                Image(systemName: step.result.success
                                                    ? "checkmark.circle"
                                                    : "xmark.circle")
                                                    .foregroundStyle(step.result.success ? .green : .red)
                                                VStack(alignment: .leading, spacing: 1) {
                                                    Text("\(step.index + 1). \(step.stepName)")
                                                    Text(step.result.message)
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(2)
                                                }
                                                Spacer()
                                                Text(
                                                    "\(step.duration * 1_000, format: .number.precision(.fractionLength(1))) ms"
                                                )
                                                .monospacedDigit()
                                                .foregroundStyle(.secondary)
                                            }
                                            .font(.caption)
                                        }
                                    }
                                    .padding(.top, 5)
                                }
                                .font(.caption)
                            }
                        }
                        Spacer()
                        Text(entry.date, format: .dateTime.hour().minute().second())
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .navigationTitle("Log")
        .toolbar {
            ToolbarItem {
                Button("Limpar", action: onClear)
                    .disabled(entries.isEmpty)
            }
        }
    }
}
