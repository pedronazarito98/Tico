import ApplicationServices
import Foundation

/// Chamadas AX síncronas usadas exclusivamente pelo actor SceneLayoutService.
/// Timeout por mensagem e limites de inventário evitam espera ilimitada. Nenhum
/// título, seleção, URL ou conteúdo de documento é consultado por esta fronteira.
enum SceneLayoutAccessibility {
    static let messageTimeout: Float = 0.2

    static func windows(for pid: pid_t) throws -> [AXUIElement] {
        let app = AXUIElementCreateApplication(pid)
        try require(AXUIElementSetMessagingTimeout(app, messageTimeout))
        var value: CFTypeRef?
        try require(AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value))
        let windows = value as? [AXUIElement] ?? []
        guard windows.count <= 20 else {
            throw SceneLayoutError.invalid("O aplicativo expõe mais de 20 janelas. Feche algumas antes de preparar a cena.")
        }
        return windows
    }

    /// Unsupported é uma limitação conhecida e pode ser ignorado. Erros de
    /// transporte/timeout não viram ausência de janela: o inventário alvo falha
    /// fechado para não confundir uma janela legível com a única janela do app.
    static func isControllable(_ window: AXUIElement) throws -> Bool {
        try require(AXUIElementSetMessagingTimeout(window, messageTimeout))
        guard try string(kAXSubroleAttribute, from: window) == kAXStandardWindowSubrole,
              try bool(kAXMinimizedAttribute, from: window) != true,
              try bool("AXFullScreen", from: window) != true else { return false }
        return try isSettable(kAXPositionAttribute, on: window) && isSettable(kAXSizeAttribute, on: window)
    }

    static func frame(_ window: AXUIElement) throws -> SceneLayoutRect {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        try require(AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue))
        try require(AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue))
        guard let position = AccessibilityValueDecoder.point(positionValue),
              let size = AccessibilityValueDecoder.size(sizeValue) else { throw SceneLayoutError.unreadableWindow }
        let result = SceneLayoutRect(CGRect(origin: position, size: size))
        guard result.isFinite else { throw SceneLayoutError.unreadableWindow }
        return result
    }

    static func raise(_ window: AXUIElement) throws {
        try require(AXUIElementPerformAction(window, kAXRaiseAction as CFString))
    }

    static func setFrame(_ frame: SceneLayoutRect, on window: AXUIElement, deadline: Date = .distantFuture) throws {
        guard frame.isFinite else { throw SceneLayoutError.unreadableWindow }
        var position = CGPoint(x: frame.x, y: frame.y)
        var size = CGSize(width: frame.width, height: frame.height)
        guard let positionValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size) else { throw SceneLayoutError.unreadableWindow }
        try checkDeadline(deadline)
        try require(AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue))
        try checkDeadline(deadline)
        try require(AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue))
        // Alguns apps limitam tamanho pela tela anterior. Após mover, reaplicamos
        // o tamanho e lemos o resultado real; aceitar a chamada não prova sucesso.
        try checkDeadline(deadline)
        try require(AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue))
    }

    private static func checkDeadline(_ deadline: Date) throws {
        try Task.checkCancellation()
        guard Date() < deadline else { throw SceneLayoutError.invalid("O tempo limite terminou durante o layout; a recuperação foi preservada.") }
    }

    private static func bool(_ attribute: String, from window: AXUIElement) throws -> Bool? {
        guard let value = try optionalValue(attribute, from: window) else { return nil }
        guard let result = value as? Bool else { throw SceneLayoutError.unreadableWindow }
        return result
    }

    private static func string(_ attribute: String, from window: AXUIElement) throws -> String? {
        guard let value = try optionalValue(attribute, from: window) else { return nil }
        guard let result = value as? String else { throw SceneLayoutError.unreadableWindow }
        return result
    }

    private static func optionalValue(_ attribute: String, from window: AXUIElement) throws -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, attribute as CFString, &value)
        if result == .attributeUnsupported || result == .noValue || result == .notImplemented { return nil }
        try require(result)
        return value
    }

    private static func isSettable(_ attribute: String, on window: AXUIElement) throws -> Bool {
        var settable = DarwinBoolean(false)
        let result = AXUIElementIsAttributeSettable(window, attribute as CFString, &settable)
        if result == .attributeUnsupported || result == .notImplemented { return false }
        try require(result)
        return settable.boolValue
    }

    private static func require(_ result: AXError) throws {
        guard result == .success else { throw SceneLayoutError.accessibilityFailure(result.rawValue) }
    }
}

enum SceneLayoutError: LocalizedError {
    case disabled, permissionRequired, unreadableWindow, accessibilityFailure(Int32)
    case invalid(String), stalePreview, changedWindow, changedDisplays, busy, pendingRecovery

    var errorDescription: String? {
        switch self {
        case .disabled: "Layouts indisponíveis durante prática, gravação ou validação isolada."
        case .permissionRequired: "Ative Acessibilidade para o Tico nos Ajustes do Sistema."
        case .unreadableWindow: "Não foi possível verificar esta janela."
        case .accessibilityFailure(let code): "O aplicativo não respondeu ao controle de janela (AX \(code))."
        case .invalid(let detail): detail
        case .stalePreview: "A prévia expirou ou mudou. Atualize-a antes de aplicar."
        case .changedWindow: "A janela mudou, foi fechada ou o aplicativo reiniciou. Atualize a prévia."
        case .changedDisplays: "Os monitores mudaram. Atualize a prévia; a disposição anterior foi preservada para restauração."
        case .busy: "Aguarde a operação de layout atual terminar."
        case .pendingRecovery: "Restaure ou descarte a disposição anterior antes de aplicar outra cena."
        }
    }
}
