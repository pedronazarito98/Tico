import SwiftUI

/// Uma ação por cartão. Ajustes de execução não competem com o conteúdo principal.
/// O texto da URL é local para permitir digitação incompleta, mas a ação recebe um
/// valor inválido sentinela nesse caso: salvar nunca reaproveita o endereço anterior.
struct WorkflowStepCard: View {
    @Binding var step: WorkflowStep
    let position: Int
    let isExpanded: Bool
    let showsHeader: Bool
    let canDelete: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let applications: [ApplicationChoice]
    let macOSShortcuts: [String]
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onMove: (Int) -> Void
    @State private var urlDraft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showsHeader {
              HStack {
                Button(action: onToggle) {
                    HStack(spacing: 10) {
                        Text("\(position)").font(.caption.monospacedDigit().bold())
                            .frame(width: 26, height: 26).background(.quaternary, in: .circle)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(step.name.isEmpty ? RuleEditorSummary.action(step.action, applications: applications) : step.name)
                                .font(.callout.weight(.semibold)).lineLimit(2).multilineTextAlignment(.leading)
                            if !step.isEnabled || step.delayBefore > 0 || step.timeout != nil {
                                Text(metadata).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down").font(.caption)
                    }.contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityLabel("Editar ação \(position): \(RuleEditorSummary.action(step.action, applications: applications))")
                Menu {
                    Button("Mover para cima") { onMove(-1) }.disabled(!canMoveUp)
                    Button("Mover para baixo") { onMove(1) }.disabled(!canMoveDown)
                    Button(step.isEnabled ? "Desativar ação" : "Ativar ação") { step.isEnabled.toggle() }
                    Divider()
                    Button("Remover ação", role: .destructive, action: onDelete).disabled(!canDelete)
                } label: { Image(systemName: "ellipsis") }
                    .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Opções da ação \(position)")
              }
            }
            VStack(alignment: .leading, spacing: 14) {
                if showsHeader { Divider() }
                RuleActionEditorView(action: $step.action, urlText: urlText, applications: applications, macOSShortcuts: macOSShortcuts)
                if let issue = WorkflowEditorValidation.issue(in: step.action) {
                    Label(issue, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.orange)
                }
                DisclosureGroup("Ajustes desta ação") {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Nome opcional da ação", text: $step.name)
                        Toggle("Ação ativa", isOn: $step.isEnabled)
                        Stepper("Aguardar antes: \(step.delayBefore, format: .number) s", value: $step.delayBefore, in: 0...300, step: 0.5)
                        Toggle("Definir tempo limite próprio", isOn: timeoutEnabled)
                        if step.timeout != nil { Stepper("Limite: \(step.timeout ?? 15, format: .number) s", value: timeoutValue, in: 1...300) }
                    }.padding(.top, 10)
                }.font(.callout).foregroundStyle(.secondary)
            }
            .frame(height: contentIsVisible ? nil : 0, alignment: .top).clipped()
            .disabled(!contentIsVisible)
            .accessibilityElement(children: contentIsVisible ? .contain : .ignore)
            .accessibilityHidden(!contentIsVisible)
        }
        .padding(showsHeader ? 14 : 0)
        .background(Color.primary.opacity(showsHeader ? 0.035 : 0), in: .rect(cornerRadius: 12))
        .onAppear { synchronizeURL() }
        .onChange(of: step.action) { synchronizeURL() }
    }

    private var metadata: String {
        [!step.isEnabled ? "Desativada" : nil,
         step.delayBefore > 0 ? "Aguardar \(step.delayBefore.formatted()) s" : nil,
         step.timeout.map { "Limite de \($0.formatted()) s" }].compactMap { $0 }.joined(separator: " · ")
    }
    private var contentIsVisible: Bool { isExpanded || !showsHeader }
    private var timeoutEnabled: Binding<Bool> {
        Binding(get: { step.timeout != nil }, set: { step.timeout = $0 ? (step.timeout ?? 15) : nil })
    }
    private var timeoutValue: Binding<Double> {
        Binding(get: { step.timeout ?? 15 }, set: { step.timeout = $0 })
    }
    private var urlText: Binding<String> {
        Binding(get: { urlDraft }, set: { value in
            urlDraft = value
            step.action = .openURL(url: representedURL(value))
        })
    }
    private func representedURL(_ text: String) -> URL { URL(string: text) ?? URL(fileURLWithPath: "/") }
    private func synchronizeURL() {
        guard case let .openURL(url) = step.action, representedURL(urlDraft) != url else { return }
        urlDraft = url.absoluteString
    }
}
