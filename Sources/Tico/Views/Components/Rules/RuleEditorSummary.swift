import Foundation

/// Projeções de apresentação. Os identificadores persistidos e os matchers não mudam.
enum RuleEditorSummary {
    static func symbol(_ trigger: TriggerDefinition) -> String {
        switch trigger {
        case .keyboard: "keyboard"
        case .mouseButton: "computermouse"
        case .trackpad: "hand.draw"
        case .customTrackpad: "scribble.variable"
        case .sequence: "arrow.triangle.branch"
        }
    }

    static let specialKeys: [(code: UInt16, name: String)] = [
        (49, "Espaço"), (36, "Return"), (48, "Tab"), (53, "Esc"), (51, "Apagar"),
        (123, "←"), (124, "→"), (125, "↓"), (126, "↑")
    ]

    static func trigger(_ trigger: TriggerDefinition, keyboardLabels: any KeyboardLabelProviding = KeyboardLabelService()) -> String {
        if case let .keyboard(code, modifiers) = trigger {
            let key = InputPresentation.label(code, provider: keyboardLabels)
            let prefix = InputModifier.allCases.filter { modifiers.contains($0) }.map(\.symbol).joined()
            return prefix.isEmpty ? key : "\(prefix) \(key)"
        }
        if case let .mouseButton(button, modifiers) = trigger {
            let prefix = InputModifier.allCases.filter(modifiers.contains).map(\.symbol).joined()
            return prefix + (prefix.isEmpty ? "" : " ") + InputPresentation.mouseLabel(button)
        }
        if case let .sequence(sequence) = trigger {
            return sequence.steps.map { Self.trigger($0.triggerDefinition, keyboardLabels: keyboardLabels) }.joined(separator: " → ")
        }
        return trigger.displayName
    }

    static func action(_ action: ShortcutAction, applications: [ApplicationChoice]) -> String {
        switch action {
        case let .openApplication(id):
            return "Abrir \(appName(id, applications: applications))"
        case let .openURL(url):
            guard let host = url.host else { return "Abrir um site" }
            return "Abrir \(host)\(url.path == "/" ? "" : url.path)"
        case let .macOSShortcut(name, _):
            return name.isEmpty ? "Escolher um Atalho do macOS" : "Executar “\(name)” no Atalhos"
        case let .content(configuration):
            let input = configuration.source == .selection ? "texto selecionado" : "conteúdo do painel"
            switch configuration.destination {
            case let .search(destination):
                return "Pesquisar \(input) em \(searchDestination(destination))"
            case let .macOSShortcut(name):
                return name.isEmpty ? "Enviar \(input) a um Atalho" : "Enviar \(input) a “\(name)”"
            }
        case let .window(target, operation):
            return "\(operation.displayName) · \(targetName(target, applications: applications))"
        case let .application(target, operation):
            return "\(operation.displayName) · \(targetName(target, applications: applications, frontmost: "app em uso"))"
        case let .continuousWindow(target, operation, _):
            return "\(operation.displayName) · \(targetName(target, applications: applications))"
        case let .keyboardShortcut(code, modifiers):
            return "Pressionar \(trigger(.keyboard(keyCode: code, modifiers: modifiers)))"
        default: return action.displayName
        }
    }

    /// Mostra um destino reconhecível, sem trazer parâmetros técnicos da busca
    /// para a frase do usuário. A configuração completa permanece no editor.
    private static func searchDestination(_ destination: ContentSearchDestination) -> String {
        if destination == .documentation { return "Documentação Apple" }
        if destination == .web { return "Google" }
        return URL(string: destination.endpoint)?.host ?? "um site a configurar"
    }

    static func scope(_ scope: RuleScope, applications: [ApplicationChoice]) -> String {
        guard case let .applications(ids) = scope else { return "Em qualquer aplicativo" }
        return ids.isEmpty ? "Escolha pelo menos um aplicativo" : "Em " + ids.map { appName($0, applications: applications) }.sorted().joined(separator: ", ")
    }

    static func appName(_ id: String, applications: [ApplicationChoice]) -> String {
        guard !id.isEmpty else { return "Escolher aplicativo" }
        return applications.first { $0.bundleIdentifier == id }?.name ?? id
    }

    private static func targetName(_ target: ApplicationTarget, applications: [ApplicationChoice],
                                   frontmost: String = "janela em uso") -> String {
        switch target {
        case .frontmost: frontmost
        case let .bundleIdentifier(id): appName(id, applications: applications)
        }
    }
}
