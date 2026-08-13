import Foundation

protocol AppleScriptRunning {
    func run(
        source: String,
        approved: Bool,
        timeout: TimeInterval
    ) async throws -> String
}

enum AppleScriptRunnerError: LocalizedError, Equatable {
    case approvalRequired
    case emptySource
    case timedOut
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .approvalRequired:
            "A execução do AppleScript não foi aprovada."
        case .emptySource:
            "O AppleScript está vazio."
        case .timedOut:
            "O AppleScript excedeu o tempo limite."
        case let .executionFailed(message):
            "AppleScript falhou: \(message)"
        }
    }
}

final class AppleScriptRunner: AppleScriptRunning {
    private let processRunner: any ShellScriptRunning

    init(
        processRunner: any ShellScriptRunning = ShellScriptRunner(
            executableURL: URL(fileURLWithPath: "/usr/bin/osascript"),
            argumentsPrefix: ["-e"]
        )
    ) {
        self.processRunner = processRunner
    }

    func run(
        source: String,
        approved: Bool,
        timeout: TimeInterval
    ) async throws -> String {
        guard approved else { throw AppleScriptRunnerError.approvalRequired }
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppleScriptRunnerError.emptySource
        }
        let result = try await processRunner.run(
            command: source,
            approved: true,
            timeout: timeout
        )
        if result.timedOut {
            throw AppleScriptRunnerError.timedOut
        }
        guard result.succeeded else {
            throw AppleScriptRunnerError.executionFailed(result.standardError)
        }
        return result.standardOutput.isEmpty
            ? "AppleScript executado com sucesso."
            : result.standardOutput
    }
}

