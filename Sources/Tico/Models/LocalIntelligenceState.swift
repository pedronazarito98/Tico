import Foundation

/// Estado de uma capacidade opcional do sistema, independente de UI e do SDK.
enum LocalIntelligenceAvailability: Equatable, Sendable {
    case checking, available, deviceNotEligible, notEnabled, notReady, unsupportedLanguage, unavailable

    var message: String {
        switch self {
        case .checking: "Verificando Apple Intelligence…"
        case .available: "Apple Intelligence · processamento neste Mac"
        case .deviceNotEligible: "Este Mac não oferece o modelo local do Apple Intelligence."
        case .notEnabled: "Ative Apple Intelligence nos Ajustes do Sistema para usar este recurso."
        case .notReady: "O modelo local ainda não está pronto. Aguarde o download do sistema e tente novamente."
        case .unsupportedLanguage: "O modelo instalado não oferece suporte ao português neste momento."
        case .unavailable: "Apple Intelligence está indisponível neste momento."
        }
    }
}

/// Diagnósticos fechados: erros do modelo podem conter o prompt e nunca são
/// apresentados, registrados ou persistidos diretamente.
enum LocalIntelligenceError: Error, LocalizedError, Sendable {
    case unavailable(LocalIntelligenceAvailability)
    case emptyInput, inputTooLong, incompleteAutomation, unsupportedAutomation
    case invalidProposal, busy, contextExceeded, refused, failed, timedOut

    var errorDescription: String? {
        switch self {
        case let .unavailable(state): state.message
        case .emptyInput: "Escreva ou selecione um texto antes de gerar."
        case .inputTooLong: "Use um trecho menor: até 2 KB de texto ou 1.000 caracteres para descrever uma automação."
        case .incompleteAutomation: "Faltam detalhes. Informe o gesto, a quantidade de dedos, o aplicativo (ou qualquer aplicativo) e uma ação."
        case .unsupportedAutomation: "A frase contém ações ou condições não suportadas neste modo. Use as escolhas e personalize no editor."
        case .invalidProposal: "Não foi possível validar a proposta. Revise a frase ou use as escolhas."
        case .busy: "O modelo já está atendendo outra solicitação do Tico. Aguarde e tente novamente."
        case .contextExceeded: "O texto excedeu a capacidade do modelo. Selecione um trecho menor."
        case .refused: "O modelo não gerou uma resposta para este conteúdo. Revise a entrada ou continue manualmente."
        case .failed: "Não foi possível gerar uma proposta. Tente novamente ou continue manualmente."
        case .timedOut: "A geração demorou demais e foi cancelada. Tente novamente."
        }
    }
}
