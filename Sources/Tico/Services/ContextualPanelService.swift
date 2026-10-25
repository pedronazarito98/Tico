import AppKit
import SwiftUI

/// Fronteira nativa: posiciona um painel sem ativar o Tico nem roubar o app de destino.
/// O owner é CompanionCoordinator. Monitores de clique existem só enquanto visível;
/// eventos de teclado já normalizados chegam pelo capturador existente, sem outro tap.
@MainActor
final class ContextualPanelService {
    private var panel: CompanionPanel?
    private var outsideClickMonitor: Any?
    private var localClickMonitor: Any?
    private var holdTask: Task<Void, Never>?
    private var mapIsVisible = false
    private var holdIsPending = false
    var isVisible: Bool { panel?.isVisible == true }
    var onRequestActions: (() -> Void)?
    var onRequestMap: (() -> Void)?

    func handle(_ event: InputEventDescriptor) -> Bool {
        guard event.kind == .keyboard else { return isVisible }
        if event.keyCode == 53, isVisible { close(); return true }
        let holdingMap = event.modifiers == [.command, .option]
        if !holdingMap {
            holdTask?.cancel()
            holdTask = nil
            holdIsPending = false
            if mapIsVisible { close() }
        }
        if holdingMap, ![54, 55, 58, 61].contains(event.keyCode ?? 0) {
            holdTask?.cancel()
            holdTask = nil
        }
        if holdingMap, [54, 55, 58, 61].contains(event.keyCode ?? 0), !holdIsPending, !isVisible {
            holdIsPending = true
            holdTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled, let self else { return }
                onRequestMap?()
            }
            return true
        }
        if event.keyCode == 49, event.modifiers == [.command, .option, .control], !isVisible {
            onRequestActions?()
            return true
        }
        return isVisible
    }

    func show(appName: String, items: [ContextualActionItem], isMap: Bool,
              onSelect: @escaping (UUID) -> Void,
              onContent: @escaping () -> Void = {}, onSelection: @escaping () -> Void = {}) {
        close()
        mapIsVisible = isMap
        let panel = CompanionPanel(contentRect: NSRect(x: 0, y: 0, width: 370, height: isMap ? 390 : 440),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.onCancel = { [weak self] in self?.close() }
        panel.contentView = NSHostingView(rootView: ContextualActionsView(
            appName: appName, items: items, isMap: isMap, onSelect: onSelect,
            onClose: { [weak self] in self?.close() }, onContent: onContent, onSelection: onSelection))
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(pointer, $0.frame, false) } ?? NSScreen.main
        if let bounds = screen?.visibleFrame {
            let origin = NSPoint(x: min(max(pointer.x + 12, bounds.minX), bounds.maxX - panel.frame.width),
                                 y: min(max(pointer.y - panel.frame.height, bounds.minY), bounds.maxY - panel.frame.height))
            panel.setFrameOrigin(origin)
        }
        self.panel = panel
        panel.orderFrontRegardless()
        if !isMap { panel.makeKey() }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.close() }
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if event.window !== self?.panel { self?.close() }
            return event
        }
    }

    func close() {
        holdTask?.cancel()
        holdTask = nil
        holdIsPending = false
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor) }
        outsideClickMonitor = nil
        localClickMonitor = nil
        panel?.orderOut(nil)
        panel = nil
        mapIsVisible = false
    }
}

@MainActor
private final class CompanionPanel: NSPanel {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onCancel?() }
}
