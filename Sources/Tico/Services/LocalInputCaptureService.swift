import AppKit
import Combine

@MainActor
protocol LocalInputCapturing: AnyObject {
    func start(onEvent: @escaping (InputEventDescriptor) -> Void,
               onModifiers: @escaping (Set<InputModifier>) -> Void,
               onCancel: @escaping () -> Void)
    func stop()
}

/// Ponte estreita para eventos da janela que iniciou a gravação. O controller
/// possui este serviço e suspende automações enquanto o monitor está ativo.
/// Teclas só vivem em memória durante a interação; nenhuma digitação é registrada.
@MainActor
final class LocalInputCaptureService: ObservableObject, LocalInputCapturing {
    @Published private(set) var pressedKeys: Set<UInt16> = []
    @Published private(set) var modifiers: Set<InputModifier> = []
    @Published private(set) var issue: String?
    @Published private(set) var isActive = false
    private var monitor: Any?
    private var resignObserver: Any?
    private weak var window: NSWindow?

    func start(onEvent: @escaping (InputEventDescriptor) -> Void,
               onModifiers: @escaping (Set<InputModifier>) -> Void,
               onCancel: @escaping () -> Void) {
        start(onInput: { input in
            onModifiers(input.modifiers)
            if case let .activation(event) = input { onEvent(event) }
        }, onCancel: onCancel)
    }

    func start(onInput: @escaping (CapturedInput) -> Void,
               onCancel: @escaping () -> Void) {
        stop()
        // A ação pode começar antes de a sheet ganhar foco. Nessa transição,
        // AppKit pode não ter keyWindow nem mainWindow; a janela visível mais
        // à frente ainda identifica a origem da gravação.
        window = NSApp.keyWindow ?? NSApp.mainWindow
            ?? NSApp.orderedWindows.first(where: { $0.isVisible && $0.canBecomeKey })
        issue = nil
        isActive = true
        modifiers = GlobalEventTapService.currentModifiers()
        onInput(.modifierChange(ModifierChange(keyCode: nil, modifiers: modifiers, timestamp: Date())))
        // Eventos locais são entregues na main thread, antes do responder chain.
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged, .otherMouseDown]) { [weak self] event in
            let consumed = MainActor.assumeIsolated { () -> Bool in
                guard let self, self.isActive, self.owns(event.window) else { return false }
                return self.consume(event, onInput: onInput, onCancel: onCancel)
            }
            return consumed ? nil : event
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { _ in MainActor.assumeIsolated { onCancel() } }
    }

    /// Mesma fronteira usada pelo monitor e por entradas sintéticas isoladas.
    /// Ownership de janela/foco é validado pelo monitor antes de entrar aqui.
    @discardableResult
    func consume(_ event: NSEvent, onInput: (CapturedInput) -> Void, onCancel: () -> Void) -> Bool {
        // Filtrar antes de flags/pressedKeys/escape evita efeitos de retorno,
        // inclusive enquanto uma ação anterior atravessa uma troca de foco.
        if let source = event.cgEvent, InputEventOrigin.isOwn(source) { return false }
        let flags = Self.modifiers(event.modifierFlags)
        modifiers = flags
        switch event.type {
        case .flagsChanged:
            if let modifier = InputPresentation.modifierKeys[event.keyCode] {
                if pressedKeys.contains(event.keyCode) || !flags.contains(modifier) {
                    pressedKeys.remove(event.keyCode)
                } else { pressedKeys.insert(event.keyCode) }
            }
            onInput(.modifierChange(ModifierChange(keyCode: event.keyCode, modifiers: flags, timestamp: Date())))
        case .keyUp:
            pressedKeys.remove(event.keyCode)
            onInput(.modifierChange(ModifierChange(keyCode: nil, modifiers: flags, timestamp: Date())))
        case .keyDown:
            if event.keyCode == 53 { onCancel(); return true }
            guard !event.isARepeat else { return true }
            pressedKeys.insert(event.keyCode)
            guard pressedKeys.filter({ InputPresentation.modifierKeys[$0] == nil }).count == 1 else {
                issue = "Use uma tecla com ⌘, ⌥, ⌃ ou ⇧. Para várias teclas em ordem, escolha Sequência."
                return true
            }
            issue = nil
            onInput(.activation(.keyboard(keyCode: event.keyCode, modifiers: flags)))
        case .otherMouseDown:
            onInput(.activation(.mouseButton(event.buttonNumber, modifiers: flags)))
        default: break
        }
        // Evita que atalhos do formulário sejam executados durante a gravação.
        return true
    }

    /// A gravação começa na janela de origem, antes de a sheet de prática ser
    /// apresentada. Aceita a própria janela e suas sheets, mas não outra janela
    /// do Tico; perder o foco do aplicativo continua encerrando a captura.
    private func owns(_ eventWindow: NSWindow?) -> Bool {
        guard let window else { return false }
        var candidate = eventWindow
        while let current = candidate {
            if current === window { return true }
            candidate = current.sheetParent
        }
        return false
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        monitor = nil
        resignObserver = nil
        window = nil
        isActive = false
        pressedKeys = []
        modifiers = []
    }

    private static func modifiers(_ flags: NSEvent.ModifierFlags) -> Set<InputModifier> {
        let pairs: [(NSEvent.ModifierFlags, InputModifier)] = [
            (.command, .command), (.option, .option), (.control, .control),
            (.shift, .shift), (.capsLock, .capsLock), (.function, .function)
        ]
        return Set(pairs.compactMap { flags.contains($0.0) ? $0.1 : nil })
    }
}
