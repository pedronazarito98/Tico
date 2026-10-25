import Foundation

/// Intenções de apresentação. Não são persistidas; a configuração continua sendo
/// o contrato usado pelo executor e pelas regras antigas.
enum ContentRecipeIntent: String, CaseIterable, Identifiable {
    case google, apple, shortcut, custom
    var id: Self { self }
    var title: String {
        switch self {
        case .google: "Google"
        case .apple: "Documentação Apple"
        case .shortcut: "Atalho do macOS"
        case .custom: "Outro site"
        }
    }
    var symbol: String {
        switch self {
        case .google, .custom: "magnifyingglass"
        case .apple: "book.closed"
        case .shortcut: "square.stack.3d.up"
        }
    }
    var destination: ContentActionDestination {
        switch self {
        case .google: .search(.web)
        case .apple: .search(.documentation)
        case .shortcut: .macOSShortcut(name: "")
        case .custom: .search(.init(endpoint: "", queryParameter: "q"))
        }
    }
    init(destination: ContentActionDestination) {
        switch destination {
        case .macOSShortcut: self = .shortcut
        case let .search(search):
            self = search == .web ? .google : search == .documentation ? .apple : .custom
        }
    }
}

extension ContentActionDestination {
    var recipeTitle: String {
        switch self {
        case let .search(search):
            if search == .web { return "Pesquisar no Google" }
            if search == .documentation { return "Pesquisar na documentação Apple" }
            return "Pesquisar em \(URLComponents(string: search.endpoint)?.host ?? "outro site")"
        case let .macOSShortcut(name):
            return name.isEmpty ? "Enviar para um Atalho" : "Enviar para \(name)"
        }
    }

    var deliverySummary: String {
        switch self {
        case let .search(search):
            return "O texto será enviado a \(URLComponents(string: search.endpoint)?.host ?? "este site")."
        case let .macOSShortcut(name):
            return name.isEmpty ? "Escolha um Atalho que aceite entrada." : "O conteúdo será entregue ao Atalho “\(name)”."
        }
    }
}
