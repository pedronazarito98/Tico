import Foundation

/// Somente a receita é persistida. A seleção e os arquivos são resolvidos na execução.
struct ContentActionConfiguration: Codable, Hashable, Sendable {
    var source: ContentInputSource = .selection
    var selectionTiming: ContentSelectionTiming = .workflowStart
    var destination: ContentActionDestination = .search(.documentation)

    var validationMessage: String? {
        switch destination {
        case let .search(search): search.validationMessage
        case let .macOSShortcut(name):
            name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.utf8.count > 512
                || name.contains("\0") || name.hasPrefix("-")
                ? "Informe um nome válido do app Atalhos (até 512 bytes)." : nil
        }
    }

    func accepts(_ content: AutomationContent) -> Bool {
        switch destination {
        case .search: content.kind != .files
        case .macOSShortcut: true
        }
    }
}

enum ContentInputSource: String, Codable, CaseIterable, Hashable, Sendable {
    case provided, selection
    var title: String { self == .provided ? "Conteúdo do painel" : "Texto selecionado" }
}

enum ContentSelectionTiming: String, Codable, CaseIterable, Hashable, Sendable {
    case workflowStart, actionStart
    var title: String { self == .workflowStart ? "No início da sequência" : "Ao executar esta ação" }
}

enum ContentActionDestination: Codable, Hashable, Sendable {
    case search(ContentSearchDestination)
    case macOSShortcut(name: String)
}

/// O termo é sempre um valor de query codificado, nunca substituição livre em uma URL.
struct ContentSearchDestination: Codable, Hashable, Sendable {
    var endpoint: String
    var queryParameter: String

    static let documentation = Self(endpoint: "https://developer.apple.com/search/", queryParameter: "q")
    static let web = Self(endpoint: "https://www.google.com/search", queryParameter: "q")

    var validationMessage: String? {
        guard endpoint.utf8.count <= 2_048,
              let components = URLComponents(string: endpoint),
              components.scheme?.lowercased() == "https",
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              components.fragment == nil,
              components.url != nil else {
            return "Use um endereço HTTPS completo, sem credenciais ou fragmento."
        }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
        guard !queryParameter.isEmpty, queryParameter.utf8.count <= 64,
              queryParameter.unicodeScalars.allSatisfy(allowed.contains) else {
            return "Use um parâmetro de busca com letras, números, hífen ou sublinhado."
        }
        return nil
    }

    func url(for content: AutomationContent) throws -> URL {
        try content.validate()
        guard validationMessage == nil, var components = URLComponents(string: endpoint) else {
            throw ContentActionError.invalidConfiguration
        }
        let query: String
        switch content {
        case let .text(text): query = text
        case let .webURL(url): query = url.absoluteString
        case .files: throw ContentActionError.incompatibleContent
        }
        guard query.utf8.count <= 8_192 else { throw ContentActionError.searchTooLong }
        let unreserved = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        var items = (components.queryItems ?? []).filter { $0.name != queryParameter }
        items.append(URLQueryItem(name: queryParameter, value: query))
        components.percentEncodedQuery = try items.map { item in
            guard let name = item.name.addingPercentEncoding(withAllowedCharacters: unreserved),
                  let value = (item.value ?? "").addingPercentEncoding(withAllowedCharacters: unreserved) else {
                throw ContentActionError.invalidURL
            }
            return "\(name)=\(value)"
        }.joined(separator: "&")
        guard let url = components.url, url.absoluteString.utf8.count <= 32_768 else {
            throw ContentActionError.contentTooLarge
        }
        return url
    }
}

/// Snapshot compartilhado por todas as etapas. Um erro de captura é preservado e
/// não provoca nova leitura em outro aplicativo após uma etapa mudar o foco.
struct ContentExecutionContext: Sendable {
    var providedContent: AutomationContent?
    var initialSelection: Result<AutomationContent, ContentActionError>?

    init(providedContent: AutomationContent? = nil, initialSelection: Result<AutomationContent, ContentActionError>? = nil) {
        self.providedContent = providedContent
        self.initialSelection = initialSelection
    }
}
