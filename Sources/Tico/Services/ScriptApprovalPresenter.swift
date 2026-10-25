import Foundation

/// Apresentação única de aprovações, independente da janela principal. O ID
/// impede que fechar um painel antigo resolva a aprovação de outra execução.
@MainActor
final class ScriptApprovalPresenter {
    private let panel = ExperiencePanelPresenter()
    private var presentedID: UUID?

    func update(_ approval: PendingScriptApproval?, resolve: @escaping (Bool) -> Void) {
        guard approval?.id != presentedID else { return }
        presentedID = nil
        panel.close()
        guard let approval else { return }
        presentedID = approval.id
        panel.show(ScriptApprovalView(approval: approval, onResolve: { [weak self] accepted in
            guard let self, presentedID == approval.id else { return }
            presentedID = nil
            panel.close()
            resolve(accepted)
        }), purpose: .content, onClose: { [weak self] in
            guard let self, presentedID == approval.id else { return }
            presentedID = nil
            resolve(false)
        })
    }
}
