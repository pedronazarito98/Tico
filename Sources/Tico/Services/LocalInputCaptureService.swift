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
        stop()
        window = NSApp.keyWindow
        issue = nil
        isActive = true
        // Eventos locais são entregues na main thread, antes do responder chain.
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged, .otherMouseDown]) { [weak self] event in
            let consumed = MainActor.assumeIsolated { () -> Bool in
                guard let self, self.isActive, event.window === self.window else { return false }
                let flags = Self.modifiers(event.modifierFlags)
                self.modifiers = flags
                onModifiers(flags)
                switch event.type {
                case .flagsChanged:
                    if let modifier = InputPresentation.modifierKeys[event.keyCode] {
                        if self.pressedKeys.contains(event.keyCode) || !flags.contains(modifier) {
                            self.pressedKeys.remove(event.keyCode)
                        } else { self.pressedKeys.insert(event.keyCode) }
                    }
                case .keyUp:
                    self.pressedKeys.remove(event.keyCode)
                case .keyDown:
                    if event.keyCode == 53 { onCancel(); return true }
                    guard !event.isARepeat else { return true }
                    self.pressedKeys.insert(event.keyCode)
                    guard self.pressedKeys.filter({ InputPresentation.modifierKeys[$0] == nil }).count == 1 else {
                        self.issue = "Use uma tecla com ⌘, ⌥, ⌃ ou ⇧. Para várias teclas em ordem, escolha Sequência."
                        return true
                    }
                    self.issue = nil
                    onEvent(.keyboard(keyCode: event.keyCode, modifiers: flags))
                case .otherMouseDown:
                    onEvent(.mouseButton(event.buttonNumber, modifiers: flags))
                default: break
                }
                // Impede que Command+S, por exemplo, salve o formulário ao gravar.
                return true
            }
            return consumed ? nil : event
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { _ in MainActor.assumeIsolated { onCancel() } }
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
