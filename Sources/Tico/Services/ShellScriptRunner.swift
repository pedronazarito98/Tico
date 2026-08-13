import Foundation

protocol ShellScriptRunning {
    func run(command: String, approved: Bool, timeout: TimeInterval) async throws -> ShellScriptExecutionResult
}

struct ShellScriptExecutionResult: Equatable, Sendable {
    let terminationStatus: Int32
    let standardOutput: String
    let standardError: String
    let timedOut: Bool
    let duration: TimeInterval
    let outputWasTruncated: Bool

    var succeeded: Bool {
        !timedOut && terminationStatus == 0
    }
}

enum ShellScriptRunnerError: LocalizedError, Equatable {
    case approvalRequired
    case emptyCommand
    case invalidTimeout
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case .approvalRequired:
            "A execução do script não foi aprovada."
        case .emptyCommand:
            "O comando do script está vazio."
        case .invalidTimeout:
            "O tempo limite do script deve ser maior que zero."
        case let .launchFailed(message):
            "Não foi possível iniciar o script: \(message)"
        }
    }
}

final class ShellScriptRunner: ShellScriptRunning {
    private let executableURL: URL
    private let argumentsPrefix: [String]
    private let environment: [String: String]?
    private let now: () -> Date
    private let maximumCapturedBytes: Int

    init(
        executableURL: URL = URL(fileURLWithPath: "/bin/zsh"),
        argumentsPrefix: [String] = ["-c"],
        environment: [String: String]? = nil,
        maximumCapturedBytes: Int = 1_048_576,
        now: @escaping () -> Date = Date.init
    ) {
        self.executableURL = executableURL
        self.argumentsPrefix = argumentsPrefix
        self.environment = environment
        self.maximumCapturedBytes = max(0, maximumCapturedBytes)
        self.now = now
    }

    func run(
        command: String,
        approved: Bool,
        timeout: TimeInterval = 15
    ) async throws -> ShellScriptExecutionResult {
        guard approved else { throw ShellScriptRunnerError.approvalRequired }
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ShellScriptRunnerError.emptyCommand
        }
        guard timeout > 0 else { throw ShellScriptRunnerError.invalidTimeout }
        try Task.checkCancellation()

        let process = Process()
        let standardOutputPipe = Pipe()
        let standardErrorPipe = Pipe()
        let output = BoundedOutputBuffer(limit: maximumCapturedBytes)
        let errorOutput = BoundedOutputBuffer(limit: maximumCapturedBytes)
        let startedAt = now()
        let resolution = ProcessResolution()

        process.executableURL = executableURL
        process.arguments = argumentsPrefix + [command]
        process.environment = environment
        process.standardOutput = standardOutputPipe
        process.standardError = standardErrorPipe

        standardOutputPipe.fileHandleForReading.readabilityHandler = { handle in
            output.append(handle.availableData)
        }
        standardErrorPipe.fileHandleForReading.readabilityHandler = { handle in
            errorOutput.append(handle.availableData)
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                resolution.install(continuation)

                process.terminationHandler = { [now] terminatedProcess in
                    standardOutputPipe.fileHandleForReading.readabilityHandler = nil
                    standardErrorPipe.fileHandleForReading.readabilityHandler = nil
                    output.append(standardOutputPipe.fileHandleForReading.readDataToEndOfFile())
                    errorOutput.append(standardErrorPipe.fileHandleForReading.readDataToEndOfFile())

                    resolution.finish(
                        .success(
                            ShellScriptExecutionResult(
                                terminationStatus: terminatedProcess.terminationStatus,
                                standardOutput: output.string,
                                standardError: errorOutput.string,
                                timedOut: resolution.didTimeOut,
                                duration: max(0, now().timeIntervalSince(startedAt)),
                                outputWasTruncated: output.wasTruncated || errorOutput.wasTruncated
                            )
                        )
                    )
                }

                do {
                    if Task.isCancelled {
                        resolution.finish(.failure(CancellationError()))
                        return
                    }
                    try process.run()
                } catch {
                    standardOutputPipe.fileHandleForReading.readabilityHandler = nil
                    standardErrorPipe.fileHandleForReading.readabilityHandler = nil
                    resolution.finish(.failure(ShellScriptRunnerError.launchFailed(error.localizedDescription)))
                    return
                }

                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                    guard process.isRunning else { return }
                    resolution.markTimedOut()
                    process.terminate()

                    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1) {
                        guard process.isRunning else { return }
                        kill(process.processIdentifier, SIGKILL)
                    }
                }
            }
        } onCancel: {
            if process.isRunning {
                process.terminate()
            }
        }
    }
}

/// Pipe readability callbacks and process termination can append concurrently;
/// `lock` protects both the bounded bytes and the truncation marker.
private final class BoundedOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private let limit: Int
    private var data = Data()
    private var truncated = false

    init(limit: Int) {
        self.limit = limit
    }

    func append(_ newData: Data) {
        guard !newData.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }

        let remaining = max(0, limit - data.count)
        if newData.count > remaining {
            truncated = true
        }
        if remaining > 0 {
            data.append(newData.prefix(remaining))
        }
    }

    var string: String {
        lock.lock()
        defer { lock.unlock() }
        return String(decoding: data, as: UTF8.self)
    }

    var wasTruncated: Bool {
        lock.lock()
        defer { lock.unlock() }
        return truncated
    }
}

/// `lock` protects the continuation, one-shot completion, and timeout flag.
/// Termination, timeout, and cancellation are allowed to race; only the first
/// `finish` resumes the continuation.
private final class ProcessResolution: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<ShellScriptExecutionResult, Error>?
    private var finished = false
    private var timedOut = false

    var didTimeOut: Bool {
        lock.lock()
        defer { lock.unlock() }
        return timedOut
    }

    func install(_ continuation: CheckedContinuation<ShellScriptExecutionResult, Error>) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
    }

    func markTimedOut() {
        lock.lock()
        timedOut = true
        lock.unlock()
    }

    func finish(_ result: Result<ShellScriptExecutionResult, Error>) {
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
