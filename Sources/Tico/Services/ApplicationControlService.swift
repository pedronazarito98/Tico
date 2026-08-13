import AppKit
import Foundation

protocol ApplicationControlling {
    func perform(
        _ operation: ApplicationOperation,
        target: ApplicationTarget
    ) async throws
}

enum ApplicationControlError: LocalizedError, Equatable {
    case bundleIdentifierRequired
    case applicationNotRunning(String)
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .bundleIdentifierRequired:
            "Escolha um aplicativo para esta ação."
        case let .applicationNotRunning(identifier):
            "O aplicativo \(identifier) não está em execução."
        case let .operationFailed(message):
            message
        }
    }
}

final class ApplicationControlService: ApplicationControlling {
    private let launcher: any ApplicationLaunching
    private let workspace: NSWorkspace

    init(
        launcher: any ApplicationLaunching = ApplicationLauncher(),
        workspace: NSWorkspace = .shared
    ) {
        self.launcher = launcher
        self.workspace = workspace
    }

    func perform(
        _ operation: ApplicationOperation,
        target: ApplicationTarget
    ) async throws {
        let identifier = resolveBundleIdentifier(for: target)

        if operation == .open {
            guard let identifier else {
                throw ApplicationControlError.bundleIdentifierRequired
            }
            try await launcher.launch(bundleIdentifier: identifier)
            return
        }

        guard let application = runningApplication(target: target, identifier: identifier) else {
            if operation == .activate, let identifier {
                try await launcher.launch(bundleIdentifier: identifier)
                return
            }
            throw ApplicationControlError.applicationNotRunning(identifier ?? "selecionado")
        }

        let succeeded: Bool
        switch operation {
        case .open:
            succeeded = true
        case .activate:
            succeeded = application.activate(options: [.activateAllWindows])
        case .hide:
            succeeded = application.hide()
        case .quit:
            succeeded = application.terminate()
        }
        guard succeeded else {
            throw ApplicationControlError.operationFailed(
                "O macOS recusou a ação \(operation.rawValue) para \(application.localizedName ?? identifier ?? "o app")."
            )
        }
    }

    private func resolveBundleIdentifier(for target: ApplicationTarget) -> String? {
        switch target {
        case .frontmost:
            workspace.frontmostApplication?.bundleIdentifier
        case let .bundleIdentifier(identifier):
            identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func runningApplication(
        target: ApplicationTarget,
        identifier: String?
    ) -> NSRunningApplication? {
        switch target {
        case .frontmost:
            return workspace.frontmostApplication
        case .bundleIdentifier:
            guard let identifier else { return nil }
            return NSRunningApplication.runningApplications(
                withBundleIdentifier: identifier
            ).first
        }
    }
}
