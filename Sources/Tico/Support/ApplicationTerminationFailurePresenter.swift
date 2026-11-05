import AppKit

/// Apresenta falha de término independentemente de uma cena SwiftUI aberta.
@MainActor
protocol ApplicationTerminationFailurePresenting: AnyObject {
    func present(_ error: Error)
    func dismiss()
}

/// Painel nativo não modal, retido pela lifecycle e reutilizado entre tentativas.
/// Não depende de ContentView nem de uma janela principal; showWindow apenas
/// apresenta a janela e devolve controle, sem loop modal ou espera na main.
/// Paralelo com React: a fronteira imperativa exibe o erro fora da árvore da
/// página; AppKit continua dono da janela e dos controles nativos.
@MainActor
final class ApplicationTerminationFailurePresenter: NSObject, ApplicationTerminationFailurePresenting {
    private let application: NSApplication
    private var windowController: NSWindowController?
    private var detailLabel: NSTextField?

    init(application: NSApplication) { self.application = application; super.init() }

    func present(_ error: Error) {
        if windowController == nil { makePanel() }
        detailLabel?.stringValue = error.localizedDescription
        if let panel = windowController?.window, let content = panel.contentView {
            content.layoutSubtreeIfNeeded()
            panel.setContentSize(NSSize(width: 448, height: max(180, content.fittingSize.height)))
        }
        application.activate(ignoringOtherApps: true)
        windowController?.showWindow(nil)
    }

    func dismiss() { windowController?.close() }

    @objc private func continueInApplication(_ sender: Any?) { dismiss() }

    private func makePanel() {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 448, height: 180),
            styleMask: [.titled, .closable], backing: .buffered, defer: true)
        panel.title = TicoBrand.displayName
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .alertPanel
        let title = NSTextField(wrappingLabelWithString: "O Tico permaneceu aberto")
        title.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        let detail = NSTextField(wrappingLabelWithString: "")
        detail.isSelectable = true
        detail.preferredMaxLayoutWidth = 400
        title.setContentCompressionResistancePriority(.required, for: .vertical)
        detail.setContentCompressionResistancePriority(.required, for: .vertical)
        let button = NSButton(title: "Continuar no Tico", target: self, action: #selector(continueInApplication(_:)))
        button.keyEquivalent = "\r"
        let buttons = NSStackView(views: [NSView(), button])
        buttons.orientation = .horizontal
        let stack = NSStackView(views: [title, detail, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24),
            title.widthAnchor.constraint(equalTo: stack.widthAnchor),
            detail.widthAnchor.constraint(equalTo: stack.widthAnchor),
            buttons.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
        panel.contentView = content
        panel.center()
        detailLabel = detail
        windowController = NSWindowController(window: panel)
    }
}
