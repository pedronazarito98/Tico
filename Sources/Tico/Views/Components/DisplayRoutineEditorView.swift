import SwiftUI

/// O editor compõe uma frase de intenção. O rascunho só recebe uma cena quando
/// ela vem do contexto ou de uma escolha explícita; cancelar nunca persiste.
/// Paralelo com React: estado local para o formulário e um único callback de commit.
struct DisplayRoutineEditorView: View {
    let workflows: [ActionWorkflow]
    let isGloballyEnabled: Bool
    let onSave: (DisplayRoutine, Bool) throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft: DisplayRoutine
    @State private var selectedWorkflowID: UUID?
    @State private var showsSceneChoices: Bool
    @State private var errorMessage: String?
    @State private var usesCompactLayout = false

    init(routine: DisplayRoutine? = nil, initialWorkflowID: UUID? = nil,
         workflows: [ActionWorkflow], isGloballyEnabled: Bool,
         onSave: @escaping (DisplayRoutine, Bool) throws -> Void) {
        self.workflows = workflows
        self.isGloballyEnabled = isGloballyEnabled
        self.onSave = onSave
        let chosenID = routine?.workflowID ?? initialWorkflowID
        var initial = routine ?? DisplayRoutine(workflowID: chosenID ?? UUID())
        if routine == nil { initial.name = "" }
        _draft = State(initialValue: initial)
        _selectedWorkflowID = State(initialValue: chosenID)
        _showsSceneChoices = State(initialValue: chosenID == nil)
    }

    private var selectedWorkflow: ActionWorkflow? {
        workflows.first { $0.id == selectedWorkflowID && $0.isValid }
    }
    private var automaticReason: String? {
        selectedWorkflow.map(DisplayRoutineCoordinator.automaticExecutionUnavailableReason)
            ?? "Escolha uma cena para ver como ela pode ser preparada."
    }
    private var effectiveMode: DisplayRoutineMode {
        draft.mode == .automatic && automaticReason == nil ? .automatic : .suggest
    }
    private var canSave: Bool {
        selectedWorkflow != nil && draft.name.trimmingCharacters(in: .whitespacesAndNewlines).utf8.count <= 160
    }
    private var sceneName: String {
        selectedWorkflow.map { $0.name.isEmpty ? "Cena sem nome" : $0.name } ?? "Escolha uma cena"
    }
    private var activationTitle: String {
        effectiveMode == .automatic ? "Ativar execução" : "Ativar sugestão"
    }
    private var suggestedName: String {
        let name = "\(draft.trigger.title) · \(sceneName)"
        var result = ""
        for character in name {
            guard (result + String(character)).utf8.count <= 160 else { break }
            result.append(character)
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Quando mudar de tela").font(.title2.weight(.semibold))
                Text("Escolha a mudança e o que o Tico deve fazer.").foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    sceneSelection
                    triggerSelection
                    behaviorSelection
                    advancedOptions
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.circle")
                            .font(.callout).foregroundStyle(.red)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
            }
            Divider()
            footer
        }
        .onGeometryChange(for: Bool.self) { $0.size.width < 560 } action: { usesCompactLayout = $0 }
        .adaptiveSheetFrame(idealWidth: 640, idealHeight: 690)
        .onChange(of: selectedWorkflowID) {
            if automaticReason != nil { draft.mode = .suggest }
        }
        .accessibilityIdentifier("tico.routine.editor")
    }

    private var sceneSelection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(sceneName, systemImage: "rectangle.3.group").font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                if selectedWorkflow != nil {
                    Button(showsSceneChoices ? "Fechar lista" : "Trocar cena") { showsSceneChoices.toggle() }
                        .fixedSize()
                }
            }
            if showsSceneChoices || selectedWorkflow == nil {
                if workflows.isEmpty {
                    Text("Crie uma cena primeiro. Ela pode usar apenas a tela do Mac.")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 6) {
                        ForEach(workflows) { workflow in
                            Button {
                                selectedWorkflowID = workflow.id
                                showsSceneChoices = false
                            } label: {
                                HStack {
                                    Image(systemName: "rectangle.3.group")
                                    Text(workflow.name.isEmpty ? "Cena sem nome" : workflow.name)
                                        .lineLimit(2)
                                    Spacer()
                                    if !workflow.isValid { Text("Revise a cena").font(.caption) }
                                    if selectedWorkflowID == workflow.id { Image(systemName: "checkmark") }
                                }.padding(10).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain).disabled(!workflow.isValid)
                            .background(selectedWorkflowID == workflow.id ? TicoBrand.Palette.primary.opacity(0.1) : .clear,
                                        in: .rect(cornerRadius: 8))
                            .accessibilityAddTraits(selectedWorkflowID == workflow.id ? .isSelected : [])
                        }
                    }
                }
            }
        }
    }

    private var triggerSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quando…").font(.headline)
            ForEach(DisplayRoutineTrigger.allCases) { trigger in
                RoutineChoiceRow(title: trigger.title, detail: triggerDetail(trigger),
                    symbol: triggerSymbol(trigger), isSelected: draft.trigger == trigger,
                    isAvailable: true, action: { draft.trigger = trigger })
            }
        }
    }

    private var behaviorSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("O Tico deve…").font(.headline)
            RoutineChoiceRow(title: "Sugerir esta cena", detail: "Você decide quando preparar o espaço.",
                symbol: "bubble.left", isSelected: effectiveMode == .suggest, isAvailable: true,
                action: { draft.mode = .suggest })
            RoutineChoiceRow(title: "Preparar automaticamente", detail: "Executar as ações sem pedir confirmação.",
                symbol: "bolt", isSelected: effectiveMode == .automatic,
                isAvailable: selectedWorkflow != nil && automaticReason == nil,
                action: { draft.mode = .automatic })
            if let automaticReason {
                Label(automaticReason, systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var advancedOptions: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Nome da rotina").font(.callout.weight(.medium))
                    TextField(suggestedName, text: $draft.name)
                        .textFieldStyle(.roundedBorder).accessibilityLabel("Nome da rotina, opcional")
                    if draft.name.utf8.count > 160 {
                        Text("Use um nome mais curto.").font(.caption).foregroundStyle(.red)
                    }
                }
                Toggle("Exigir uma quantidade de telas externas", isOn: restrictExternalCount)
                if draft.externalCount != nil {
                    Stepper(value: externalCount, in: 0...32) {
                        Text("\(draft.externalCount ?? 0) tela(s) externa(s) após a mudança")
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tela do Mac").font(.callout.weight(.medium))
                    Picker("Tela do Mac", selection: builtInRequirement) {
                        Text("Indiferente").tag(-1)
                        Text("Disponível").tag(1)
                        Text("Indisponível").tag(0)
                    }.pickerStyle(.segmented).labelsHidden()
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tela principal").font(.callout.weight(.medium))
                    Picker("Tela principal", selection: mainRole) {
                        Text("Indiferente").tag("any")
                        Text("Integrada").tag("builtIn")
                        Text("Externa").tag("external")
                    }.pickerStyle(.segmented).labelsHidden()
                }
                Text("As condições são avaliadas depois da mudança. O Tico não dispara rotinas ao iniciar ou retomar o Mac.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(.top, 12)
        } label: {
            Text(hasEnvironmentConditions ? "Condições e nome · condições configuradas" : "Condições e nome")
                .font(.callout)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isGloballyEnabled
                 ? "Salvar pausada mantém esta rotina sem executar. Ativar vale para a próxima mudança de telas."
                 : "Ativar também retoma o monitoramento de telas e as outras rotinas marcadas como ativas.")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            // AnyLayout muda a distribuição sem recriar controles ou o rascunho.
            // Paralelo com React: a árvore permanece montada; só o layout muda.
            footerLayout {
                Button("Cancelar") { dismiss() }.keyboardShortcut(.cancelAction)
                HStack {
                    Button("Salvar pausada") { save(activate: false) }.disabled(!canSave)
                    Button(activationTitle) { save(activate: true) }
                        .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(!canSave)
                        .accessibilityIdentifier("tico.routine.activate")
                }.frame(maxWidth: .infinity, alignment: .trailing)
            }
        }.padding(16)
    }

    private var footerLayout: AnyLayout {
        usesCompactLayout ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(spacing: 12))
    }

    private var hasEnvironmentConditions: Bool {
        draft.externalCount != nil || draft.requiresBuiltIn != nil || draft.mainDisplayRole != nil
    }
    private var restrictExternalCount: Binding<Bool> {
        Binding(get: { draft.externalCount != nil }, set: { draft.externalCount = $0 ? 1 : nil })
    }
    private var externalCount: Binding<Int> {
        Binding(get: { draft.externalCount ?? 1 }, set: { draft.externalCount = $0 })
    }
    private var builtInRequirement: Binding<Int> {
        Binding(get: { draft.requiresBuiltIn.map { $0 ? 1 : 0 } ?? -1 },
                set: { draft.requiresBuiltIn = $0 == -1 ? nil : $0 == 1 })
    }
    private var mainRole: Binding<String> {
        Binding(get: { draft.mainDisplayRole?.rawValue ?? "any" },
                set: { draft.mainDisplayRole = DisplayEnvironmentSnapshot.MainDisplayRole(rawValue: $0) })
    }
    private func save(activate: Bool) {
        guard let workflow = selectedWorkflow, canSave else { return }
        var candidate = draft
        candidate.workflowID = workflow.id
        candidate.mode = effectiveMode
        candidate.isEnabled = activate
        candidate.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if candidate.name.isEmpty { candidate.name = suggestedName }
        do { try onSave(candidate, activate); dismiss() }
        catch { errorMessage = error.localizedDescription }
    }
    private func triggerSymbol(_ trigger: DisplayRoutineTrigger) -> String {
        switch trigger {
        case .externalConnected: "display"
        case .externalDisconnected: "laptopcomputer"
        case .topologyChanged: "rectangle.3.group"
        }
    }
    private func triggerDetail(_ trigger: DisplayRoutineTrigger) -> String {
        switch trigger {
        case .externalConnected: "Uma tela externa passa a fazer parte do espaço."
        case .externalDisconnected: "Voltar à tela do Mac, por exemplo."
        case .topologyChanged: "Mudar posição, resolução ou tela principal."
        }
    }
}

/// Escolha nativa com seleção visível e anunciada, sem depender apenas da cor.
private struct RoutineChoiceRow: View {
    let title: String
    let detail: String
    let symbol: String
    let isSelected: Bool
    let isAvailable: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.title3).frame(width: 26)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.callout.weight(.medium))
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? TicoBrand.Palette.primary : .secondary)
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(!isAvailable)
        .background(isSelected ? TicoBrand.Palette.primary.opacity(0.09) : Color.primary.opacity(0.025),
                    in: .rect(cornerRadius: 10))
        .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(isSelected ? TicoBrand.Palette.primary.opacity(0.45) : .clear) }
        .opacity(isAvailable ? 1 : 0.55)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title). \(detail)")
        .accessibilityValue(isSelected ? "Selecionado" : "Não selecionado")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
