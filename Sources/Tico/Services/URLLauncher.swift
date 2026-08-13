import AppKit
import Foundation

protocol URLLaunching {
    func open(_ url: URL) throws
}

enum URLLauncherError: LocalizedError, Equatable {
    case unsupportedURL(URL)
    case openFailed(URL)

    var errorDescription: String? {
        switch self {
        case let .unsupportedURL(url):
            "A URL não pode ser aberta: \(url.absoluteString)"
        case let .openFailed(url):
            "O macOS não conseguiu abrir: \(url.absoluteString)"
        }
    }
}

final class URLLauncher: URLLaunching {
    private let canOpen: (URL) -> Bool
    private let opener: (URL) -> Bool

    init(
        canOpen: @escaping (URL) -> Bool = { NSWorkspace.shared.urlForApplication(toOpen: $0) != nil },
        opener: @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) }
    ) {
        self.canOpen = canOpen
        self.opener = opener
    }

    func open(_ url: URL) throws {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              canOpen(url) else {
            throw URLLauncherError.unsupportedURL(url)
        }
        guard opener(url) else {
            throw URLLauncherError.openFailed(url)
        }
    }
}
