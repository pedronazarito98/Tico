import SwiftUI

/// O StateObject vive somente neste modo da sheet. Sair dele cancela a tarefa
/// e apaga a frase; uma geração nunca entrega uma regra ao shell automaticamente.
struct NaturalAutomationView: View {
    let applications: [ApplicationChoice]
    let recordedTrigger: TriggerDefinition?
    let onRecord: () -> Void
    let onCreate: (ShortcutRule) -> Void
    @StateObject private var session: AutomationIntelligenceSession
    @Environment(\.scenePhase) private var scenePhase

    init(service: any LocalIntelligenceServicing, applications: [ApplicationChoice],
         recordedTrigger: TriggerDefinition?, onRecord: @escaping () -> Void,
         onCreate: @escaping (ShortcutRule) -> Void) {
        self.applications = applications
        self.recordedTrigger = recordedTrigger
        self.onRecord = onRecord
        self.onCreate = onCreate
        _session = StateObject(wrappedValue: AutomationIntelligenceSession(service: service))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(session.availability.message, systemImage: "sparkles")
                .font(.callout).foregroundStyle(.secondary)
                .accessibilityIdentifier("tico.describe.ai-availability")
            if session.availability != .available {
                Text("Você pode continuar em Montar com escolhas ou Escrever uma frase.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Verificar novamente") { Task { await session.refreshAvailability() } }
            }
            Text("Descreva o gesto, onde ele funciona e o resultado. A proposta será revisada antes de abrir o editor.")
                .font(.callout).foregroundStyle(.secondary)
            TextField("Com três dedos pra esquerda no Safari, coloque a janela na metade esquerda", text: $session.text, axis: .vertical)
                .lineLimit(3...6).textFieldStyle(.roundedBorder)
                .accessibilityLabel("Descrição da automação em linguagem natural")
                .accessibilityIdentifier("tico.describe.ai-sentence")
            Text("Até 1.000 caracteres. Toques e swipes com 2–5 dedos; mover, ampliar ou centralizar janela, reabrir aba, atualizar página ou janela, abrir app ou link. Para condições e sequências, use o editor.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(recordedTrigger == nil ? "Gravar ‘este gesto’" : "Gravar novamente", action: onRecord)
                if let recordedTrigger { Text(recordedTrigger.displayName).font(.caption).foregroundStyle(.secondary) }
            }
            if session.isGenerating {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Preparando proposta…").font(.callout)
                    Spacer()
                    Button("Cancelar geração", action: session.invalidate)
                        .accessibilityIdentifier("tico.describe.ai-cancel")
                }
            } else if let draft = session.draft {
                AutomationProposalView(draft: draft, applications: applications, onReview: session.invalidate)
                Button("Personalizar no editor") { onCreate(draft) }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("tico.describe.ai-review")
            } else {
                Button("Gerar proposta") { session.generate(applications: applications, recordedTrigger: recordedTrigger) }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(session.availability != .available || session.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("tico.describe.ai-generate")
            }
            if let issue = session.issue {
                Label(issue, systemImage: "info.circle").font(.callout).foregroundStyle(.secondary)
                    .accessibilityIdentifier("tico.describe.ai-issue")
            }
        }
        .task { await session.refreshAvailability() }
        .onChange(of: scenePhase) { if scenePhase == .active { Task { await session.refreshAvailability() } } }
        .onChange(of: applications) { session.invalidate() }
        .onChange(of: recordedTrigger) { session.invalidate() }
        .onDisappear { session.clear() }
    }
}
