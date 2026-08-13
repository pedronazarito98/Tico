import SwiftUI

struct GestureLibraryView: View {
    @ObservedObject var store: ShortcutStore

    @State private var selectedTemplateID: UUID?
    @State private var selectedPresetID: UUID?
    @State private var tab = LibraryTab.gestures
    @State private var presentedError: String?

    var body: some View {
        VStack(spacing: 0) {
            Picker("Biblioteca", selection: $tab) {
                ForEach(LibraryTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            switch tab {
            case .gestures:
                gestureLibrary
            case .presets:
                presetLibrary
            }
        }
        .navigationTitle("Biblioteca")
        .alert("Biblioteca", isPresented: errorPresented) {
            Button("OK", role: .cancel) { presentedError = nil }
        } message: {
            Text(presentedError ?? "Erro desconhecido")
        }
    }

    private var gestureLibrary: some View {
        HSplitView {
            List(store.customGestureTemplates, selection: $selectedTemplateID) { template in
                VStack(alignment: .leading, spacing: 2) {
                    Text(template.name)
                    Text("\(template.fingerCount.displayText) dedos · \(template.samplePaths.count) amostras")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(template.id)
            }
            .overlay {
                if store.customGestureTemplates.isEmpty {
                    ContentUnavailableView(
                        "Nenhum gesto ensinado",
                        systemImage: "scribble.variable",
                        description: Text("Use “Ensinar gesto” em uma regra para gravar de três a cinco amostras.")
                    )
                }
            }
            .frame(minWidth: 250, idealWidth: 290)

            if let template = selectedTemplate {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(template.name)
                                .font(.title2.weight(.semibold))
                            Text("Reconhecimento local e determinístico")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Duplicar") {
                            do {
                                let copy = try store.duplicateCustomGestureTemplate(id: template.id)
                                selectedTemplateID = copy.id
                            } catch {
                                presentedError = error.localizedDescription
                            }
                        }
                        Button("Excluir", role: .destructive) {
                            do {
                                try store.deleteCustomGestureTemplate(id: template.id)
                                selectedTemplateID = store.customGestureTemplates.first?.id
                            } catch {
                                presentedError = "Remova o gesto das regras antes de excluí-lo."
                            }
                        }
                    }

                    GesturePathPreview(path: template.representativePath)
                        .frame(maxWidth: .infinity, minHeight: 280)

                    HStack {
                        LabeledContent("Dedos", value: template.fingerCount.displayText)
                        LabeledContent("Amostras", value: "\(template.samplePaths.count)")
                        LabeledContent(
                            "Tolerância",
                            value: template.tolerance.formatted(
                                .number.precision(.fractionLength(2))
                            )
                        )
                    }
                    .frame(maxWidth: 560)

                    Text("Para regravar, abra a regra que usa este template e escolha “Ensinar gesto” novamente. Templates semelhantes aparecem como conflito antes de salvar.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(24)
                .frame(minWidth: 460)
            } else {
                ContentUnavailableView("Selecione um gesto", systemImage: "scribble")
                    .frame(minWidth: 460)
            }
        }
    }

    private var presetLibrary: some View {
        HSplitView {
            List(store.presets, selection: $selectedPresetID) { preset in
                VStack(alignment: .leading, spacing: 2) {
                    Text(preset.name)
                    Text(preset.trigger.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .tag(preset.id)
            }
            .overlay {
                if store.presets.isEmpty {
                    ContentUnavailableView(
                        "Nenhum preset",
                        systemImage: "square.stack.3d.up",
                        description: Text("Salve uma regra como preset no editor.")
                    )
                }
            }
            .frame(minWidth: 250, idealWidth: 290)

            if let preset = selectedPreset {
                VStack(alignment: .leading, spacing: 16) {
                    Text(preset.name)
                        .font(.title2.weight(.semibold))
                    Text(preset.summary.isEmpty ? "Preset local" : preset.summary)
                        .foregroundStyle(.secondary)
                    GroupBox("Gatilho") {
                        LabeledContent("Quando", value: preset.trigger.displayName)
                            .padding(4)
                    }
                    GroupBox("Workflow") {
                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(Array(preset.workflow.steps.enumerated()), id: \.element.id) { index, step in
                                Label(
                                    "\(index + 1). \(step.displayName)",
                                    systemImage: "bolt"
                                )
                            }
                        }
                        .padding(4)
                    }
                    Spacer()
                }
                .padding(24)
                .frame(minWidth: 460)
            } else {
                ContentUnavailableView("Selecione um preset", systemImage: "square.stack.3d.up")
                    .frame(minWidth: 460)
            }
        }
    }

    private var selectedTemplate: CustomGestureTemplate? {
        store.customGestureTemplates.first { $0.id == selectedTemplateID }
    }

    private var selectedPreset: GesturePreset? {
        store.presets.first { $0.id == selectedPresetID }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { presentedError != nil },
            set: { if !$0 { presentedError = nil } }
        )
    }
}

private enum LibraryTab: String, CaseIterable, Identifiable {
    case gestures
    case presets

    var id: Self { self }
    var title: String {
        switch self {
        case .gestures: "Gestos gravados"
        case .presets: "Presets"
        }
    }
}

