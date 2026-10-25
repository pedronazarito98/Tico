import Foundation

enum DisplayRoutineTrigger: String, Codable, CaseIterable, Identifiable {
    case externalConnected, externalDisconnected, topologyChanged
    var id: Self { self }
    var title: String {
        switch self {
        case .externalConnected: return "Ao conectar uma tela externa"
        case .externalDisconnected: return "Ao desconectar uma tela externa"
        case .topologyChanged: return "Ao mudar a organização de telas"
        }
    }

    func matches(from previous: DisplayEnvironmentSnapshot, to current: DisplayEnvironmentSnapshot) -> Bool {
        switch self {
        case .externalConnected: return current.externalCount > previous.externalCount
        case .externalDisconnected: return current.externalCount < previous.externalCount
        case .topologyChanged: return previous != current
        }
    }
}

enum DisplayRoutineMode: String, Codable, CaseIterable, Identifiable {
    case suggest, automatic
    var id: Self { self }
    var title: String { self == .suggest ? "Oferecer a cena" : "Executar automaticamente" }
}

/// Uma rotina referencia uma cena existente; não guarda cópias que possam divergir.
struct DisplayRoutine: Identifiable, Codable, Equatable {
    var id = UUID()
    var name = "Minha rotina"
    var workflowID: UUID
    var isEnabled = false
    var trigger: DisplayRoutineTrigger = .externalConnected
    var mode: DisplayRoutineMode = .suggest
    var externalCount: Int?
    var requiresBuiltIn: Bool?
    var mainDisplayRole: DisplayEnvironmentSnapshot.MainDisplayRole?

    func matches(from previous: DisplayEnvironmentSnapshot, to current: DisplayEnvironmentSnapshot) -> Bool {
        isEnabled && trigger.matches(from: previous, to: current)
            && (externalCount.map { $0 == current.externalCount } ?? true)
            && (requiresBuiltIn.map { $0 == (current.builtInCount > 0) } ?? true)
            && (mainDisplayRole.map { $0 == current.mainDisplayRole } ?? true)
    }
}

struct DisplayRoutineDocument: Codable, Equatable {
    var version = 1
    var isEnabled = false
    var routines: [DisplayRoutine] = []
}

/// Autorização efêmera de uma transição estável; o executor central deve validá-la uma vez.
struct DisplayRoutineExecutionIntent: Identifiable, Equatable {
    let id: UUID
    let routine: DisplayRoutine
    let workflow: ActionWorkflow
    let topology: DisplayEnvironmentSnapshot
    let createdAt: Date
    var routineID: UUID { routine.id }
}

struct DisplayRoutineSuggestion: Identifiable, Equatable {
    let id = UUID()
    let intents: [DisplayRoutineExecutionIntent]
    let reason: String
}

enum DisplayRoutineError: LocalizedError {
    case invalidDocument, unavailable, persistence
    var errorDescription: String? {
        switch self {
        case .invalidDocument: return "Os dados das rotinas não são válidos. O arquivo anterior foi preservado."
        case .unavailable: return "Não foi possível carregar as rotinas. O arquivo anterior foi preservado."
        case .persistence: return "Não foi possível salvar a rotina. O último estado válido foi preservado."
        }
    }
}
