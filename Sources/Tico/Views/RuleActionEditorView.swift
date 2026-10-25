import SwiftUI

struct RuleActionEditorView: View {
    @Binding var action: ShortcutAction
    @Binding var urlText: String
    let applications: [ApplicationChoice]
    var macOSShortcuts: [String] = []
    var showsSelectionTiming = false
    var showsActionHeader = true
    @State private var showsActionPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsActionHeader {
                HStack {
                    Label(RuleActionKind(action: action).title, systemImage: RuleActionKind(action: action).systemImage)
                        .font(.body.weight(.medium))
                    Spacer()
                    Button("Trocar ação") { showsActionPicker = true }.buttonStyle(.borderless)
                }
            }
            fields
        }
        .sheet(isPresented: $showsActionPicker) {
            RuleActionPickerView(applications: applications) { action = $0 }
        }
    }

    @ViewBuilder
    private var fields: some View {
        switch action {
        case let .openApplication(bundleIdentifier):
            ApplicationSearchPicker(selection: Binding(
                get: { bundleIdentifier },
                set: { action = .openApplication(bundleIdentifier: $0) }
            ), applications: applications)

        case .openURL:
            Text("Qual site você quer abrir?").font(.headline)
            TextField("https://…", text: $urlText).textFieldStyle(.roundedBorder)
                .accessibilityLabel("Endereço do site")
            if !urlText.isEmpty && !urlIsValid {
                Text("Informe uma URL completa, incluindo https://")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

        case let .notification(title, body):
            TextField("Título", text: Binding(
                get: { title },
                set: { action = .notification(title: $0, body: body) }
            ))
            TextField("Mensagem", text: Binding(
                get: { body },
                set: { action = .notification(title: title, body: $0) }
            ), axis: .vertical)
                .lineLimit(2...4)

        case let .shellScript(command):
            TextField("Comando", text: Binding(
                get: { command },
                set: { action = .shellScript(command: $0) }
            ), axis: .vertical)
                .font(.system(.body, design: .monospaced))
                .lineLimit(3...8)
            Label("Scripts exigem confirmação antes da execução.", systemImage: "exclamationmark.shield")
                .font(.caption)
                .foregroundStyle(.secondary)

        case let .appleScript(source):
            TextField("AppleScript", text: Binding(
                get: { source },
                set: { action = .appleScript(source: $0) }
            ), axis: .vertical)
                .font(.system(.body, design: .monospaced))
                .lineLimit(4...10)
            Label("O conteúdo exato exige confirmação antes da primeira execução.", systemImage: "exclamationmark.shield")
                .font(.caption)
                .foregroundStyle(.secondary)

        case let .macOSShortcut(name, input):
            TextField("Buscar ou digitar o nome do Atalho", text: Binding(
                get: { name },
                set: { action = .macOSShortcut(name: $0, input: input) }
            ))
            ForEach(macOSShortcuts.filter { name.isEmpty || $0.localizedStandardContains(name) }.prefix(6), id: \.self) { shortcut in
                EditorChoiceButton(title: shortcut, symbol: "square.stack.3d.up.fill", isSelected: name == shortcut) {
                    action = .macOSShortcut(name: shortcut, input: input)
                }
            }
            TextField("Entrada opcional", text: Binding(
                get: { input ?? "" },
                set: { action = .macOSShortcut(name: name, input: $0.isEmpty ? nil : $0) }
            ), axis: .vertical)
                .lineLimit(2...5)
            Text("Use exatamente o nome exibido no app Atalhos.")
                .font(.caption)
                .foregroundStyle(.secondary)

        case let .content(configuration):
            ContentActionEditorView(configuration: Binding(
                get: { configuration },
                set: { action = .content($0) }
            ), macOSShortcuts: macOSShortcuts, showsSelectionTiming: showsSelectionTiming)

        case let .keyboardShortcut(keyCode, modifiers):
            KeyboardActionChoices(keyCode: keyCode, modifiers: modifiers) { code, flags in
                action = .keyboardShortcut(keyCode: code, modifiers: flags)
            }

        case let .setClipboard(text):
            TextField("Texto", text: Binding(
                get: { text },
                set: { action = .setClipboard(text: $0) }
            ), axis: .vertical)
                .lineLimit(2...6)

        case let .application(target, operation):
            ApplicationOperationChoices(operation: operation) { newOperation in
                let newTarget: ApplicationTarget = newOperation == .open && target == .frontmost
                    ? .bundleIdentifier("") : target
                action = .application(target: newTarget, operation: newOperation)
            }
            ApplicationTargetPicker(
                target: Binding(
                    get: { target },
                    set: { action = .application(target: $0, operation: operation) }
                ),
                applications: applications,
                allowsFrontmost: operation != .open
            )

        case let .window(target, operation):
            WindowActionChoices(operation: operation) {
                action = .window(target: target, operation: $0)
            }
            ApplicationTargetPicker(
                target: Binding(
                    get: { target },
                    set: { action = .window(target: $0, operation: operation) }
                ),
                applications: applications
            )
            Label(
                "Controle de janelas usa a permissão de Acessibilidade.",
                systemImage: "accessibility"
            )
            .font(.caption)
            .foregroundStyle(.secondary)

        case let .continuousWindow(target, operation, curve):
            Picker("Controle contínuo", selection: Binding(
                get: { operation },
                set: { action = .continuousWindow(target: target, operation: $0, curve: curve) }
            )) {
                ForEach(ContinuousWindowOperation.allCases, id: \.self) {
                    Text($0.displayName).tag($0)
                }
            }.pickerStyle(.radioGroup)
            Picker("Resposta ao movimento", selection: Binding(
                get: { curve },
                set: { action = .continuousWindow(target: target, operation: operation, curve: $0) }
            )) {
                ForEach(ContinuousResponseCurve.allCases, id: \.self) {
                    Text($0.displayName).tag($0)
                }
            }.pickerStyle(.segmented)
            ApplicationTargetPicker(
                target: Binding(
                    get: { target },
                    set: { action = .continuousWindow(target: $0, operation: operation, curve: curve) }
                ),
                applications: applications
            )
            Label("Exige um gesto com fases de movimento e Acessibilidade.", systemImage: "waveform.path")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var urlIsValid: Bool {
        RuleURLValidator.isValidWebURL(urlText)
    }
}
