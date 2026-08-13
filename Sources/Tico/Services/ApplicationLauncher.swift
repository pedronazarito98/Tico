import AppKit
import Foundation

protocol ApplicationLaunching {
    func launch(bundleIdentifier: String) async throws
}

enum ApplicationLauncherError: LocalizedError, Equatable {
    case invalidBundleIdentifier
    case applicationNotFound(String)
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidBundleIdentifier:
            "O identificador do aplicativo está vazio."
        case let .applicationNotFound(bundleIdentifier):
            "Nenhum aplicativo foi encontrado para \(bundleIdentifier)."
        case let .launchFailed(message):
            "Não foi possível abrir o aplicativo: \(message)"
        }
    }
}

final class ApplicationLauncher: ApplicationLaunching {
    typealias ApplicationURLProvider = (String) -> URL?
    typealias ApplicationOpener = (URL, @escaping (Error?) -> Void) -> Void

    private let applicationURLProvider: ApplicationURLProvider
    private let applicationOpener: ApplicationOpener

    init(
        applicationURLProvider: @escaping ApplicationURLProvider = {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0)
        },
        applicationOpener: @escaping ApplicationOpener = { url, completion in
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
                completion(error)
            }
        }
    ) {
        self.applicationURLProvider = applicationURLProvider
        self.applicationOpener = applicationOpener
    }

    func launch(bundleIdentifier: String) async throws {
        let identifier = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identifier.isEmpty else {
            throw ApplicationLauncherError.invalidBundleIdentifier
        }
        guard let applicationURL = applicationURLProvider(identifier) else {
            throw ApplicationLauncherError.applicationNotFound(identifier)
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            applicationOpener(applicationURL) { error in
                if let error {
                    continuation.resume(throwing: ApplicationLauncherError.launchFailed(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
