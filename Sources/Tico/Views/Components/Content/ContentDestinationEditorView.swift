import SwiftUI

/// Compartilha a escolha de intenção entre regras e receitas manuais. As opções
/// conhecidas preenchem a configuração; somente "Outro site" expõe a sintaxe.
struct ContentDestinationEditorView: View {
    @Binding var destination: ContentActionDestination
    let macOSShortcuts: [String]
    @State private var intent: ContentRecipeIntent

    init(destination: Binding<ContentActionDestination>, macOSShortcuts: [String]) {
        _destination = destination
        self.macOSShortcuts = macOSShortcuts
        _intent = State(initialValue: ContentRecipeIntent(destination: destination.wrappedValue))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("O que você quer fazer?").font(.headline)
            // O grid conserva as opções e o rascunho quando passa a uma coluna.
            // Paralelo com React: auto-fit com largura mínima, sem remontar o formulário.
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 8)], spacing: 8) {
                ForEach(ContentRecipeIntent.allCases) { option in
                    EditorChoiceButton(title: option.title, symbol: option.symbol, isSelected: intent == option) {
                        if intent != option {
                            intent = option
                            destination = option.destination
                        }
                    }
                }
            }
            switch destination {
            case let .search(search):
                if intent == .custom {
                    ContentSearchDestinationFields(search: search) { destination = .search($0) }
                }
            case let .macOSShortcut(name):
                ContentShortcutDestinationFields(name: name, shortcuts: macOSShortcuts) {
                    destination = .macOSShortcut(name: $0)
                }
            }
            if destinationIsValid {
                Label(destination.deliverySummary, systemImage: "arrow.up.forward")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .onChange(of: destination) { _, value in
            // Digitar um endpoint conhecido em "Outro site" não pode desmontar
            // os campos no meio da edição. O modo é estado efêmero do editor.
            if intent == .custom, case .search = value { return }
            intent = ContentRecipeIntent(destination: value)
        }
    }

    private var destinationIsValid: Bool {
        ContentActionConfiguration(source: .provided, destination: destination).validationMessage == nil
    }
}

private struct ContentSearchDestinationFields: View {
    let search: ContentSearchDestination
    let onChange: (ContentSearchDestination) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Endereço de pesquisa").font(.callout.weight(.medium))
                TextField("https://exemplo.com/busca", text: Binding(
                    get: { search.endpoint },
                    set: { onChange(.init(endpoint: $0, queryParameter: search.queryParameter)) }))
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text("Parâmetro do termo").font(.callout.weight(.medium))
                TextField("q", text: Binding(
                    get: { search.queryParameter },
                    set: { onChange(.init(endpoint: search.endpoint, queryParameter: $0)) }))
                    .textFieldStyle(.roundedBorder)
                Text("Em “?q=palavra”, o parâmetro é q. O Tico codifica o termo automaticamente.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !search.endpoint.isEmpty, let issue = search.validationMessage {
                Label(issue, systemImage: "info.circle").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct ContentShortcutDestinationFields: View {
    let name: String
    let shortcuts: [String]
    let onChange: (String) -> Void

    private var matches: [String] {
        shortcuts.filter { name.isEmpty || $0.localizedStandardContains(name) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Qual Atalho recebe o conteúdo?").font(.callout.weight(.medium))
            TextField("Buscar ou digitar o nome exato", text: Binding(get: { name }, set: onChange))
                .textFieldStyle(.roundedBorder)
            if !matches.isEmpty {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(matches, id: \.self) { shortcut in
                            EditorChoiceButton(title: shortcut, symbol: "square.stack.3d.up",
                                               isSelected: name == shortcut) { onChange(shortcut) }
                        }
                    }
                }.frame(maxHeight: 150)
            }
            Text("Use um Atalho do macOS preparado para receber texto, links ou arquivos.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
