import Foundation
import FoundationModels

/// DTO exclusivo da fronteira Apple. A geração guiada limita a estrutura; o
/// parser existente ainda valida os valores e resolve apps no catálogo local.
/// Paralelo com React: schema de resposta separado do modelo salvo do formulário.
@Generable
struct GeneratedAutomationProposal {
    @Guide(description: "swipeLeft/right/up/down for deslizar/arrastar/swipe; tap for tocar/toque; recorded ONLY for 'este gesto'; unspecified if missing.")
    var trigger: Gesture
    @Guide(description: "Explicit finger count, 2 to 5. Nil if missing; never guess.")
    var fingers: Int?
    @Guide(description: "Exact application name from the request, or 'qualquer aplicativo' ONLY for explicitly global scope. Nil if missing.")
    var application: String?
    @Guide(description: "leftHalf/rightHalf=metade esquerda/direita; maximize=maximizar; center=centralizar; reopenLastTab=reabrir aba; reloadPage=atualizar ou recarregar página/janela; openApplication=abrir app; openURL=abrir link; unspecified if missing.")
    var action: Action
    @Guide(description: "Exact target app name or complete HTTP(S) URL copied from the request for open actions. Otherwise nil.")
    var target: String?
    // Gerado por último para que a classificação considere os campos extraídos.
    @Guide(description: "True for a single supported automation (including window positioning). False ONLY for unsupported actions, extra conditions or multiple steps.")
    var isSupported: Bool

    @Generable
    enum Gesture { case swipeLeft, swipeRight, swipeUp, swipeDown, tap, recorded, unspecified }

    @Generable
    enum Action { case leftHalf, rightHalf, maximize, center, reopenLastTab, reloadPage, openApplication, openURL, unspecified }

    func makeRule(applications: [ApplicationChoice], recordedTrigger: TriggerDefinition?, source: String) throws -> ShortcutRule {
        guard trigger != .unspecified, action != .unspecified else {
            throw LocalIntelligenceError.incompleteAutomation
        }
        guard isSupported else { throw LocalIntelligenceError.unsupportedAutomation }
        guard let application, !application.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !application.contains(","), !application.contains("\n") else {
            throw LocalIntelligenceError.incompleteAutomation
        }
        let gesture: String
        switch trigger {
        case .recorded:
            guard recordedTrigger != nil else { throw AutomationDraftParser.DraftError.missingGesture }
            gesture = "este gesto"
        case .unspecified: throw LocalIntelligenceError.incompleteAutomation
        default:
            guard let fingers, (2...5).contains(fingers) else { throw LocalIntelligenceError.incompleteAutomation }
            switch trigger {
            case .swipeLeft: gesture = "um swipe para a esquerda com \(fingers) dedos"
            case .swipeRight: gesture = "um swipe para a direita com \(fingers) dedos"
            case .swipeUp: gesture = "um swipe para cima com \(fingers) dedos"
            case .swipeDown: gesture = "um swipe para baixo com \(fingers) dedos"
            case .tap: gesture = "um toque com \(fingers) dedos"
            default: throw LocalIntelligenceError.invalidProposal
            }
        }
        let result: String
        switch action {
        case .leftHalf: result = "coloque a janela na metade esquerda"
        case .rightHalf: result = "coloque a janela na metade direita"
        case .maximize: result = "maximize a janela"
        case .center: result = "centralize a janela"
        case .reopenLastTab: result = "reabra a última aba"
        case .reloadPage: result = "recarregue a página"
        case .unspecified: throw LocalIntelligenceError.incompleteAutomation
        case .openApplication, .openURL:
            guard let target, !target.isEmpty, !target.contains("\n") else {
                throw LocalIntelligenceError.incompleteAutomation
            }
            if action == .openURL {
                // O modelo não pode inventar ou alterar um endereço de destino.
                let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
                let links = detector.matches(in: source, range: NSRange(source.startIndex..., in: source))
                guard links.contains(where: { match in
                    guard let range = Range(match.range, in: source) else { return false }
                    return String(source[range]) == target
                }) else { throw LocalIntelligenceError.invalidProposal }
                result = "abra \(target)"
            } else { result = "abra o \(target)" }
        }
        var rule = try AutomationDraftParser().parse(
            "Quando eu fizer \(gesture) em \(application), \(result)",
            applications: applications, recordedTrigger: recordedTrigger)
        // O parser manual conserva a frase em notes. Uma inferência não deve
        // persistir o prompt, nem mesmo quando a pessoa salvar a regra revisada.
        rule.notes = ""
        rule.isEnabled = false
        return rule
    }
}
