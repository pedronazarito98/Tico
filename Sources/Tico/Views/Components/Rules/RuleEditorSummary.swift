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
            let key = specialKeys.first(where: { $0.code == code })?.name
                ?? keyboardLabels.label(for: code) ?? "Tecla \(code)"
            let prefix = InputModifier.allCases.filter { modifiers.contains($0) }.map(\.symbol).joined()
            return prefix.isEmpty ? key : "\(prefix) \(key)"
        }
        return trigger.displayName
    }

    static func action(_ action: ShortcutAction, applications: [ApplicationChoice]) -> String {
        switch action {
        case let .openApplication(id):
            return "Abrir \(appName(id, applications: applications))"
        case let .window(target, operation):
            return "\(operation.displayName) · \(targetName(target, applications: applications))"
        case let .application(target, operation):
            return "\(operation.displayName) · \(targetName(target, applications: applications))"
        case let .keyboardShortcut(code, modifiers):
            return "Pressionar \(trigger(.keyboard(keyCode: code, modifiers: modifiers)))"
        default: return action.displayName
        }
    }

    static func scope(_ scope: RuleScope, applications: [ApplicationChoice]) -> String {
        guard case let .applications(ids) = scope else { return "Em qualquer aplicativo" }
        return ids.isEmpty ? "Escolha pelo menos um aplicativo" : "Em " + ids.map { appName($0, applications: applications) }.sorted().joined(separator: ", ")
    }

    static func appName(_ id: String, applications: [ApplicationChoice]) -> String {
        guard !id.isEmpty else { return "Escolher aplicativo" }
        return applications.first { $0.bundleIdentifier == id }?.name ?? id
    }

    private static func targetName(_ target: ApplicationTarget, applications: [ApplicationChoice]) -> String {
        switch target {
        case .frontmost: "janela atual"
        case let .bundleIdentifier(id): appName(id, applications: applications)
        }
    }
}
