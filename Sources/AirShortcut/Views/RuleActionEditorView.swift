import SwiftUI

struct RuleActionEditorView: View {
    @Binding var action: ShortcutAction
    @Binding var urlText: String
    let applications: [ApplicationChoice]
    var macOSShortcuts: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Tipo de ação", selection: actionKind) {
                ForEach(RuleActionKind.allCases) { kind in
                    Label(kind.title, systemImage: kind.systemImage).tag(kind)
                }
            }
            fields
        }
    }

    @ViewBuilder
    private var fields: some View {
        switch action {
        case let .openApplication(bundleIdentifier):
            Picker("Aplicativo", selection: Binding(
                get: { bundleIdentifier },
                set: { action = .openApplication(bundleIdentifier: $0) }
            )) {
                ForEach(applications) { application in
                    Text(application.name).tag(application.bundleIdentifier)
                }
            }
            Text("O \(TicoBrand.displayName) usa o identificador do app automaticamente.")
                .font(.caption)
                .foregroundStyle(.secondary)

        case .openURL:
            TextField("URL", text: $urlText)
            if !urlIsValid {
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
            if !macOSShortcuts.isEmpty {
                Picker("Atalho", selection: Binding(
                    get: { name },
                    set: { action = .macOSShortcut(name: $0, input: input) }
                )) {
                    if !name.isEmpty, !macOSShortcuts.contains(name) {
                        Text("\(name) · não encontrado").tag(name)
                    }
                    ForEach(macOSShortcuts, id: \.self) { shortcut in
                        Text(shortcut).tag(shortcut)
                    }
                }
            }
            TextField("Nome do Atalho", text: Binding(
                get: { name },
                set: { action = .macOSShortcut(name: $0, input: input) }
            ))
            TextField("Entrada opcional", text: Binding(
                get: { input ?? "" },
                set: { action = .macOSShortcut(name: name, input: $0.isEmpty ? nil : $0) }
            ), axis: .vertical)
                .lineLimit(2...5)
            Text("Use exatamente o nome exibido no app Atalhos.")
                .font(.caption)
                .foregroundStyle(.secondary)

        case let .keyboardShortcut(keyCode, modifiers):
            Stepper(
                "Código da tecla: \(keyCode)",
                value: Binding(
                    get: { keyCode },
                    set: { action = .keyboardShortcut(keyCode: $0, modifiers: modifiers) }
                ),
                in: 0...255
            )
            HStack {
                ForEach(InputModifier.allCases, id: \.self) { modifier in
                    Toggle(modifier.symbol, isOn: Binding(
                        get: { modifiers.contains(modifier) },
                        set: { enabled in
                            var value = modifiers
                            if enabled { value.insert(modifier) } else { value.remove(modifier) }
                            action = .keyboardShortcut(keyCode: keyCode, modifiers: value)
                        }
                    ))
                    .toggleStyle(.button)
                    .help(modifier.displayName)
                }
            }

        case let .setClipboard(text):
            TextField("Texto", text: Binding(
                get: { text },
                set: { action = .setClipboard(text: $0) }
            ), axis: .vertical)
                .lineLimit(2...6)

        case let .application(target, operation):
            Picker("Operação", selection: Binding(
                get: { operation },
                set: { newOperation in
                    let newTarget: ApplicationTarget
                    if newOperation == .open, case .frontmost = target {
                        newTarget = .bundleIdentifier(
                            applications.first?.bundleIdentifier ?? "com.apple.Safari"
                        )
                    } else {
                        newTarget = target
                    }
                    action = .application(target: newTarget, operation: newOperation)
                }
            )) {
                ForEach(ApplicationOperation.allCases, id: \.self) {
                    Text($0.displayName).tag($0)
                }
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
            Picker("Organização da janela", selection: Binding(
                get: { operation },
                set: { action = .window(target: target, operation: $0) }
            )) {
                ForEach(WindowOperation.allCases, id: \.self) {
                    Text($0.displayName).tag($0)
                }
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
            }
            Picker("Curva", selection: Binding(
                get: { curve },
                set: { action = .continuousWindow(target: target, operation: operation, curve: $0) }
            )) {
                ForEach(ContinuousResponseCurve.allCases, id: \.self) {
                    Text($0.displayName).tag($0)
                }
            }
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

    private var actionKind: Binding<RuleActionKind> {
        Binding(
            get: {
                switch action {
                case .openApplication: .openApplication
                case .openURL: .openURL
                case .notification: .notification
                case .shellScript: .shellScript
                case .appleScript: .appleScript
                case .macOSShortcut: .macOSShortcut
                case .keyboardShortcut: .keyboardShortcut
                case .setClipboard: .clipboard
                case .application: .controlApplication
                case .window: .controlWindow
                case .continuousWindow: .continuousWindow
                }
            },
            set: { kind in
                switch kind {
                case .openApplication:
                    action = .openApplication(
                        bundleIdentifier: applications.first?.bundleIdentifier ?? "com.apple.Safari"
                    )
                case .controlApplication:
                    action = .application(target: .frontmost, operation: .activate)
                case .controlWindow:
                    action = .window(target: .frontmost, operation: .leftHalf)
                case .openURL:
                    urlText = "https://"
                    action = .openURL(url: URL(string: "https://example.com")!)
                case .notification:
                    action = .notification(title: TicoBrand.displayName, body: "Regra executada")
                case .shellScript:
                    action = .shellScript(command: "")
                case .appleScript:
                    action = .appleScript(source: "tell application \"Finder\"\nactivate\nend tell")
                case .macOSShortcut:
                    action = .macOSShortcut(name: "", input: nil)
                case .keyboardShortcut:
                    action = .keyboardShortcut(keyCode: 49, modifiers: [.command])
                case .clipboard:
                    action = .setClipboard(text: "")
                case .continuousWindow:
                    action = .continuousWindow(
                        target: .frontmost,
                        operation: .moveHorizontal,
                        curve: .linear
                    )
                }
            }
        )
    }

    private var urlIsValid: Bool {
        RuleURLValidator.isValidWebURL(urlText)
    }
}

private enum RuleActionKind: String, CaseIterable, Identifiable {
    case openApplication
    case controlApplication
    case controlWindow
    case openURL
    case notification
    case shellScript
    case appleScript
    case macOSShortcut
    case keyboardShortcut
    case clipboard
    case continuousWindow

    var id: Self { self }

    var title: String {
        switch self {
        case .openApplication: "Abrir aplicativo"
        case .controlApplication: "Controlar aplicativo"
        case .controlWindow: "Organizar janela"
        case .openURL: "Abrir URL"
        case .notification: "Mostrar notificação"
        case .shellScript: "Executar script"
        case .appleScript: "Executar AppleScript"
        case .macOSShortcut: "Executar Atalho do macOS"
        case .keyboardShortcut: "Enviar atalho de teclado"
        case .clipboard: "Atualizar clipboard"
        case .continuousWindow: "Controlar janela continuamente"
        }
    }

    var systemImage: String {
        switch self {
        case .openApplication: "app.badge"
        case .controlApplication: "app.dashed"
        case .controlWindow: "macwindow.on.rectangle"
        case .openURL: "link"
        case .notification: "bell"
        case .shellScript: "terminal"
        case .appleScript: "applescript"
        case .macOSShortcut: "square.stack.3d.up.fill"
        case .keyboardShortcut: "keyboard"
        case .clipboard: "doc.on.clipboard"
        case .continuousWindow: "arrow.up.left.and.arrow.down.right"
        }
    }
}
