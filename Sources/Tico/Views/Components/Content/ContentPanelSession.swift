import Combine
import Foundation

/// Owner do conteúdo efêmero do painel. A execução volta ao coordenador recebido
/// por closure, mantendo aprovação/cancelamento iguais aos demais workflows.
/// Paralelo com React: estado de formulário local e callbacks; nenhum dado pessoal
/// é serializado. Fechar, limpar e expirar invalidam tarefas e apagam a entrada.
@MainActor
final class ContentPanelSession: ObservableObject {
    @Published private(set) var kind: ContentKind = .text
    @Published var text = "" { didSet { if !isUpdating { resetResultAndExpiry() } } }
    @Published private(set) var files: [URL] = []
    @Published private(set) var isRunning = false
    @Published private(set) var isCancelling = false
    @Published private(set) var status: String?
    @Published private(set) var resultSucceeded = false
    @Published private(set) var runningActionID: UUID?
    private(set) var inputGeneration = UUID()

    private let execute: @MainActor (ContentActionChoice, AutomationContent) async -> ActionExecutionResult
    private let onCancel: @MainActor () -> Void
    private var operation: Task<Void, Never>?
    private var expiration: Task<Void, Never>?
    private var generation = UUID()
    private var isUpdating = false

    init(execute: @escaping @MainActor (ContentActionChoice, AutomationContent) async -> ActionExecutionResult,
         onCancel: @escaping @MainActor () -> Void = {}) {
        self.execute = execute
        self.onCancel = onCancel
    }

    var content: AutomationContent? {
        let value: AutomationContent
        switch kind {
        case .text: value = .text(text)
        case .webURL:
            guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
            value = .webURL(url)
        case .files: value = .files(files)
        }
        return (try? value.validate()) != nil ? value : nil
    }

    var inputIssue: String? {
        if kind == .files, files.isEmpty { return nil }
        if kind != .files, text.isEmpty { return nil }
        do {
            switch kind {
            case .text: try AutomationContent.text(text).validate()
            case .webURL:
                guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                    throw ContentActionError.invalidURL
                }
                try AutomationContent.webURL(url).validate()
            case .files: try AutomationContent.files(files).validate()
            }
            return nil
        } catch let error as ContentActionError { return error.localizedDescription }
        catch { return ContentActionError.invalidConfiguration.localizedDescription }
    }

    func selectKind(_ value: ContentKind) {
        guard !isRunning, value != kind else { return }
        // Mudar a apresentação não descarta o rascunho. Texto/link compartilham
        // a mesma entrada; arquivos e texto são apagados juntos ao limpar/expirar.
        kind = value
        resetResultAndExpiry()
    }

    func setContent(_ value: AutomationContent) {
        guard !isRunning else { return }
        do { try value.validate() }
        catch let error as ContentActionError { status = error.localizedDescription; return }
        catch { status = ContentActionError.emptyContent.localizedDescription; return }
        isUpdating = true
        kind = value.kind
        switch value {
        case let .text(value): text = value; files = []
        case let .webURL(url): text = url.absoluteString; files = []
        case let .files(urls): files = urls; text = ""
        }
        isUpdating = false
        resetResultAndExpiry()
    }

    /// Um seletor de arquivos pode responder depois de fechar ou expirar o
    /// painel. Seu token impede que esse retorno ressuscite uma entrada apagada.
    func receiveFiles(_ result: Result<[URL], Error>, inputGeneration token: UUID) {
        guard inputGeneration == token, !isRunning else { return }
        switch result {
        case let .success(urls): addFiles(urls)
        case let .failure(error):
            guard (error as? CocoaError)?.code != .userCancelled else { return }
            status = "Não foi possível receber os arquivos. Selecione novamente."
        }
    }

    @discardableResult
    func addFiles(_ urls: [URL]) -> Bool {
        guard !isRunning, urls.allSatisfy(\.isFileURL) else { return false }
        let combined = files + urls
        let unique = combined.reduce(into: [URL]()) { result, url in
            if !result.contains(url) { result.append(url) }
        }
        do { try AutomationContent.files(unique).validate() }
        catch { status = ContentActionError.invalidFiles.localizedDescription; return false }
        // Adicionar arquivos muda a aba, mas conserva o texto digitado nesta
        // mesma sessão. Só os caminhos explícitos de limpeza apagam ambos.
        kind = .files
        files = unique
        resetResultAndExpiry()
        return true
    }

    func removeFile(_ url: URL) {
        guard !isRunning else { return }
        files.removeAll { $0 == url }
        resetResultAndExpiry()
    }

    func run(_ choice: ContentActionChoice) {
        guard !isRunning, let content else { return }
        guard choice.acceptedKinds.contains(content.kind) else {
            status = ContentActionError.incompatibleContent.localizedDescription
            return
        }
        expiration?.cancel()
        let token = UUID()
        generation = token
        isRunning = true
        isCancelling = false
        runningActionID = choice.id
        status = nil
        resultSucceeded = false
        operation = Task { [weak self] in
            guard let self else { return }
            let result = await execute(choice, content)
            guard generation == token else { return }
            isRunning = false
            isCancelling = false
            runningActionID = nil
            operation = nil
            if Task.isCancelled {
                discardInput()
                status = ContentActionError.cancelled.localizedDescription
                resultSucceeded = false
                return
            }
            // O coordenador pode retornar mensagens de outras etapas; o painel
            // publica apenas um resumo fixo, sem refletir saídas de processos.
            resultSucceeded = result.success
            status = result.success ? "Concluído. O conteúdo foi removido do painel." : "A ação não concluiu. Seu conteúdo continua aqui para tentar novamente."
            if result.success { discardInput() }
            else { scheduleExpiry() }
        }
    }

    func cancel() {
        guard isRunning, !isCancelling else { return }
        isCancelling = true
        operation?.cancel()
        onCancel()
        status = "Cancelando…"
        resultSucceeded = false
        discardInput()
        // isRunning só cai quando o coordenador retorna. Isso impede iniciar
        // outra ação enquanto o processo anterior ainda está encerrando.
    }

    func clear() {
        cancel()
        if !isRunning { generation = UUID() }
        expiration?.cancel()
        expiration = nil
        discardInput()
        if !isRunning { status = nil }
        resultSucceeded = false
    }

    func reportCaptureError(_ error: Error) {
        status = (error as? ContentActionError)?.localizedDescription
            ?? ContentActionError.selectionUnavailable.localizedDescription
        resultSucceeded = false
    }

    private func discardInput() {
        inputGeneration = UUID()
        isUpdating = true
        text = ""
        files = []
        isUpdating = false
    }

    private func resetResultAndExpiry() {
        guard !isRunning else { return }
        status = nil
        resultSucceeded = false
        scheduleExpiry()
    }

    private func scheduleExpiry() {
        expiration?.cancel()
        expiration = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(300)) }
            catch { return }
            guard let self, !isRunning else { return }
            discardInput()
            status = "O conteúdo expirou após 5 minutos sem uso."
        }
    }
}
