import Foundation

/// Catálogo de apresentação compartilhado pelo criador e pelos seletores de ação.
/// A busca produz as mesmas escolhas em todos os caminhos; não executa automações.
struct ActionCatalogEntry: Identifiable {
    enum Category: String, CaseIterable, Identifiable {
        case applications = "Apps"
        case windows = "Janelas"
        case content = "Texto e arquivos"
        case keyboard = "Teclado"
        case other = "Outras ações"
        case advanced = "Avançado"

        var id: Self { self }
    }

    let id: String
    let title: String
    let detail: String
    let category: Category
    let action: ShortcutAction
    let isSuggested: Bool
    private let keywords: String

    func matches(_ query: String) -> Bool {
        let ignoredWords: Set<String> = ["a", "o", "as", "os", "de", "da", "do", "para", "um", "uma", "eu", "quero"]
        let words = Self.normalized(query).split(whereSeparator: \.isWhitespace)
            .map(String.init).filter { !ignoredWords.contains($0) }
        let searchable = Self.normalized("\(title) \(detail) \(category.rawValue) \(keywords)")
        return words.allSatisfy(searchable.contains)
    }

    static func entries(applications: [ApplicationChoice]) -> [Self] {
        let sortedApps = applications.sorted {
            if $0.isRunning != $1.isRunning { return $0.isRunning }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        var result = sortedApps.enumerated().map { index, app in
            Self(id: "app.\(app.id)", title: "Abrir \(app.name)",
                 detail: app.isRunning ? "Em execução" : "", category: .applications,
                 action: .openApplication(bundleIdentifier: app.id), isSuggested: index < 3,
                 keywords: "abrir app aplicativo")
        }
        result += WindowOperation.allCases.map {
            Self(id: "window.\($0.rawValue)", title: windowTitle($0),
                 detail: "Janela em uso", category: .windows,
                 action: .window(target: .frontmost, operation: $0),
                 isSuggested: [.leftHalf, .center].contains($0),
                 keywords: "mover organizar janela \($0.displayName)")
        }
        result += [
            Self(id: "content.search", title: "Pesquisar texto selecionado",
                 detail: "Escolha onde pesquisar", category: .content,
                 action: .content(ContentActionConfiguration()), isSuggested: true,
                 keywords: "conteúdo selecao buscar pesquisa documentação"),
            Self(id: "content.shortcut", title: "Enviar conteúdo a um Atalho",
                 detail: "Texto, link ou arquivos", category: .content,
                 action: .content(ContentActionConfiguration(source: .provided,
                    destination: .macOSShortcut(name: ""))), isSuggested: true,
                 keywords: "conteúdo executar macOS"),
        ]
        result += KeyboardActionPreset.allCases.map {
            Self(id: "keyboard.\($0.id)", title: $0.title, detail: "No app em uso",
                 category: .keyboard, action: $0.action, isSuggested: false,
                 keywords: "teclado combinação")
        }
        result += ApplicationOperation.allCases.filter { $0 != .open }.map {
            Self(id: "application.\($0.rawValue)", title: "\($0.displayName) o app em uso",
                 detail: "", category: .applications,
                 action: .application(target: .frontmost, operation: $0),
                 isSuggested: false, keywords: "controlar aplicativo")
        }
        result += RuleActionKind.allCases.filter {
            ![.openApplication, .controlApplication, .controlWindow, .content].contains($0)
        }.map {
            Self(id: "kind.\($0.rawValue)", title: $0.title, detail: $0.summary,
                 category: $0.isAdvanced ? .advanced : $0 == .keyboardShortcut ? .keyboard : .other,
                 action: $0.makeAction(applications: applications), isSuggested: $0 == .openURL,
                 keywords: "")
        }
        return result
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    private static func windowTitle(_ operation: WindowOperation) -> String {
        switch operation {
        case .leftHalf: "Mover para a esquerda"
        case .rightHalf: "Mover para a direita"
        case .center: "Centralizar janela"
        default: WindowActionChoices.title(operation)
        }
    }
}
