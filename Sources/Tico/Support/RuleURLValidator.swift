import Foundation

enum RuleURLValidator {
    static func isValidWebURL(_ text: String) -> Bool {
        guard let url = URL(string: text) else { return false }
        return isValidWebURL(url)
    }

    static func isValidWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "https" || scheme == "http"
    }
}
