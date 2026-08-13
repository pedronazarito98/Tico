import Foundation

extension InputModifier {
    var displayName: String {
        switch self {
        case .command: "Command"
        case .option: "Option"
        case .control: "Control"
        case .shift: "Shift"
        case .capsLock: "Caps Lock"
        case .function: "Fn"
        }
    }

    var symbol: String {
        switch self {
        case .command: "⌘"
        case .option: "⌥"
        case .control: "⌃"
        case .shift: "⇧"
        case .capsLock: "⇪"
        case .function: "fn"
        }
    }
}

extension TrackpadGesture {
    var displayName: String {
        switch self {
        case .tap: "Toque"
        case .hold: "Pressionar e segurar"
        case .tipTapLeft: "TipTap esquerdo"
        case .tipTapRight: "TipTap direito"
        case .addFinger: "Adicionar dedo"
        case .removeFinger: "Remover dedo"
        case .fingerChord: "Acorde de dedos"
        case .swipeLeft: "Deslizar para a esquerda"
        case .swipeRight: "Deslizar para a direita"
        case .swipeUp: "Deslizar para cima"
        case .swipeDown: "Deslizar para baixo"
        case .pinchIn: "Pinça para dentro"
        case .pinchOut: "Pinça para fora"
        case .rotateClockwise: "Girar no sentido horário"
        case .rotateCounterclockwise: "Girar no sentido anti-horário"
        }
    }
}

extension TrackpadRegion {
    var displayName: String {
        switch self {
        case .any: "Qualquer região"
        case .topLeft: "Superior esquerda"
        case .topRight: "Superior direita"
        case .bottomLeft: "Inferior esquerda"
        case .bottomRight: "Inferior direita"
        case .topEdge: "Borda superior"
        case .bottomEdge: "Borda inferior"
        case .leftEdge: "Borda esquerda"
        case .rightEdge: "Borda direita"
        case .cornerTopLeft: "Canto superior esquerdo"
        case .cornerTopRight: "Canto superior direito"
        case .cornerBottomLeft: "Canto inferior esquerdo"
        case .cornerBottomRight: "Canto inferior direito"
        case .gridTopLeft: "Grade · superior esquerda"
        case .gridTopCenter: "Grade · superior centro"
        case .gridTopRight: "Grade · superior direita"
        case .gridMiddleLeft: "Grade · meio esquerda"
        case .gridCenter: "Grade · centro"
        case .gridMiddleRight: "Grade · meio direita"
        case .gridBottomLeft: "Grade · inferior esquerda"
        case .gridBottomCenter: "Grade · inferior centro"
        case .gridBottomRight: "Grade · inferior direita"
        }
    }
}

extension GestureCalibrationPreset {
    var displayName: String {
        switch self {
        case .conservative: "Conservador"
        case .balanced: "Equilibrado"
        case .responsive: "Responsivo"
        case .custom: "Personalizado"
        }
    }
}

extension TriggerDefinition {
    var displayName: String {
        switch self {
        case let .keyboard(keyCode, modifiers):
            return modifierPrefix(modifiers) + "Tecla \(keyCode)"
        case let .mouseButton(button, modifiers):
            return modifierPrefix(modifiers) + "Botão \(button)"
        case let .trackpad(spec):
            let count = spec.fingerCount.lowerBound == spec.fingerCount.upperBound
                ? "\(spec.fingerCount.lowerBound)"
                : "\(spec.fingerCount.lowerBound)–\(spec.fingerCount.upperBound)"
            let regionSuffix = spec.startRegion == .any ? "" : " · \(spec.startRegion.displayName)"
            let tapPrefix = spec.tapCount > 1 ? "\(spec.tapCount)× " : ""
            return "\(tapPrefix)\(count) dedos · \(spec.gesture.displayName)\(regionSuffix)"
        case let .customTrackpad(template):
            let count = template.fingerCount.lowerBound == template.fingerCount.upperBound
                ? "\(template.fingerCount.lowerBound)"
                : "\(template.fingerCount.lowerBound)–\(template.fingerCount.upperBound)"
            return "\(count) dedos · \(template.name)"
        case let .sequence(sequence):
            return sequence.steps.map(\.displayName).joined(separator: "  →  ")
        }
    }
}

extension ShortcutAction {
    var displayName: String {
        switch self {
        case let .openApplication(bundleIdentifier):
            return "Abrir \(bundleIdentifier)"
        case let .openURL(url):
            return "Abrir \(url.absoluteString)"
        case let .notification(title, _):
            return "Notificação: \(title)"
        case .shellScript:
            return "Executar script local"
        case .appleScript:
            return "Executar AppleScript"
        case let .macOSShortcut(name, _):
            return "Atalho: \(name)"
        case let .keyboardShortcut(keyCode, modifiers):
            return modifierPrefix(modifiers) + "Tecla \(keyCode)"
        case .setClipboard:
            return "Atualizar clipboard"
        case let .application(target, operation):
            return "\(operation.displayName) · \(target.displayName)"
        case let .window(target, operation):
            return "\(operation.displayName) · \(target.displayName)"
        case let .continuousWindow(target, operation, _):
            return "\(operation.displayName) · \(target.displayName)"
        }
    }
}

extension TriggerStep {
    var displayName: String {
        triggerDefinition.displayName
    }
}

extension RuleScope {
    func displayName(applications: [ApplicationChoice] = []) -> String {
        switch self {
        case .global:
            "Todos os apps"
        case let .applications(bundleIdentifiers):
            bundleIdentifiers
                .map { identifier in
                    applications.first { $0.bundleIdentifier == identifier }?.name ?? identifier
                }
                .sorted()
                .joined(separator: ", ")
        }
    }
}

extension ApplicationTarget {
    var displayName: String {
        switch self {
        case .frontmost:
            "App em primeiro plano"
        case let .bundleIdentifier(identifier):
            identifier
        }
    }
}

extension ApplicationOperation {
    var displayName: String {
        switch self {
        case .open: "Abrir"
        case .activate: "Trazer para frente"
        case .hide: "Ocultar"
        case .quit: "Encerrar"
        }
    }
}

extension WindowOperation {
    var displayName: String {
        switch self {
        case .close: "Fechar janela"
        case .minimize: "Minimizar janela"
        case .maximize: "Maximizar janela"
        case .restore: "Restaurar frame anterior"
        case .center: "Centralizar janela"
        case .leftHalf: "Mover para metade esquerda"
        case .rightHalf: "Mover para metade direita"
        case .topHalf: "Mover para metade superior"
        case .bottomHalf: "Mover para metade inferior"
        case .leftThird: "Mover para terço esquerdo"
        case .centerThird: "Mover para terço central"
        case .rightThird: "Mover para terço direito"
        case .topLeftQuarter: "Mover para quarto superior esquerdo"
        case .topRightQuarter: "Mover para quarto superior direito"
        case .bottomLeftQuarter: "Mover para quarto inferior esquerdo"
        case .bottomRightQuarter: "Mover para quarto inferior direito"
        case .nextDisplay: "Mover para próximo monitor"
        case .tileAll: "Organizar todas as janelas"
        }
    }
}

extension ContinuousWindowOperation {
    var displayName: String {
        switch self {
        case .moveHorizontal: "Mover horizontalmente"
        case .moveVertical: "Mover verticalmente"
        case .resizeWidth: "Redimensionar largura"
        case .resizeHeight: "Redimensionar altura"
        case .resizeProportionally: "Redimensionar proporcionalmente"
        }
    }
}

extension ContinuousResponseCurve {
    var displayName: String {
        switch self {
        case .precise: "Precisa"
        case .linear: "Linear"
        case .accelerated: "Acelerada"
        }
    }
}

extension WorkflowFailurePolicy {
    var displayName: String {
        switch self {
        case .stop: "Parar no primeiro erro"
        case .continueRemaining: "Continuar as próximas etapas"
        }
    }
}

enum TrackpadGestureAvailability: Equatable {
    case available
    case degraded(String)
    case unavailable(String)
}

extension TrackpadCaptureMode {
    func availability(for gesture: TrackpadGesture) -> TrackpadGestureAvailability {
        switch self {
        case .advancedGlobal:
            .available
        case .systemGestureFallback:
            if gesture.requiresRawContacts || gesture == .tap || gesture == .hold {
                .unavailable("Este gesto exige contatos brutos e não funciona no fallback público.")
            } else {
                .degraded("O fallback público não informa dedos, âncoras ou região com precisão.")
            }
        case .stopped:
            .degraded("Inicie a captura para confirmar a capacidade do trackpad.")
        }
    }
}

extension InputEventDescriptor {
    var displayName: String {
        switch kind {
        case .keyboard:
            return modifierPrefix(modifiers) + "Tecla \(keyCode.map(String.init) ?? "—")"
        case .mouseButton:
            return modifierPrefix(modifiers) + "Botão \(mouseButton.map(String.init) ?? "—")"
        case .trackpadGesture:
            let count = fingerCount.map { "\($0) dedos · " } ?? ""
            let region = trackpadRegion == nil || trackpadRegion == .any
                ? ""
                : " · \(trackpadRegion!.displayName)"
            return count + (gesture?.displayName ?? "Trajetória personalizada") + region
        }
    }

    var triggerDefinition: TriggerDefinition? {
        switch kind {
        case .keyboard:
            guard let keyCode else { return nil }
            return .keyboard(keyCode: keyCode, modifiers: modifiers)
        case .mouseButton:
            guard let mouseButton else { return nil }
            return .mouseButton(button: mouseButton, modifiers: modifiers)
        case .trackpadGesture:
            guard let gesture else { return nil }
            return .trackpad(
                gesture: gesture,
                fingerCount: fingerCount ?? gesture.defaultFingerCount,
                region: trackpadRegion ?? .any
            )
        }
    }
}

private func modifierPrefix(_ modifiers: Set<InputModifier>) -> String {
    let ordered = InputModifier.allCases.filter(modifiers.contains)
    guard !ordered.isEmpty else { return "" }
    return ordered.map(\.symbol).joined() + " "
}

extension ClosedRange where Bound == Int {
    var displayText: String {
        lowerBound == upperBound ? "\(lowerBound)" : "\(lowerBound)–\(upperBound)"
    }
}
