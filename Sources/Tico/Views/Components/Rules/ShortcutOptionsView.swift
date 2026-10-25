import SwiftUI

/// Personalizações progressivas da direção aprovada. Delay e timeout projetam
/// campos do workflow existente; não existe um segundo modelo de execução.
struct ShortcutOptionsView: View {
    @ObservedObject var session: RuleEditingSession
    let applications: [ApplicationChoice]
    let displays: [DisplayCatalogService.Choice]
    let onClose: () -> Void
    @State private var showsNote = false
    @State private var showsAdvanced = false
    @State private var showsScope = false
    @State private var conditionPresentation: ConditionPresentation?
    @State private var usesCustomTimeout = false

    /// O payload e a apresentação mudam juntos, evitando abrir o popover com
    /// a condição anterior quando o usuário alterna entre Adicionar e Editar.
    private struct ConditionPresentation: Identifiable {
        let id = UUID()
        let original: RuleCondition?
    }

    private var delay: Binding<Double> {
        Binding(get: { session.draft.workflow.enabledSteps.first?.delayBefore ?? 0 }, set: { value in
            guard let index = session.draft.workflow.steps.firstIndex(where: \.isEnabled) else { return }
            session.draft.workflow.steps[index].delayBefore = value
        })
    }
    private var delayed: Binding<Bool> {
        Binding(get: { delay.wrappedValue > 0 }, set: { delay.wrappedValue = $0 ? 0.5 : 0 })
    }
    private var customTimeout: Binding<Bool> {
        Binding(get: { usesCustomTimeout }, set: {
            usesCustomTimeout = $0
            if !$0 { session.draft.workflow.timeout = 60 }
        })
    }
    private var uniqueConditions: [RuleCondition] {
        session.draft.conditions.reduce(into: []) { result, condition in
            if !result.contains(condition) { result.append(condition) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Mais ajustes").font(.title3.bold())
                Spacer()
                Button("Fechar ajustes", systemImage: "xmark.circle.fill", action: onClose)
                    .labelStyle(.iconOnly).buttonStyle(.plain)
            }.padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ShortcutOptionRow(title: "Nome") {
                        TextField("Nome do atalho", text: $session.draft.name)
                            .textFieldStyle(.roundedBorder).accessibilityLabel("Nome")
                            .accessibilityIdentifier("tico.rule.name")
                    }
                    if showsNote || !session.draft.notes.isEmpty {
                        TextField("Nota opcional", text: $session.draft.notes, axis: .vertical)
                            .textFieldStyle(.roundedBorder).lineLimit(2...4)
                    } else {
                        Button("Adicionar nota", systemImage: "note.text") { showsNote = true }
                            .buttonStyle(.borderless)
                    }
                    Divider()
                    ShortcutOptionRow(title: "Executar") {
                        Picker("Executar", selection: delayed) {
                            Text("Na hora").tag(false)
                            Text("Após pausa").tag(true)
                        }.pickerStyle(.segmented).labelsHidden().frame(maxWidth: .infinity)
                    }
                    if delayed.wrappedValue {
                        ShortcutOptionRow(title: "Pausa") {
                            Stepper("\(delay.wrappedValue, format: .number.precision(.fractionLength(1))) s",
                                    value: delay, in: 0.1...300, step: 0.1).fixedSize()
                        }
                    }
                    ShortcutOptionRow(title: "Disponível em") {
                        ForEach(Array(session.draft.scope.bundleIdentifiers.sorted().prefix(2)), id: \.self) { id in
                            ApplicationIconView(application: applications.first { $0.id == id }, size: 24)
                        }
                        Text(session.draft.scope.displayName(applications: applications)).lineLimit(2)
                        Spacer(minLength: 0)
                        Button("Alterar…") { showsScope = true }
                            .popover(isPresented: $showsScope) {
                                ShortcutScopePicker(scope: $session.draft.scope, applications: applications)
                            }
                    }
                    Divider()
                    DisclosureGroup("Avançado", isExpanded: $showsAdvanced) {
                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 7) {
                                ShortcutOptionRow(title: "Prioridade") {
                                  Picker("Prioridade", selection: $session.draft.priority) {
                                    Text("Baixa").tag(-5)
                                    Text("Normal").tag(0)
                                    Text("Alta").tag(5)
                                    if ![-5, 0, 5].contains(session.draft.priority) {
                                        Text("\(session.draft.priority)").tag(session.draft.priority)
                                    }
                                  }.pickerStyle(.segmented).labelsHidden().frame(maxWidth: .infinity)
                                }
                                Text("Usada se dois atalhos tiverem o mesmo gesto.")
                                    .font(.caption).foregroundStyle(.secondary)
                                    .padding(.leading, 128)
                            }
                            ShortcutOptionRow(title: "Tempo máximo") {
                                Picker("Tempo máximo", selection: customTimeout) {
                                    Text("Automático").tag(false)
                                    Text("Personalizar").tag(true)
                                }.pickerStyle(.segmented).labelsHidden().frame(maxWidth: .infinity)
                            }
                            if customTimeout.wrappedValue {
                                Stepper("Tempo máximo: \(session.draft.workflow.timeout, format: .number) s",
                                        value: $session.draft.workflow.timeout, in: 1...600)
                            }
                            Divider()
                            HStack {
                                Text("Condições")
                                if uniqueConditions.isEmpty { Text("Nenhuma").foregroundStyle(.secondary) }
                                Spacer()
                                Button("Adicionar", systemImage: "plus") {
                                    conditionPresentation = ConditionPresentation(original: nil)
                                }.accessibilityIdentifier("tico.composer.add-condition")
                                    .popover(item: $conditionPresentation, arrowEdge: .bottom) { presentation in
                                        ShortcutConditionPicker(displays: displays,
                                            initialCondition: presentation.original,
                                            onSave: { saveCondition($0, replacing: presentation.original) })
                                    }
                            }
                            ForEach(uniqueConditions, id: \.self) { condition in
                                HStack {
                                    Button(ShortcutConditionSummary.text(condition)) {
                                        conditionPresentation = ConditionPresentation(original: condition)
                                    }.buttonStyle(.plain).multilineTextAlignment(.leading)
                                        .disabled(isApplicationCondition(condition))
                                    Spacer()
                                    Button("Remover condição", systemImage: "minus.circle") {
                                        session.draft.conditions.removeAll { $0 == condition }
                                    }.labelStyle(.iconOnly).buttonStyle(.borderless)
                                }.font(.callout)
                            }
                        }.padding(.top, 16)
                    }
                }.padding(20)
            }
            Divider()
            HStack {
                Button("Restaurar padrões") {
                    session.resetComposerOptions()
                    showsNote = false
                    usesCustomTimeout = false
                }
                    .buttonStyle(.borderless)
                Spacer()
                Button("Concluir", action: onClose).buttonStyle(.glassProminent)
            }.padding(16)
        }
        .adaptiveSheetFrame(idealWidth: 650, idealHeight: 630)
        .onAppear { usesCustomTimeout = session.draft.workflow.timeout != 60 }
    }

    private func isApplicationCondition(_ value: RuleCondition) -> Bool {
        if case .application = value { return true }; return false
    }

    private func saveCondition(_ condition: RuleCondition, replacing original: RuleCondition?) {
        if let original, let index = session.draft.conditions.firstIndex(of: original) {
            session.draft.conditions[index] = condition
        } else if !session.draft.conditions.contains(condition) {
            session.draft.conditions.append(condition)
        }
    }
}

/// Coluna fixa de rótulos mantém a leitura alinhada sem impor largura aos campos.
private struct ShortcutOptionRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 8) {
            Text(title).frame(width: 120, alignment: .leading)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
