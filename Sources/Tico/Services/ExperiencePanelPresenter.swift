import AppKit
import SwiftUI

/// Ponte estreita dos painéis de conteúdo e feedback. Cada coordenador possui
/// sua instância; nenhuma janela, monitor global ou conteúdo sobrevive a close().
/// Painéis não ativam o app externo nem alteram seu destino de execução.
@MainActor
final class ExperiencePanelPresenter: NSObject, NSWindowDelegate {
    enum Purpose { case content, feedback }

    private var panel: ExperiencePanel?
    private var onClose: (() -> Void)?
    private var presentationID = UUID()
    var isVisible: Bool { panel?.isVisible == true }

    func show<Content: View>(
        _ content: Content,
        purpose: Purpose,
        onClose: @escaping () -> Void
    ) {
        close()
        presentationID = UUID()
        self.onClose = onClose
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(pointer, $0.frame, false) }) ?? NSScreen.main
        let bounds = screen?.visibleFrame.insetBy(dx: 16, dy: 16)
        let width = min(purpose == .content ? 560.0 : 420.0, bounds?.width ?? 560)
        let hosting = NSHostingController(rootView: content.tint(TicoBrand.Palette.primary))
        // Medir com a largura real permite quebrar títulos e mensagens antes
        // de escolher a altura do feedback; a medida ideal solta os truncava.
        let proposed = hosting.sizeThatFits(in: CGSize(width: width, height: 420))
        let height = purpose == .content ? 640 : max(160, min(proposed.height, 420))
        // O NSPanel oferece o tamanho; o conteúdo SwiftUI rola dentro dele.
        // Uma fittingSize rígida não deve vencer o limite da tela menor.
        hosting.sizingOptions = []
        let panel = ExperiencePanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: purpose == .content ? [.borderless, .nonactivatingPanel, .resizable] : [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.delegate = self
        panel.onCancel = { [weak self] in self?.close() }
        panel.contentViewController = hosting
        if let bounds {
            let size = NSSize(width: min(width, bounds.width), height: min(height, bounds.height))
            if purpose == .content {
                panel.contentMinSize = NSSize(width: min(360, bounds.width), height: min(320, bounds.height))
            }
            let origin = purpose == .feedback
                ? NSPoint(x: bounds.maxX - size.width, y: bounds.maxY - size.height)
                : NSPoint(x: min(max(pointer.x + 12, bounds.minX), bounds.maxX - size.width),
                          y: min(max(pointer.y - size.height, bounds.minY), bounds.maxY - size.height))
            panel.setFrame(NSRect(origin: origin, size: size), display: false)
        }
        self.panel = panel
        panel.orderFrontRegardless()
        if purpose == .content { panel.makeKey() }
    }

    /// Suspende a mesma janela para devolver o foco AX ao app que já estava
    /// ativo. Não ativa outro aplicativo e não dispara o encerramento da sessão.
    /// O token impede que uma captura antiga restaure uma apresentação nova.
    func hideForSelectionCapture() -> UUID? {
        guard let panel else { return nil }
        panel.resignKey()
        panel.orderOut(nil)
        return presentationID
    }

    func restoreAfterSelectionCapture(_ token: UUID) {
        guard presentationID == token, let panel else { return }
        panel.orderFrontRegardless()
        panel.makeKey()
    }

    func close() {
        guard let existing = panel else { return }
        panel = nil
        presentationID = UUID()
        let completion = onClose
        onClose = nil
        existing.delegate = nil
        existing.orderOut(nil)
        existing.close()
        completion?()
    }

    func windowWillClose(_ notification: Notification) { close() }

    func windowDidChangeScreen(_ notification: Notification) {
        guard let panel, let screen = panel.screen else { return }
        let bounds = screen.visibleFrame.insetBy(dx: 16, dy: 16)
        var frame = panel.frame
        frame.size = NSSize(width: min(frame.width, bounds.width), height: min(frame.height, bounds.height))
        frame.origin.x = min(max(frame.minX, bounds.minX), bounds.maxX - frame.width)
        frame.origin.y = min(max(frame.minY, bounds.minY), bounds.maxY - frame.height)
        panel.setFrame(frame, display: true)
    }
}

@MainActor
private final class ExperiencePanel: NSPanel {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}
