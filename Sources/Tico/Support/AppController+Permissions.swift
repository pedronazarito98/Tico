import Foundation

extension AppController {
    /// Atualiza o estado observado do TCC e encerra a captura quando a
    /// autorização foi revogada fora do aplicativo.
    ///
    /// Este método é chamado pelos pontos de entrada da interface ao abrir ou
    /// retomar a janela. O `CaptureCoordinator` continua sendo o owner dos
    /// recursos nativos; o controller apenas coordena também o motor de ações.
    ///
    /// Paralelo com React: é próximo de sincronizar um store externo em um
    /// efeito de foco, mas a limpeza também encerra event taps e observadores.
    @discardableResult
    func reconcilePermissions() -> PermissionStatus {
        let status = permissions.refresh()
        guard !status.canCaptureGlobalInput else { return status }

        if captureIsRunning || trackpadCaptureMode != .stopped {
            stopCapture()
        }
        return status
    }
}
