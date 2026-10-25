import SwiftUI

/// Resumo da intenção; manutenção e etapas completas só aparecem quando pedidas.
struct SceneCardView: View {
    let workflow: ActionWorkflow
    let applications: [ApplicationChoice]
    let isRunning: Bool
    let hasPendingRecovery: Bool
    let report: WorkflowExecutionReport?
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onRun: () -> Void
    let onCancel: () -> Void
    let onCreateRule: () -> Void
    let onConfigureRoutine: (() -> Void)?
    @State private var showsDetails = false
    @State private var usesCompactLayout = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerLayout {
                HStack(spacing: 14) {
                    Image(systemName: "rectangle.3.group").font(.title).foregroundStyle(TicoBrand.Palette.primary)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(workflow.name.isEmpty ? "Cena sem nome" : workflow.name).font(.title3.bold())
                            .fixedSize(horizontal: false, vertical: true)
                        Text(summary).font(.callout).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 12) {
                    Menu {
                        Button("Editar cena", action: onEdit)
                        if let onConfigureRoutine { Button("Usar quando…", action: onConfigureRoutine) }
                        Button("Usar com um atalho", action: onCreateRule)
                        Divider()
                        Button("Excluir cena", role: .destructive, action: onDelete)
                    } label: { Image(systemName: "ellipsis.circle") }
                        .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Opções de \(workflow.name)")
                    if isRunning {
                        ProgressView().controlSize(.small)
                        Button("Cancelar", action: onCancel)
                    } else {
                        Button("Preparar cena", systemImage: "play.fill", action: onRun)
                            .buttonStyle(.borderedProminent).disabled(!workflow.isValid || hasPendingRecovery)
                    }
                }.fixedSize().frame(maxWidth: usesCompactLayout ? .infinity : nil, alignment: .trailing)
            }
            if hasPendingRecovery {
                Text("Escolha manter ou restaurar a disposição anterior acima para preparar outra cena.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let layout = workflow.sceneLayout {
                Text(layout.windows.map { "\($0.applicationName) · \($0.display.label)" }.joined(separator: "   "))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            DisclosureGroup("Ações e detalhes", isExpanded: $showsDetails) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(workflow.enabledSteps.enumerated()), id: \.element.id) { index, step in
                        Text("\(index + 1). \(RuleEditorSummary.action(step.action, applications: applications))")
                            .font(.callout)
                    }
                    if let report { WorkflowReportView(report: report) }
                }.padding(.top, 8)
            }.font(.callout)
            if let report, !showsDetails {
                Label(report.summary.message, systemImage: report.summary.success ? "checkmark.circle" : "exclamationmark.circle")
                    .font(.caption).foregroundStyle(report.summary.success ? Color.secondary : .orange)
            }
        }
        .padding(18).background(TicoBrand.Palette.surface, in: .rect(cornerRadius: 14))
        .onGeometryChange(for: Bool.self) { $0.size.width < 560 } action: { usesCompactLayout = $0 }
        .onChange(of: report?.finishedAt) { if report?.summary.success == false { showsDetails = true } }
    }

    /// Reorganiza a mesma árvore para não perder a expansão de detalhes ao
    /// redimensionar a janela. Nenhum estado de execução pertence ao layout.
    private var headerLayout: AnyLayout {
        usesCompactLayout ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 14))
    }

    private var summary: String {
        var parts: [String] = []
        if let layout = workflow.sceneLayout { parts.append("\(layout.windows.count) janelas") }
        if !workflow.enabledSteps.isEmpty { parts.append("\(workflow.enabledSteps.count) ações") }
        return parts.joined(separator: " · ")
    }
}
