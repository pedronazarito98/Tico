import Foundation

/// Escolhas estruturadas da frase. A resolução por identidade evita que nomes
/// iguais de apps produzam uma escolha ambígua. Texto livre continua no parser.
/// Paralelo com React: reducer/form state puro, sem persistência ou efeitos.
struct DescriptionPhraseDraft: Equatable {
    var gesture: DescriptionGestureChoice?
    var fingerCount = 3
    var scopeApplicationID: String?
    var action: DescriptionActionChoice?
    var targetApplicationID = ""
    var targetURL = ""

    func makeRule(applications: [ApplicationChoice], recordedTrigger: TriggerDefinition?) throws -> ShortcutRule {
        guard let gesture else { throw DescriptionPhraseError.missingGesture }
        let trigger: TriggerDefinition
        if gesture == .recorded {
            guard let recordedTrigger else { throw DescriptionPhraseError.recordGesture }
            trigger = recordedTrigger
        } else {
            guard (2...5).contains(fingerCount), let trackpadGesture = gesture.trackpadGesture else {
                throw DescriptionPhraseError.missingGesture
            }
            trigger = .trackpad(gesture: trackpadGesture, fingerCount: fingerCount)
        }
        let scope: RuleScope
        if let scopeApplicationID {
            guard applications.contains(where: { $0.id == scopeApplicationID }) else { throw DescriptionPhraseError.missingApp }
            scope = .applications(bundleIdentifiers: [scopeApplicationID])
        } else { scope = .global }
        guard let action else { throw DescriptionPhraseError.missingAction }
        let result: ShortcutAction
        switch action {
        case .left: result = .window(target: .frontmost, operation: .leftHalf)
        case .right: result = .window(target: .frontmost, operation: .rightHalf)
        case .maximize: result = .window(target: .frontmost, operation: .maximize)
        case .center: result = .window(target: .frontmost, operation: .center)
        case .reopenTab: result = .keyboardShortcut(keyCode: 17, modifiers: [.command, .shift])
        case .openApplication:
            guard applications.contains(where: { $0.id == targetApplicationID }) else { throw DescriptionPhraseError.missingApp }
            result = .openApplication(bundleIdentifier: targetApplicationID)
        case .openURL:
            let value = targetURL.trimmingCharacters(in: .whitespacesAndNewlines)
            guard value.utf8.count <= 8_192, let url = URL(string: value), RuleURLValidator.isValidWebURL(url),
                  let host = url.host, !host.isEmpty, url.user == nil, url.password == nil,
                  !value.contains(where: \.isWhitespace) else { throw DescriptionPhraseError.invalidURL }
            result = .openURL(url: url)
        }
        return ShortcutRule(name: result.displayName, isEnabled: false, trigger: trigger,
                            action: result, scope: scope)
    }

    func gestureTitle(recordedTrigger: TriggerDefinition?) -> String {
        guard let gesture else { return "escolher acionamento" }
        if gesture == .recorded { return recordedTrigger.map { "usar \($0.displayName)" } ?? "usar um acionamento gravado" }
        return "\(gesture.title.lowercased()) com \(fingerCount) dedos"
    }

    func actionTitle(applications: [ApplicationChoice]) -> String {
        switch action {
        case .openApplication:
            let app = applications.first { $0.id == targetApplicationID }
            return app.map { "abrir \($0.name)" } ?? "escolher um aplicativo para abrir"
        case .openURL:
            let host = URL(string: targetURL)?.host
            return host.map { "abrir \($0)" } ?? "escolher um site para abrir"
        case .some(let action): return action.title.lowercased()
        case nil: return "escolher resultado"
        }
    }
}

private enum DescriptionPhraseError: LocalizedError {
    case missingGesture, recordGesture, missingAction, missingApp, invalidURL
    var errorDescription: String? {
        switch self {
        case .missingGesture: "Escolha como você quer acionar o atalho."
        case .recordGesture: "Grave o acionamento ou escolha um dos movimentos disponíveis."
        case .missingAction: "Escolha o resultado que você quer obter."
        case .missingApp: "Escolha um aplicativo disponível neste Mac."
        case .invalidURL: "Informe um endereço HTTP ou HTTPS completo, sem usuário ou senha."
        }
    }
}
