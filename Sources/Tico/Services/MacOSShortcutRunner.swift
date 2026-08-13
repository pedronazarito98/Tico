import Foundation

protocol MacOSShortcutRunning {
    func run(name: String, input: String?, timeout: TimeInterval) async throws -> String
    func list() async throws -> [String]
}

enum MacOSShortcutRunnerError: LocalizedError {
    case emptyName
    case timedOut
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .emptyName:
            "Escolha um Atalho do macOS."
        case .timedOut:
            "O Atalho do macOS excedeu o tempo limite."
        case let .failed(message):
            "O Atalho do macOS falhou: \(message)"
        }
    }
}

final class MacOSShortcutRunner: MacOSShortcutRunning {
    private let executableURL: URL

    init(executableURL: URL = URL(fileURLWithPath: "/usr/bin/shortcuts")) {
        self.executableURL = executableURL
    }

    func run(name: String, input: String?, timeout: TimeInterval) async throws -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw MacOSShortcutRunnerError.emptyName }

        var temporaryInputURL: URL?
        var arguments = ["run", trimmedName]
        if let input, !input.isEmpty {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("Tico-\(UUID().uuidString).txt")
            try Data(input.utf8).write(to: url, options: .atomic)
            temporaryInputURL = url
            arguments += ["--input-path", url.path]
        }
        defer {
            if let temporaryInputURL {
                try? FileManager.default.removeItem(at: temporaryInputURL)
            }
        }
        return try await runProcess(arguments: arguments, timeout: timeout)
    }

    func list() async throws -> [String] {
        let output = try await runProcess(arguments: ["list"], timeout: 5)
        return output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func runProcess(arguments: [String], timeout: TimeInterval) async throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let resolver = ShortcutProcessResolver(continuation: continuation)
                process.terminationHandler = { process in
                    let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let error = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    if resolver.didTimeOut {
                        resolver.finish(.failure(MacOSShortcutRunnerError.timedOut))
                    } else if process.terminationStatus != 0 {
                        resolver.finish(.failure(MacOSShortcutRunnerError.failed(
                            String(decoding: error, as: UTF8.self)
                        )))
                    } else {
                        resolver.finish(.success(
                            String(decoding: output, as: UTF8.self)
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                        ))
                    }
                }
                do {
                    try process.run()
                } catch {
                    resolver.finish(.failure(MacOSShortcutRunnerError.failed(
                        error.localizedDescription
                    )))
                    return
                }
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                    guard process.isRunning else { return }
                    resolver.markTimedOut()
                    process.terminate()
                }
            }
        } onCancel: {
            if process.isRunning {
                process.terminate()
            }
        }
    }
}

/// `lock` guards the continuation, one-shot completion, and timeout flag.
/// Process termination, timeout, and cancellation may race, but only the first
/// `finish` resumes the continuation.
private final class ShortcutProcessResolver: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<String, Error>?
    private var finished = false
    private var timedOut = false

    init(continuation: CheckedContinuation<String, Error>) {
        self.continuation = continuation
    }

    var didTimeOut: Bool {
        lock.lock()
        defer { lock.unlock() }
        return timedOut
    }

    func markTimedOut() {
        lock.lock()
        timedOut = true
        lock.unlock()
    }

    func finish(_ result: Result<String, Error>) {
        lock.lock()
        guard !finished, let continuation else {
            lock.unlock()
            return
        }
        finished = true
        self.continuation = nil
        lock.unlock()
        continuation.resume(with: result)
    }
}
