import AppKit
import SwiftUI

/// Janela de revisão independente da janela principal. A sessão possui a decisão
/// assíncrona; este adaptador apenas apresenta/fecha e comunica um fechamento humano.
/// Dismiss programático nunca resolve novamente a continuação da sessão.
@MainActor
final class SceneLayoutReviewPresenter: NSObject, NSWindowDelegate {
    private var panel: SceneLayoutReviewPanel?
    private var onClose: (() -> Void)?

    func show(workflow: ActionWorkflow, session: SceneLayoutSession, deadline: Date,
              onClose: @escaping () -> Void) {
        dismiss()
        self.onClose = onClose
        let view = SceneLayoutReviewView(workflow: workflow, session: session, deadline: deadline)
            .tint(TicoBrand.Palette.primary)
        let panel = SceneLayoutReviewPanel(contentRect: NSRect(x: 0, y: 0, width: 760, height: 740),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = "Revisar layout · Tico"
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.contentMinSize = NSSize(width: 540, height: 360)
        let hosting = NSHostingView(rootView: view)
        hosting.sizingOptions = []
        panel.contentView = hosting
        panel.delegate = self
        panel.onCancel = { [weak self] in self?.closeByUser() }
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main {
            let bounds = screen.visibleFrame.insetBy(dx: 20, dy: 20)
            panel.contentMinSize = NSSize(width: min(540, bounds.width), height: min(360, bounds.height))
            let size = NSSize(width: min(760, bounds.width), height: min(780, bounds.height))
            panel.setFrame(NSRect(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2,
                                 width: size.width, height: size.height), display: false)
        }
        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    func dismiss() {
        guard let panel else { return }
        self.panel = nil
        onClose = nil
        panel.delegate = nil
        panel.onCancel = nil
        panel.orderOut(nil)
        panel.close()
    }

    func windowWillClose(_ notification: Notification) { closeByUser() }

    func windowDidChangeScreen(_ notification: Notification) {
        guard let panel, let screen = panel.screen else { return }
        let bounds = screen.visibleFrame.insetBy(dx: 20, dy: 20)
        var frame = panel.frame
        frame.size = NSSize(width: min(frame.width, bounds.width), height: min(frame.height, bounds.height))
        frame.origin.x = min(max(frame.minX, bounds.minX), bounds.maxX - frame.width)
        frame.origin.y = min(max(frame.minY, bounds.minY), bounds.maxY - frame.height)
        panel.setFrame(frame, display: true)
    }

    private func closeByUser() {
        let completion = onClose
        dismiss()
        completion?()
    }
}

@MainActor
private final class SceneLayoutReviewPanel: NSPanel {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}
