import SwiftUI

/// Galeria de resultados, compartilhada por adicionar e substituir ações.
/// Entrega a ação completa: escolher Safari já significa abrir Safari. Navegar,
/// pesquisar e cancelar nunca modificam a regra ou executam o que está na galeria.
struct RuleActionPickerView: View {
    let applications: [ApplicationChoice]
    let onSelect: (ShortcutAction) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    @State private var showsAllApplications = false
    @State private var showsAdvanced = false
    @FocusState private var searchIsFocused: Bool

    private var applicationQuery: String {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.lowercased().hasPrefix("abrir ") ? String(query.dropFirst(6)) : query
    }
    private var visibleApplications: [ApplicationChoice] {
        applications.filter { applicationQuery.isEmpty || $0.name.localizedStandardContains(applicationQuery) || "abrir aplicativo app".localizedStandardContains(applicationQuery) }
            .sorted {
                if $0.isRunning != $1.isRunning { return $0.isRunning }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }
    private var visibleKinds: [RuleActionKind] {
        RuleActionKind.allCases.filter {
            ![.openApplication, .controlApplication, .controlWindow].contains($0) &&
            (search.isEmpty || ($0.title + " " + $0.summary).localizedStandardContains(search))
        }
    }
    private var visibleWindows: [WindowOperation] {
        WindowOperation.allCases.filter {
            search.isEmpty ? WindowActionChoices.common.contains($0) :
                ("janela " + $0.displayName).localizedStandardContains(search)
        }
    }
    private var visibleOperations: [ApplicationOperation] {
        ApplicationOperation.allCases.filter {
            $0 != .open && (search.isEmpty || ($0.displayName + " app aplicativo em uso").localizedStandardContains(search))
        }
    }
    private var visibleKeyboardPresets: [KeyboardActionPreset] {
        KeyboardActionPreset.allCases.filter {
            search.isEmpty || ("teclado " + $0.title).localizedStandardContains(search)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("O que você quer fazer?").font(.title2.bold())
                    Text("Escolha o app ou o resultado desejado.").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancelar") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            TextField("Buscar: Safari, metade esquerda, copiar…", text: $search)
                .textFieldStyle(.roundedBorder).controlSize(.large)
                .focused($searchIsFocused).accessibilityIdentifier("tico.action.search")
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !visibleApplications.isEmpty {
                        sectionTitle("Abrir um aplicativo")
                        ApplicationChoiceGrid(applications: Array(visibleApplications.prefix(showsAllApplications ? visibleApplications.count : 7)),
                                              opensApplication: true) {
                            choose(.openApplication(bundleIdentifier: $0))
                        }
                        if visibleApplications.count > 7 {
                            Button(showsAllApplications ? "Mostrar menos aplicativos" : "Ver todos os aplicativos") {
                                showsAllApplications.toggle()
                            }.buttonStyle(.borderless)
                        }
                    }
                    if !visibleWindows.isEmpty {
                        sectionTitle("Organizar a janela em uso")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                            ForEach(visibleWindows, id: \.self) { operation in
                                Button { choose(.window(target: .frontmost, operation: operation)) } label: {
                                    HStack(spacing: 10) {
                                        WindowPlacementPreview(operation: operation)
                                        Text(WindowActionChoices.title(operation)).font(.callout).lineLimit(2)
                                        Spacer(minLength: 0)
                                    }.padding(10).frame(maxWidth: .infinity, minHeight: 55)
                                        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 8))
                                        .contentShape(Rectangle())
                                }.buttonStyle(.plain).accessibilityLabel(operation.displayName)
                            }
                        }
                    }
                    if !visibleOperations.isEmpty {
                        sectionTitle("Aplicativo em uso")
                        HStack {
                            ForEach(visibleOperations, id: \.self) { operation in
                                EditorChoiceButton(title: operation.displayName,
                                                   symbol: ApplicationOperationChoices.symbol(operation)) {
                                    choose(.application(target: .frontmost, operation: operation))
                                }
                            }
                        }
                    }
                    if !visibleKeyboardPresets.isEmpty {
                        sectionTitle("Edição e teclado")
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(visibleKeyboardPresets) { preset in
                                EditorChoiceButton(title: preset.title, symbol: preset.symbol) {
                                    choose(preset.action)
                                }
                            }
                        }
                    }
                    kinds(visibleKinds.filter { !$0.isAdvanced })
                    if visibleKinds.contains(where: \.isAdvanced) {
                        DisclosureGroup("Automação avançada", isExpanded: $showsAdvanced) {
                            kinds(visibleKinds.filter(\.isAdvanced)).padding(.top, 10)
                        }
                    }
                    if visibleApplications.isEmpty && visibleWindows.isEmpty && visibleKinds.isEmpty && visibleOperations.isEmpty && visibleKeyboardPresets.isEmpty {
                        ContentUnavailableView("Nenhuma ação encontrada", systemImage: "magnifyingglass",
                            description: Text("Tente o nome de um aplicativo ou uma ação, como janela ou copiar."))
                    }
                }.padding(.bottom, 8)
            }
            Text("A ação será adicionada ao rascunho. Nada é executado agora.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(22).frame(width: 680, height: 590)
        .onAppear { searchIsFocused = true }
        .onChange(of: search) { showsAllApplications = false; showsAdvanced = !search.isEmpty }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.callout.weight(.semibold)).foregroundStyle(.secondary)
    }
    private func kinds(_ values: [RuleActionKind]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(values) { kind in
                EditorChoiceButton(title: kind.title, symbol: kind.systemImage) {
                    choose(kind.makeAction(applications: applications))
                }.help(kind.summary)
            }
        }
    }
    private func choose(_ action: ShortcutAction) {
        onSelect(action)
        dismiss()
    }
}
