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
    @Published private(set) var intelligenceAvailability: LocalIntelligenceAvailability = .checking
    @Published private(set) var transformation: ContentTransformation?
    @Published var generatedText: String? { didSet { if !isUpdating { scheduleExpiry() } } }
    private(set) var inputGeneration = UUID()

    private let intelligence: (any LocalIntelligenceServicing)?
    private let copyText: @MainActor (String) throws -> Void
    private var generationTimeout: Task<Void, Never>?

    private let execute: @MainActor (ContentActionChoice, AutomationContent) async -> ActionExecutionResult
    private let onCancel: @MainActor () -> Void
    private var operation: Task<Void, Never>?
    private var expiration: Task<Void, Never>?
    private var generation = UUID()
    private var isUpdating = false

    init(intelligence: (any LocalIntelligenceServicing)? = nil,
         copyText: @escaping @MainActor (String) throws -> Void = { _ in throw ContentActionError.launchFailed },
         execute: @escaping @MainActor (ContentActionChoice, AutomationContent) async -> ActionExecutionResult,
         onCancel: @escaping @MainActor () -> Void = {}) {
        self.intelligence = intelligence
        self.copyText = copyText
        self.execute = execute
        self.onCancel = onCancel
    }

    var supportsTransformation: Bool { intelligence != nil }
    var isGenerating: Bool { isRunning && transformation != nil }

    var generatedTextIsValid: Bool {
        guard let generatedText else { return false }
        return (try? AutomationContent.text(generatedText).validate()) != nil
    }

    func refreshIntelligenceAvailability() async {
        guard let intelligence else { return }
        let state = await intelligence.availability()
        guard !Task.isCancelled else { return }
        intelligenceAvailability = state
    }

    /// A inferência compartilha exclusão mútua com a execução, mas seu resultado
    /// permanece separado da entrada. Só a revisão pode promovê-lo ao formulário.
    func transform(_ transformation: ContentTransformation) {
        guard !isRunning, kind == .text, let intelligence, let content,
              case let .text(input) = content else { return }
        guard intelligenceAvailability == .available else {
            status = intelligenceAvailability.message
            return
        }
        generatedText = nil
        expiration?.cancel()
        self.transformation = transformation
        let token = UUID()
        generation = token
        isRunning = true
        isCancelling = false
        runningActionID = nil
        status = nil
        resultSucceeded = false
        operation = Task { [weak self] in
            do {
                let output = try await intelligence.transform(input, operation: transformation)
                guard let self, !Task.isCancelled, generation == token else { return }
                generatedText = output
                finishGeneration()
                status = "Confira o texto gerado antes de usar."
            } catch {
                guard let self, !Task.isCancelled, generation == token else { return }
                finishGeneration()
                status = (error as? LocalIntelligenceError)?.localizedDescription
                    ?? LocalIntelligenceError.failed.localizedDescription
            }
        }
        generationTimeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(60)) } catch { return }
            guard let self, generation == token, isGenerating else { return }
            cancel()
            status = LocalIntelligenceError.timedOut.localizedDescription
        }
    }

    /// Aprovar altera somente a entrada do painel. Pesquisar, enviar ou executar
    /// continua exigindo a escolha explícita de uma das ações existentes.
    func useGeneratedText() {
        guard !isRunning, generatedTextIsValid, let generatedText else { return }
        setContent(.text(generatedText))
        status = "Texto revisado no painel. Escolha uma ação quando quiser usá-lo."
    }

    func copyGeneratedText() {
        guard !isRunning, generatedTextIsValid, let generatedText else { return }
        do {
            try copyText(generatedText)
            status = "Texto revisado copiado."
            resultSucceeded = true
        } catch {
            status = "Não foi possível copiar o texto revisado."
            resultSucceeded = false
        }
        scheduleExpiry()
    }

    func discardGeneratedText() {
        guard !isRunning else { return }
        generatedText = nil
        transformation = nil
        status = nil
        resultSucceeded = false
        scheduleExpiry()
    }

    private func finishGeneration() {
        isRunning = false
        isCancelling = false
        operation = nil
        generationTimeout?.cancel()
        generationTimeout = nil
        scheduleExpiry()
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
        generatedText = nil
        transformation = nil
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
        if isGenerating {
            // O SDK pode terminar depois do cancelamento. A geração invalida
            // esse retorno sem ressuscitar texto ao reabrir o painel.
            generation = UUID()
            operation?.cancel()
            operation = nil
            generationTimeout?.cancel()
            generationTimeout = nil
            isRunning = false
            isCancelling = false
            discardInput()
            status = "Geração cancelada. O conteúdo foi removido do painel."
            resultSucceeded = false
            return
        }
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
        generatedText = nil
        transformation = nil
        isUpdating = false
    }

    private func resetResultAndExpiry() {
        guard !isRunning else { return }
        generatedText = nil
        transformation = nil
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
