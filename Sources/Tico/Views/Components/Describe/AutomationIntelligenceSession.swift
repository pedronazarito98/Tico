import Combine
import Foundation

/// Estado efêmero pertencente à tela de linguagem natural. Tokens descartam
/// respostas antigas após edição, troca de apps/gesto, cancelamento ou fechamento.
/// Paralelo com React: estado de uma requisição com cleanup; o serviço faz o IO.
@MainActor
final class AutomationIntelligenceSession: ObservableObject {
    @Published var text = "" { didSet { invalidate() } }
    @Published private(set) var availability: LocalIntelligenceAvailability = .checking
    @Published private(set) var isGenerating = false
    @Published private(set) var draft: ShortcutRule?
    @Published private(set) var issue: String?
    private let service: any LocalIntelligenceServicing
    private var operation: Task<Void, Never>?
    private var timeout: Task<Void, Never>?
    private var generation = UUID()

    init(service: any LocalIntelligenceServicing) { self.service = service }

    func refreshAvailability() async {
        let state = await service.availability()
        guard !Task.isCancelled else { return }
        availability = state
    }

    func generate(applications: [ApplicationChoice], recordedTrigger: TriggerDefinition?) {
        guard !isGenerating, availability == .available else { return }
        invalidate()
        let token = generation
        let input = text
        let service = service
        isGenerating = true
        operation = Task { [weak self] in
            do {
                let draft = try await service.automationDraft(from: input, applications: applications,
                                                             recordedTrigger: recordedTrigger)
                guard let self, !Task.isCancelled, generation == token else { return }
                self.draft = draft
                finish()
            } catch {
                guard let self, !Task.isCancelled, generation == token else { return }
                issue = (error as? LocalIntelligenceError)?.localizedDescription
                    ?? (error as? AutomationDraftParser.DraftError)?.localizedDescription
                    ?? LocalIntelligenceError.failed.localizedDescription
                finish()
            }
        }
        timeout = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(60)) } catch { return }
            guard let self, generation == token, isGenerating else { return }
            invalidate()
            issue = LocalIntelligenceError.timedOut.localizedDescription
        }
    }

    func invalidate() {
        generation = UUID()
        operation?.cancel()
        operation = nil
        timeout?.cancel()
        timeout = nil
        isGenerating = false
        draft = nil
        issue = nil
    }

    func clear() {
        text = ""
        invalidate()
    }

    private func finish() {
        isGenerating = false
        operation = nil
        timeout?.cancel()
        timeout = nil
    }
}
