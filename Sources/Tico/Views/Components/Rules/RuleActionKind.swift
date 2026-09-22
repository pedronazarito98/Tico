import Foundation

/// Opções de apresentação do seletor de ações; não altera o modelo persistido.
enum RuleActionKind: String, CaseIterable, Identifiable {
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

    init(action: ShortcutAction) {
        switch action {
        case .openApplication: self = .openApplication
        case .openURL: self = .openURL
        case .notification: self = .notification
        case .shellScript: self = .shellScript
        case .appleScript: self = .appleScript
        case .macOSShortcut: self = .macOSShortcut
        case .keyboardShortcut: self = .keyboardShortcut
        case .setClipboard: self = .clipboard
        case .application: self = .controlApplication
        case .window: self = .controlWindow
        case .continuousWindow: self = .continuousWindow
        }
    }

    var isAdvanced: Bool { [.shellScript, .appleScript, .continuousWindow].contains(self) }

    var summary: String {
        switch self {
        case .openApplication: "Deixe um app pronto para usar."
        case .controlApplication: "Ative, oculte ou encerre um app."
        case .controlWindow: "Metade da tela, centralizar e mais."
        case .openURL: "Abra um site ou endereço."
        case .notification: "Mostre uma mensagem no Mac."
        case .shellScript: "Execute um comando com aprovação."
        case .appleScript: "Automatize apps com aprovação."
        case .macOSShortcut: "Use uma rotina do app Atalhos."
        case .keyboardShortcut: "Envie uma combinação de teclas."
        case .clipboard: "Prepare um texto para colar."
        case .continuousWindow: "Mova a janela acompanhando o gesto."
        }
    }

    func makeAction(applications: [ApplicationChoice]) -> ShortcutAction {
        switch self {
        case .openApplication: .openApplication(bundleIdentifier: applications.first?.bundleIdentifier ?? "com.apple.Safari")
        case .controlApplication: .application(target: .frontmost, operation: .activate)
        case .controlWindow: .window(target: .frontmost, operation: .leftHalf)
        case .openURL: .openURL(url: URL(string: "https://example.com") ?? URL(fileURLWithPath: "/"))
        case .notification: .notification(title: TicoBrand.displayName, body: "Regra executada")
        case .shellScript: .shellScript(command: "")
        case .appleScript: .appleScript(source: "tell application \"Finder\"\nactivate\nend tell")
        case .macOSShortcut: .macOSShortcut(name: "", input: nil)
        case .keyboardShortcut: .keyboardShortcut(keyCode: 49, modifiers: [.command])
        case .clipboard: .setClipboard(text: "")
        case .continuousWindow: .continuousWindow(target: .frontmost, operation: .moveHorizontal, curve: .linear)
        }
    }

    var title: String {
        switch self {
        case .openApplication: "Abrir aplicativo"
        case .controlApplication: "Controlar aplicativo"
        case .controlWindow: "Organizar janela"
        case .openURL: "Abrir link"
        case .notification: "Mostrar notificação"
        case .shellScript: "Executar script"
        case .appleScript: "Executar AppleScript"
        case .macOSShortcut: "Executar Atalho do macOS"
        case .keyboardShortcut: "Enviar atalho de teclado"
        case .clipboard: "Copiar texto"
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
