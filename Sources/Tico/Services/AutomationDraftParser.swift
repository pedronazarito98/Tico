import Foundation

/// Gramática local e deliberadamente limitada. Só produz rascunhos desativados;
/// texto não reconhecido nunca é convertido em código ou executado parcialmente.
struct AutomationDraftParser {
    enum DraftError: LocalizedError {
        case invalidSentence, unsupportedTrigger, missingGesture, unknownApplication, unsupportedAction
        var errorDescription: String? {
            switch self {
            case .invalidSentence:
                "Use: Quando eu fizer [gesto] no [aplicativo], [ação]."
            case .unsupportedTrigger:
                "Descreva um swipe para esquerda/direita/cima/baixo com 2–5 dedos, um toque com 2–5 dedos, ou use ‘este gesto’ e grave o gatilho."
            case .missingGesture:
                "Grave o gatilho que você chamou de ‘este gesto’ antes de montar o rascunho."
            case .unknownApplication:
                "Não identifiquei um único aplicativo com esse nome. Use o nome completo de um app instalado ou ‘qualquer aplicativo’."
            case .unsupportedAction:
                "Ações suportadas: coloque a janela na metade esquerda/direita, maximize a janela, centralize a janela, reabra a última aba, abra o [aplicativo] ou abra [link https]."
            }
        }
    }

    func parse(_ text: String, applications: [ApplicationChoice], recordedTrigger: TriggerDefinition?) throws -> ShortcutRule {
        guard text.count <= 1_000 else { throw DraftError.invalidSentence }
        let sentence = normalize(text).trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        guard let fields = captures("^quando eu fizer (.+) (?:no|na|em) (.+),\\s*(.+)$", in: sentence) else {
            throw DraftError.invalidSentence
        }
        let trigger = try parseTrigger(fields[0], recorded: recordedTrigger)
        let scope: RuleScope = fields[1] == "qualquer aplicativo" ? .global
            : .applications(bundleIdentifiers: [try applicationID(fields[1], in: applications)])
        let action: ShortcutAction
        if fields[2].hasPrefix("abra https://") || fields[2].hasPrefix("abra http://") {
            guard let comma = text.firstIndex(of: ",") else { throw DraftError.invalidSentence }
            let originalAction = text[text.index(after: comma)...].trimmingCharacters(in: .whitespacesAndNewlines)
            let originalURL = String(originalAction.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: originalURL), RuleURLValidator.isValidWebURL(url),
                  let host = url.host, !host.isEmpty, url.user == nil, url.password == nil,
                  !originalURL.contains(where: \.isWhitespace) else { throw DraftError.unsupportedAction }
            action = .openURL(url: url)
        } else {
            action = try parseAction(fields[2], applications: applications)
        }
        return ShortcutRule(name: action.displayName, isEnabled: false, trigger: trigger,
                            action: action, scope: scope, notes: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func parseTrigger(_ text: String, recorded: TriggerDefinition?) throws -> TriggerDefinition {
        if text == "este gesto" {
            guard let recorded else { throw DraftError.missingGesture }
            return recorded
        }
        if let parts = captures("^(?:um )?(?:swipe|deslizamento) para (?:a |o )?(esquerda|direita|cima|baixo) com ([2-5]) dedos$", in: text),
           let count = Int(parts[1]) {
            let directions: [String: TrackpadGesture] = ["esquerda": .swipeLeft, "direita": .swipeRight,
                                                       "cima": .swipeUp, "baixo": .swipeDown]
            guard let gesture = directions[parts[0]] else { throw DraftError.unsupportedTrigger }
            return .trackpad(gesture: gesture, fingerCount: count)
        }
        if let parts = captures("^(?:um )?toque com ([2-5]) dedos$", in: text), let count = Int(parts[0]) {
            return .trackpad(gesture: .tap, fingerCount: count)
        }
        throw DraftError.unsupportedTrigger
    }

    private func parseAction(_ text: String, applications: [ApplicationChoice]) throws -> ShortcutAction {
        switch text {
        case "coloque a janela na metade esquerda": return .window(target: .frontmost, operation: .leftHalf)
        case "coloque a janela na metade direita": return .window(target: .frontmost, operation: .rightHalf)
        case "maximize a janela": return .window(target: .frontmost, operation: .maximize)
        case "centralize a janela": return .window(target: .frontmost, operation: .center)
        case "reabra a ultima aba": return .keyboardShortcut(keyCode: 17, modifiers: [.command, .shift])
        default:
            if text.hasPrefix("abra o ") {
                return .openApplication(bundleIdentifier: try applicationID(String(text.dropFirst(7)), in: applications))
            }
            // URLs são extraídas da frase original em parse para preservar caixa e acentos.
            throw DraftError.unsupportedAction
        }
    }

    private func applicationID(_ name: String, in applications: [ApplicationChoice]) throws -> String {
        let matches = Set(applications.filter { normalize($0.name) == name }.map(\.bundleIdentifier))
        guard matches.count == 1, let id = matches.first else { throw DraftError.unknownApplication }
        return id
    }

    private func normalize(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func captures(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        return (1..<match.numberOfRanges).compactMap { index in
            Range(match.range(at: index), in: text).map { String(text[$0]) }
        }
    }
}
