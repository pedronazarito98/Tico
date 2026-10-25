import SwiftUI

/// Modelos reutilizáveis e gestos ensinados compartilham busca e seleção estável.
/// Personalizar envia o modelo ao shell, sem salvar uma regra provisória.
struct GestureLibraryView: View {
    @ObservedObject var store: ShortcutStore
    var onUsePreset: ((GesturePreset) -> Void)? = nil
    var searchText = ""
    @State private var selectedTemplateID: UUID?
    @State private var selectedPresetID: UUID?
    @State private var tab = LibraryTab.presets
    @State private var presentedError: String?
    @State private var templatePendingDeletion: CustomGestureTemplate?

    private var query: String { searchText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var templates: [CustomGestureTemplate] {
        store.customGestureTemplates.filter { query.isEmpty || $0.name.localizedStandardContains(query) }
    }
    private var presets: [GesturePreset] {
        store.presets.filter {
            query.isEmpty || [$0.name, $0.summary, $0.trigger.displayName]
                .contains { $0.localizedStandardContains(query) }
                || $0.workflow.steps.contains { $0.displayName.localizedStandardContains(query) }
        }
    }
    private var selectedTemplate: CustomGestureTemplate? { templates.first { $0.id == selectedTemplateID } }
    private var selectedPreset: GesturePreset? { presets.first { $0.id == selectedPresetID } }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Reaproveite o que já funciona").font(.title2.weight(.semibold))
                HStack(spacing: 8) {
                    tabButton(.presets, count: presets.count)
                    tabButton(.gestures, count: templates.count)
                    Spacer()
                }
                if let presentedError {
                    Label(presentedError, systemImage: "exclamationmark.circle")
                        .font(.callout).foregroundStyle(.red)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
            Divider()
            switch tab {
            case .gestures: gestureLibrary
            case .presets: presetLibrary
            }
        }
        .navigationTitle("Modelos e gestos")
        .onAppear(perform: reconcileSelection)
        .onChange(of: searchText) { reconcileSelection() }
        .onChange(of: store.presets) { reconcileSelection() }
        .onChange(of: store.customGestureTemplates) { reconcileSelection() }
        .confirmationDialog("Excluir este gesto ensinado?", isPresented: deletionPresented, titleVisibility: .visible) {
            Button("Excluir gesto", role: .destructive, action: deleteTemplate)
        } message: {
            Text("Atalhos que usam este gesto precisam ser ajustados antes da exclusão.")
        }
    }

    private func tabButton(_ value: LibraryTab, count: Int) -> some View {
        Button { tab = value } label: {
            Label("\(value.title) · \(count)", systemImage: value == .presets ? "square.stack.3d.up" : "scribble.variable")
        }
        .buttonStyle(.bordered)
        .tint(tab == value ? TicoBrand.Palette.primary : .secondary)
        .accessibilityAddTraits(tab == value ? .isSelected : [])
    }

    private var presetLibrary: some View {
        AdaptiveSplitView(maxPrimaryWidth: 340) {
            List(presets, selection: $selectedPresetID) { preset in
                HStack(spacing: 10) {
                    Image(systemName: RuleEditorSummary.symbol(preset.trigger))
                        .foregroundStyle(TicoBrand.Palette.primary).frame(width: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(preset.name).font(.callout.weight(.medium)).lineLimit(1)
                        Text(preset.trigger.displayName).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                }.padding(.vertical, 6).tag(preset.id)
            }
            .listStyle(.inset)
            .overlay {
                if presets.isEmpty {
                    emptyList(title: query.isEmpty ? "Nenhum modelo salvo" : "Nenhum modelo encontrado",
                        symbol: "square.stack.3d.up", message: query.isEmpty
                        ? "Salve um atalho como modelo nas opções do editor."
                        : "Tente outro nome, resultado ou acionamento.")
                }
            }
        } detail: {
            Group {
                if let preset = selectedPreset {
                    presetDetail(preset)
                } else {
                    ContentUnavailableView("Escolha um modelo", systemImage: "square.stack.3d.up",
                        description: Text("Confira o resultado e personalize uma cópia para seu uso."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func presetDetail(_ preset: GesturePreset) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(preset.name).font(.title2.weight(.semibold))
                        Text(preset.summary.isEmpty ? "Personalize esta base sem alterar o modelo salvo." : preset.summary)
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Ao usar este acionamento").font(.headline)
                        ViewThatFits(in: .horizontal) {
                            TriggerKeycaps(trigger: preset.trigger)
                            Text(preset.trigger.displayName).font(.callout)
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("O Tico faz").font(.headline)
                        ForEach(Array(preset.workflow.steps.enumerated()), id: \.element.id) { index, step in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1)").font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary).frame(width: 22)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(step.displayName).font(.callout)
                                    if !step.isEnabled { Text("Etapa pausada").font(.caption).foregroundStyle(.secondary) }
                                }
                            }
                        }
                        if let layout = preset.workflow.sceneLayout {
                            Label("Organiza \(layout.windows.count) janela(s)", systemImage: "rectangle.3.group")
                                .font(.callout)
                        }
                    }
                    Text("O editor permite alterar o acionamento, as ações e onde o atalho funciona antes de salvar.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(20).frame(maxWidth: 640, alignment: .leading)
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                if onUsePreset == nil {
                    Text("A personalização não está disponível nesta janela.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                HStack {
                    Spacer(minLength: 0)
                    Button("Personalizar modelo", systemImage: "pencil") { onUsePreset?(preset) }
                        .buttonStyle(.borderedProminent).disabled(onUsePreset == nil)
                        .accessibilityIdentifier("tico.library.personalize-preset")
                }
            }.padding(16)
        }
    }

    private var gestureLibrary: some View {
        AdaptiveSplitView(maxPrimaryWidth: 340) {
            List(templates, selection: $selectedTemplateID) { template in
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name).font(.callout.weight(.medium)).lineLimit(1)
                    Text("\(template.fingerCount.displayText) dedos · \(template.samplePaths.count) amostras")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(.vertical, 6).tag(template.id)
            }
            .listStyle(.inset)
            .overlay {
                if templates.isEmpty {
                    emptyList(title: query.isEmpty ? "Nenhum gesto ensinado" : "Nenhum gesto encontrado",
                        symbol: "scribble.variable", message: query.isEmpty
                        ? "No editor, use Ensinar gesto para gravar de três a cinco amostras."
                        : "Tente buscar pelo nome do gesto.")
                }
            }
        } detail: {
            Group {
                if let template = selectedTemplate {
                    gestureDetail(template)
                } else {
                    ContentUnavailableView("Escolha um gesto", systemImage: "scribble",
                        description: Text("Consulte as amostras e os detalhes do reconhecimento."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func gestureDetail(_ template: CustomGestureTemplate) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(template.name).font(.title2.weight(.semibold))
                        Text("Gesto ensinado neste Mac").font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Menu("Opções") {
                        Button("Duplicar gesto") { duplicate(template) }
                        Button("Excluir gesto…", role: .destructive) { templatePendingDeletion = template }
                    }.fixedSize()
                }
                GesturePathPreview(path: template.representativePath)
                    .frame(maxWidth: .infinity).frame(height: 230)
                Text("Para regravar, abra o atalho que usa este gesto e escolha Ensinar gesto novamente.")
                    .font(.callout).foregroundStyle(.secondary)
                DisclosureGroup("Detalhes do reconhecimento") {
                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent("Dedos", value: template.fingerCount.displayText)
                        LabeledContent("Amostras", value: "\(template.samplePaths.count)")
                        LabeledContent("Tolerância", value: template.tolerance.formatted(.number.precision(.fractionLength(2))))
                        Text("O reconhecimento é local e determinístico. Gestos semelhantes aparecem como conflito antes de salvar.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.padding(.top, 12)
                }
            }.padding(20).frame(maxWidth: 640, alignment: .leading)
        }
    }

    private func emptyList(title: String, symbol: String, message: String) -> some View {
        VStack(spacing: 6) {
            Label(title, systemImage: symbol).font(.headline)
            Text(message).font(.caption).foregroundStyle(.secondary)
        }.multilineTextAlignment(.center).padding(12).allowsHitTesting(false)
    }

    private var deletionPresented: Binding<Bool> {
        Binding(get: { templatePendingDeletion != nil }, set: { if !$0 { templatePendingDeletion = nil } })
    }
    private func reconcileSelection() {
        if !presets.contains(where: { $0.id == selectedPresetID }) { selectedPresetID = presets.first?.id }
        if !templates.contains(where: { $0.id == selectedTemplateID }) { selectedTemplateID = templates.first?.id }
    }
    private func duplicate(_ template: CustomGestureTemplate) {
        do {
            selectedTemplateID = try store.duplicateCustomGestureTemplate(id: template.id).id
            presentedError = nil
        } catch { presentedError = error.localizedDescription }
    }
    private func deleteTemplate() {
        guard let template = templatePendingDeletion else { return }
        do {
            try store.deleteCustomGestureTemplate(id: template.id)
            templatePendingDeletion = nil
            presentedError = nil
            reconcileSelection()
        } catch { presentedError = "Remova o gesto dos atalhos antes de excluí-lo." }
    }
}

private enum LibraryTab {
    case gestures, presets
    var title: String { self == .presets ? "Modelos salvos" : "Gestos ensinados" }
}
