import Foundation

/// Entrada efêmera de uma execução. Não conforma a Codable: conteúdo fornecido
/// pelo usuário nunca integra regras, preferências ou relatórios de execução.
/// Paralelo com React: é o valor transitório de uma interação, separado do formulário salvo.
enum AutomationContent: Sendable, Equatable {
    case text(String)
    case webURL(URL)
    case files([URL])

    static let maximumTextBytes = 65_536
    static let maximumFiles = 20
    static let maximumFileBytes = 100 * 1_024 * 1_024

    var kind: ContentKind {
        switch self {
        case .text: .text
        case .webURL: .webURL
        case .files: .files
        }
    }

    /// Somente metadados podem sair da sessão para status e acessibilidade.
    var summary: String {
        switch self {
        case let .text(value): "Texto · \(value.count) caracteres"
        case .webURL: "Link pronto"
        case let .files(urls): "\(urls.count) arquivo(s)"
        }
    }

    func validate() throws {
        switch self {
        case let .text(value):
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ContentActionError.emptyContent
            }
            guard value.utf8.count <= Self.maximumTextBytes else { throw ContentActionError.contentTooLarge }
        case let .webURL(url):
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
                  let host = components.host, !host.isEmpty,
                  components.user == nil, components.password == nil else {
                throw ContentActionError.invalidURL
            }
            guard url.absoluteString.utf8.count <= 8_192 else { throw ContentActionError.contentTooLarge }
        case let .files(urls):
            guard !urls.isEmpty else { throw ContentActionError.emptyContent }
            guard urls.count <= Self.maximumFiles, urls.allSatisfy(\.isFileURL),
                  Set(urls).count == urls.count else { throw ContentActionError.invalidFiles }
        }
    }
}

enum ContentKind: String, CaseIterable, Sendable {
    case text, webURL, files

    var title: String {
        switch self {
        case .text: "Texto"
        case .webURL: "Link"
        case .files: "Arquivos"
        }
    }
}

/// Erros fechados e sanitizados: nunca carregam seleção, caminho, URL final ou saída de processo.
enum ContentActionError: Error, LocalizedError, Sendable, Equatable {
    case emptyContent, contentTooLarge, searchTooLong, invalidURL, invalidFiles, incompatibleContent
    case invalidConfiguration, permissionRequired, selectionUnavailable, secureField
    case focusChanged, captureTimedOut, cancelled, shortcutFailed, shortcutTimedOut, launchFailed

    var errorDescription: String? {
        switch self {
        case .emptyContent: "Forneça conteúdo antes de executar."
        case .contentTooLarge: "O conteúdo excede o limite permitido. Use até 64 KB de texto ou um link de até 8 KB."
        case .searchTooLong: "A pesquisa aceita até 8 KB de texto ou link. Reduza a seleção antes de pesquisar."
        case .invalidURL: "Use um endereço HTTP ou HTTPS completo, sem credenciais."
        case .invalidFiles: "Escolha até 20 arquivos regulares, com até 100 MB cada, sem pastas ou links simbólicos."
        case .incompatibleContent: "Esta ação não aceita esse tipo de conteúdo."
        case .invalidConfiguration: "Revise o destino desta ação de conteúdo."
        case .permissionRequired: "Permita Acessibilidade ao Tico para usar texto selecionado."
        case .selectionUnavailable: "O aplicativo não disponibilizou texto selecionado. Forneça o conteúdo no painel."
        case .secureField: "O Tico não captura seleção de campos protegidos."
        case .focusChanged: "O foco mudou durante a captura. Selecione novamente e repita a ação."
        case .captureTimedOut: "O aplicativo não respondeu à captura a tempo."
        case .cancelled: "A execução foi cancelada."
        case .shortcutFailed: "O Atalho do macOS não concluiu. Verifique sua configuração no app Atalhos."
        case .shortcutTimedOut: "O Atalho do macOS excedeu o tempo limite e seu processo foi encerrado."
        case .launchFailed: "Não foi possível abrir o destino da pesquisa."
        }
    }
}
