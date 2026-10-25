import SwiftUI

/// Parâmetros essenciais da ação escolhida. O texto de URL pode estar incompleto
/// durante a digitação, mas nunca deixa uma URL antiga válida no rascunho.
struct ComposerActionParameters: View {
    @Binding var action: ShortcutAction
    let applications: [ApplicationChoice]
    let macOSShortcuts: [String]
    let showsSelectionTiming: Bool
    @State private var urlDraft = ""
    @FocusState private var urlIsFocused: Bool

    var body: some View {
        Group {
            switch action {
            case .openApplication:
                Label("O app será aberto quando você usar este atalho.", systemImage: "checkmark.circle")
                    .font(.callout).foregroundStyle(.secondary)
            case .openURL:
                VStack(alignment: .leading, spacing: 10) {
                    Text("Qual site você quer abrir?").font(.callout.weight(.medium))
                    TextField("https://", text: urlText)
                        .textFieldStyle(.roundedBorder).controlSize(.large)
                        .focused($urlIsFocused)
                        .accessibilityLabel("Endereço do site")
                        .accessibilityIdentifier("tico.composer.url")
                    Text("Informe o endereço completo do destino.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            default:
                RuleActionEditorView(action: $action, urlText: urlText, applications: applications,
                    macOSShortcuts: macOSShortcuts, showsSelectionTiming: showsSelectionTiming,
                    showsActionHeader: false)
            }
        }
        .onAppear { synchronizeURL(); focusIncompleteURL() }
        .onChange(of: RuleActionKind(action: action)) {
            synchronizeURL()
            focusIncompleteURL()
        }
        .onChange(of: action) { synchronizeURL() }
    }

    private var urlText: Binding<String> {
        Binding(get: { urlDraft }, set: {
            urlDraft = $0
            action = .openURL(url: representedURL($0))
        })
    }

    private func representedURL(_ value: String) -> URL {
        URL(string: value) ?? URL(fileURLWithPath: "/")
    }

    private func synchronizeURL() {
        guard case let .openURL(url) = action, representedURL(urlDraft) != url else { return }
        urlDraft = url.absoluteString
    }

    private func focusIncompleteURL() {
        if case let .openURL(url) = action, url.absoluteString.isEmpty { urlIsFocused = true }
    }
}
