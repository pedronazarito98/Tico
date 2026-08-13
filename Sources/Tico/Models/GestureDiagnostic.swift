import Foundation

enum GestureDiagnosticOutcome: String, Codable, Sendable {
    case inProgress
    case accepted
    case rejected
    case ignored
    case cancelled
}

struct GestureDiagnostic: Equatable, Sendable {
    let outcome: GestureDiagnosticOutcome
    let summary: String
    let reasons: [String]

    static let inProgress = Self(
        outcome: .inProgress,
        summary: "Sessão em andamento",
        reasons: ["Aguardando o término do gesto para comparar todos os candidatos."]
    )
}
