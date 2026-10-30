import Foundation

/// Operações fechadas sobre texto fornecido explicitamente. Não integram o
/// schema de regras: toda transformação exige revisão na sessão do painel.
enum ContentTransformation: String, CaseIterable, Identifiable, Sendable {
    case summarize, proofread, shorten, extractTasks

    var id: Self { self }
    var title: String {
        switch self {
        case .summarize: "Resumir"
        case .proofread: "Revisar escrita"
        case .shorten: "Deixar mais direto"
        case .extractTasks: "Extrair tarefas"
        }
    }
}
