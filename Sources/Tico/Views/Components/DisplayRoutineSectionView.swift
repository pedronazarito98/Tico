import SwiftUI

/// Seção de manutenção compacta. A criação escolhe sua cena explicitamente;
/// a ativação reúne preferência global e configuração local no mesmo commit.
struct DisplayRoutineSectionView: View {
    let routines: [DisplayRoutine]
    let isEnabled: Bool
    var isMonitoringAvailable = true
    let workflows: [ActionWorkflow]
    let statusMessage: String
    let suggestion: DisplayRoutineSuggestion?
    let errorMessage: String?
    let onSetEnabled: (Bool) throws -> Void
    let onSave: (DisplayRoutine, Bool) throws -> Void
    let onDelete: (UUID) throws -> Void
    let onAccept: (UUID) -> Void
    let onDismiss: () -> Void
    @State private var editing: RoutineEditorPresentation?
    @State private var deleting: DisplayRoutine?
    @State private var actionError: String?
    @State private var usesCompactLayout = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerLayout {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Rotinas de telas", systemImage: "display.2").font(.headline)
                    Text(routines.isEmpty ? "Prepare uma cena quando seu espaço mudar."
                         : "\(routines.count) rotina(s) · \(routines.filter(\.isEnabled).count) habilitada(s)")
                        .font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 12) {
                    if !routines.isEmpty {
                        Toggle("Monitorar mudanças de tela", isOn: enabledBinding)
                            .toggleStyle(.switch).labelsHidden()
                            .accessibilityLabel("Monitorar mudanças de tela para todas as rotinas habilitadas")
                    }
                    if workflows.contains(where: \.isValid) {
                        Button("Adicionar rotina", systemImage: "plus") { editing = RoutineEditorPresentation() }
                            .disabled(routines.count >= 64)
                    }
                }.fixedSize().frame(maxWidth: usesCompactLayout ? .infinity : nil, alignment: .trailing)
            }
            if !workflows.contains(where: \.isValid) {
                Text(workflows.isEmpty
                     ? "Crie uma cena primeiro. As cenas também funcionam só com a tela do Mac."
                     : "Conclua a configuração de uma cena para adicionar sua rotina.")
                    .font(.callout).foregroundStyle(.secondary)
            } else if !routines.isEmpty {
                Text(statusMessage).font(.caption).foregroundStyle(.secondary)
            }
            if let suggestion {
                DisplayRoutinePromptView(suggestion: suggestion, onAccept: onAccept, onDismiss: onDismiss)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(routines) { routine in
                DisplayRoutineSummaryRow(routine: routine,
                    workflow: workflows.first { $0.id == routine.workflowID },
                    isGloballyEnabled: isEnabled, isMonitoringAvailable: isMonitoringAvailable,
                    onEdit: { editing = RoutineEditorPresentation(routine: routine) },
                    onPause: { pause(routine) }, onDelete: { deleting = routine })
            }
            if let message = actionError ?? errorMessage {
                Label(message, systemImage: "exclamationmark.circle").font(.callout).foregroundStyle(.red)
            }
        }
        .padding(18)
        .background(Color.primary.opacity(0.025), in: .rect(cornerRadius: 12))
        .onGeometryChange(for: Bool.self) { $0.size.width < 580 } action: { usesCompactLayout = $0 }
        .sheet(item: $editing) { presentation in
            DisplayRoutineEditorView(routine: presentation.routine, workflows: workflows,
                isGloballyEnabled: isEnabled, onSave: onSave)
        }
        .confirmationDialog("Remover esta rotina?", isPresented: deletionPresented, titleVisibility: .visible) {
            Button("Remover rotina", role: .destructive) { remove() }
        } message: { Text("A cena associada será preservada.") }
        .accessibilityIdentifier("tico.scenes.display-routines")
    }

    private var headerLayout: AnyLayout {
        usesCompactLayout ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
    }

    private var enabledBinding: Binding<Bool> {
        Binding(get: { isEnabled }, set: { enabled in
            do { try onSetEnabled(enabled); actionError = nil } catch { actionError = error.localizedDescription }
        })
    }
    private var deletionPresented: Binding<Bool> {
        Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })
    }
    private func pause(_ routine: DisplayRoutine) {
        var candidate = routine
        candidate.isEnabled = false
        do { try onSave(candidate, false); actionError = nil } catch { actionError = error.localizedDescription }
    }
    private func remove() {
        guard let deleting else { return }
        do { try onDelete(deleting.id); self.deleting = nil; actionError = nil }
        catch { actionError = error.localizedDescription }
    }
}

private struct RoutineEditorPresentation: Identifiable {
    let id = UUID()
    var routine: DisplayRoutine?
}

/// O estado efetivo combina rotina, monitoramento e capacidade da cena atual.
/// Não anunciamos execução automática se uma edição passou a exigir confirmação.
private struct DisplayRoutineSummaryRow: View {
    let routine: DisplayRoutine
    let workflow: ActionWorkflow?
    let isGloballyEnabled: Bool
    let isMonitoringAvailable: Bool
    let onEdit: () -> Void
    let onPause: () -> Void
    let onDelete: () -> Void

    private var mode: DisplayRoutineMode {
        workflow.map { DisplayRoutineCoordinator.effectiveMode(for: routine, workflow: $0) } ?? .suggest
    }
    private var status: String {
        guard let workflow, workflow.isValid else { return "Cena indisponível" }
        if !routine.isEnabled { return "Pausada" }
        if !isGloballyEnabled { return "Pausada com todas as rotinas" }
        if !isMonitoringAvailable { return "Pausada nesta sessão" }
        return mode == .automatic ? "Execução automática" : "Sugestão com confirmação"
    }
    private var behavior: String {
        "\(routine.trigger.title), \(mode == .automatic ? "preparar" : "sugerir") \(workflow?.name.isEmpty == false ? workflow?.name ?? "cena" : "a cena")."
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onEdit) {
                HStack(spacing: 12) {
                    Image(systemName: "rectangle.3.group").font(.title3).frame(width: 28)
                        .foregroundStyle(TicoBrand.Palette.primary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(routine.name).font(.callout.weight(.medium)).lineLimit(2)
                        Text(behavior).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        Text(status).font(.caption.weight(.medium))
                        if routine.mode == .automatic, mode != .automatic, workflow != nil {
                            Text("Esta cena agora precisa de confirmação.").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                }.padding(12).contentShape(Rectangle())
            }.buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityHint("Abre a configuração desta rotina")
            Menu {
                Button("Configurar rotina", action: onEdit)
                if routine.isEnabled { Button("Pausar esta rotina", action: onPause) }
                Divider()
                Button("Remover rotina…", role: .destructive, action: onDelete)
            } label: { Image(systemName: "ellipsis") }
                .menuStyle(.borderlessButton).fixedSize()
                .accessibilityLabel("Opções de \(routine.name)")
                .padding(.trailing, 12)
        }.background(TicoBrand.Palette.surface.opacity(0.7), in: .rect(cornerRadius: 10))
    }
}
