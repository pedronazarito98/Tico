import Combine
import Foundation

/// Reconhece repetições sem executar workflows: três na prática guiada e sem
/// limite na prévia do criador. O controller é o owner da captura em ambos os casos.
/// Paralelo com React: estado de uma interação guiada, separado dos efeitos globais.
@MainActor
final class GesturePracticeSession: ObservableObject {
    private(set) var sessionID: UUID?
    @Published private(set) var rule: ShortcutRule?
    @Published private(set) var lastReceivedDescription: String?
    @Published private(set) var lastInputMatched = false
    @Published private(set) var completedCount = 0
    @Published private(set) var feedback = "Escolha um atalho para praticar."
    private var runtime = TriggerSequenceRuntime()
    private var lastSessionID: UUID?
    private var lastAcceptedAt = Date.distantPast
    private var repetitionLimit: Int? = 3

    var isComplete: Bool { repetitionLimit.map { completedCount >= $0 } ?? false }

    func begin(_ rule: ShortcutRule, repetitionLimit: Int? = 3) -> UUID {
        let id = UUID()
        sessionID = id
        self.rule = rule
        self.repetitionLimit = repetitionLimit
        completedCount = 0
        lastReceivedDescription = nil
        lastInputMatched = false
        runtime.reset()
        lastSessionID = nil
        lastAcceptedAt = .distantPast
        feedback = repetitionLimit == nil ? "Faça o gesto para experimentar na prévia."
            : "Repita o gatilho três vezes. Nenhuma ação será executada."
        return id
    }

    func receive(_ event: InputEventDescriptor) {
        guard var candidate = rule, !isComplete else { return }
        if let gesture = event.gestureEvent {
            // Hold é um reconhecimento discreto emitido em began, sem ended posterior.
            let isRecognition = gesture.phase == .ended || (gesture.kind == .hold && gesture.phase == .began)
            guard isRecognition, gesture.sessionID != lastSessionID else { return }
        }
        lastReceivedDescription = event.displayName
        candidate.isEnabled = true
        candidate.scope = .global

        candidate.conditions = []
        let evaluation = runtime.process(
            event: event, rules: [candidate],
            context: ContextSnapshot(modifiers: event.modifiers, capturedAt: event.timestamp)
        )
        lastInputMatched = !evaluation.matchedRules.isEmpty
        guard lastInputMatched else {
            feedback = "Continue: procure repetir o gatilho mostrado acima."
            return
        }
        guard event.timestamp.timeIntervalSince(lastAcceptedAt) >= 0.25 else { return }
        lastSessionID = event.gestureEvent?.sessionID
        lastAcceptedAt = event.timestamp
        completedCount += 1
        if let repetitionLimit {
            feedback = isComplete ? "Três repetições reconhecidas. A prática foi concluída."
                : "Reconhecido! Mais \(repetitionLimit - completedCount) repetição(ões)."
        } else {
            feedback = "Gesto reconhecido. Nenhuma ação foi executada."
        }
    }

    func end() {
        sessionID = nil
        rule = nil
        runtime.reset()
    }
}
