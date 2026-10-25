import Foundation

/// Fronteira de execução com saída sanitizada. Conteúdo nunca aparece no nome da
/// ação ou no resultado; URLLauncher pode devolver a URL em erros, então a causa
/// é convertida aqui antes de chegar ao ActionRunner e ao histórico.
final class ContentActionService {
    private let selectionCapture: any SelectedTextCapturing
    private let shortcutRunner: any ContentShortcutRunning
    private let urlLauncher: any URLLaunching

    init(selectionCapture: any SelectedTextCapturing = SelectionCaptureService(),
         shortcutRunner: any ContentShortcutRunning = ContentShortcutRunner(),
         urlLauncher: any URLLaunching = URLLauncher()) {
        self.selectionCapture = selectionCapture
        self.shortcutRunner = shortcutRunner
        self.urlLauncher = urlLauncher
    }

    func prepareContext(actions: [ShortcutAction], providedContent: AutomationContent?) async -> ContentExecutionContext {
        var context = ContentExecutionContext(providedContent: providedContent)
        let needsSelection = actions.contains {
            guard case let .content(configuration) = $0 else { return false }
            return configuration.source == .selection && configuration.selectionTiming == .workflowStart
        }
        if needsSelection {
            do { context.initialSelection = .success(try await selectionCapture.capture()) }
            catch let error as ContentActionError { context.initialSelection = .failure(error) }
            catch is CancellationError { context.initialSelection = .failure(.cancelled) }
            catch { context.initialSelection = .failure(.selectionUnavailable) }
        }
        return context
    }

    func execute(_ configuration: ContentActionConfiguration, context: ContentExecutionContext?, timeout: TimeInterval) async throws -> String {
        try Task.checkCancellation()
        guard configuration.validationMessage == nil else { throw ContentActionError.invalidConfiguration }
        let content: AutomationContent
        switch configuration.source {
        case .provided:
            guard let provided = context?.providedContent else { throw ContentActionError.emptyContent }
            content = provided
        case .selection:
            if configuration.selectionTiming == .workflowStart {
                // Sem snapshot, falha fechada. Não captura novamente num app que
                // uma etapa anterior possa ter aberto ou trazido para frente.
                guard let snapshot = context?.initialSelection else { throw ContentActionError.selectionUnavailable }
                content = try snapshot.get()
            } else {
                content = try await selectionCapture.capture()
            }
        }
        try Task.checkCancellation()
        try content.validate()
        guard configuration.accepts(content) else { throw ContentActionError.incompatibleContent }
        switch configuration.destination {
        case let .search(destination):
            let url = try destination.url(for: content)
            try Task.checkCancellation()
            do { try urlLauncher.open(url) }
            catch { throw ContentActionError.launchFailed }
            return "Pesquisa aberta com o conteúdo fornecido."
        case let .macOSShortcut(name):
            do { try await shortcutRunner.run(name: name, content: content, timeout: timeout) }
            catch let error as ContentActionError { throw error }
            catch is CancellationError { throw ContentActionError.cancelled }
            catch { throw ContentActionError.shortcutFailed }
            return "Atalho do macOS executado com o conteúdo fornecido."
        }
    }
}
