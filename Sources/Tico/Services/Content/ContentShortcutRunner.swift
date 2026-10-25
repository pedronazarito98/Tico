import Darwin
import Foundation

protocol ContentShortcutRunning {
    func run(name: String, content: AutomationContent, timeout: TimeInterval) async throws
}

/// Atalhos recebem argumentos diretamente, sem shell. Entrada textual fica em
/// diretório 0700/arquivo 0600 apenas durante o processo; saída e stderr são
/// descartados para impedir que conteúdo pessoal alcance relatórios ou logs.
final class ContentShortcutRunner: ContentShortcutRunning {
    func run(name: String, content: AutomationContent, timeout: TimeInterval) async throws {
        try Task.checkCancellation()
        try content.validate()
        guard ContentActionConfiguration(destination: .macOSShortcut(name: name)).validationMessage == nil else {
            throw ContentActionError.invalidConfiguration
        }
        let input = try TemporaryContentInput(content: content)
        defer { input.cleanup() }
        let operation = ContentShortcutProcess()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                operation.start(
                    name: name,
                    paths: input.urls.map(\.path),
                    timeout: min(max(timeout.isFinite ? timeout : 15, 0.25), 300),
                    continuation: continuation
                )
            }
        } onCancel: {
            operation.cancel()
        }
        try Task.checkCancellation()
    }
}

/// Owner exclusivo dos arquivos temporários e acessos security-scoped desta execução.
/// A entrada de arquivos usa somente URLs fornecidas explicitamente; não enumera pastas.
private final class TemporaryContentInput {
    let urls: [URL]
    private let directory: URL?
    private let scopedURLs: [URL]

    init(content: AutomationContent) throws {
        switch content {
        case let .files(urls):
            var scopes: [URL] = []
            do {
                for url in urls {
                    if url.startAccessingSecurityScopedResource() { scopes.append(url) }
                    let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
                    guard values.isRegularFile == true, values.isSymbolicLink != true,
                          let size = values.fileSize, size <= AutomationContent.maximumFileBytes,
                          FileManager.default.isReadableFile(atPath: url.path) else {
                        throw ContentActionError.invalidFiles
                    }
                }
            } catch {
                scopes.forEach { $0.stopAccessingSecurityScopedResource() }
                throw ContentActionError.invalidFiles
            }
            self.urls = urls
            scopedURLs = scopes
            directory = nil
        case .text, .webURL:
            let text: String
            switch content {
            case let .text(value): text = value
            case let .webURL(url): text = url.absoluteString
            case .files: throw ContentActionError.incompatibleContent
            }
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent("Tico-ContentInputs", isDirectory: true)
            try Self.prepareRoot(root)
            let directory = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
                                                        attributes: [.posixPermissions: 0o700])
                let file = directory.appendingPathComponent(content.kind == .webURL ? "input.url.txt" : "input.txt")
                guard FileManager.default.createFile(atPath: file.path, contents: Data(text.utf8),
                                                      attributes: [.posixPermissions: 0o600]) else {
                    throw ContentActionError.shortcutFailed
                }
                self.urls = [file]
                self.directory = directory
                scopedURLs = []
            } catch {
                try? FileManager.default.removeItem(at: directory)
                throw ContentActionError.shortcutFailed
            }
        }
    }

    /// Remove somente diretórios UUID próprios, antigos e não simbólicos. Isso
    /// recupera resíduos de encerramento abrupto na próxima execução; não lê
    /// conteúdo dos arquivos e nunca remove uma entrada ainda dentro do timeout.
    private static func prepareRoot(_ root: URL) throws {
        let manager = FileManager.default
        do {
            if !manager.fileExists(atPath: root.path) {
                try manager.createDirectory(at: root, withIntermediateDirectories: false,
                                            attributes: [.posixPermissions: 0o700])
            }
            let values = try root.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            let attributes = try manager.attributesOfItem(atPath: root.path)
            guard values.isDirectory == true, values.isSymbolicLink != true,
                  (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == getuid() else {
                throw ContentActionError.shortcutFailed
            }
            try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: root.path)
            let entries = try manager.contentsOfDirectory(at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .creationDateKey],
                options: [.skipsHiddenFiles])
            for entry in entries where UUID(uuidString: entry.lastPathComponent) != nil {
                guard let values = try? entry.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .creationDateKey]),
                      values.isDirectory == true, values.isSymbolicLink != true,
                      let created = values.creationDate, Date().timeIntervalSince(created) > 900 else { continue }
                try? manager.removeItem(at: entry)
            }
        } catch { throw ContentActionError.shortcutFailed }
    }

    func cleanup() {
        if let directory { try? FileManager.default.removeItem(at: directory) }
        scopedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
    }
}

/// `lock` serializa início, motivo de cancelamento e término. A continuação só
/// conclui após término do processo (ou falha em iniciar), mantendo a entrada viva.
/// TERM é seguido de KILL após 500 ms; tarefas do Atalhos já entregues ao sistema
/// podem ter produzido efeitos irreversíveis antes do cancelamento.
private final class ContentShortcutProcess: @unchecked Sendable {
    private let lock = NSLock()
    private let process = Process()
    private var continuation: CheckedContinuation<Void, Error>?
    private var stopReason: ContentActionError?
    private var finished = false

    func start(name: String, paths: [String], timeout: TimeInterval,
               continuation: CheckedContinuation<Void, Error>) {
        lock.lock()
        guard stopReason == nil else {
            let reason = stopReason ?? .cancelled
            lock.unlock()
            continuation.resume(throwing: reason)
            return
        }
        self.continuation = continuation
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["run", name, "--input-path"] + paths + ["--output-path", "/dev/null"]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [self] process in complete(status: process.terminationStatus) }
        do { try process.run() }
        catch {
            self.continuation = nil
            process.terminationHandler = nil
            process.arguments = nil
            finished = true
            lock.unlock()
            continuation.resume(throwing: ContentActionError.shortcutFailed)
            return
        }
        lock.unlock()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) { [self] in
            stop(reason: .shortcutTimedOut)
        }
    }

    func cancel() { stop(reason: .cancelled) }

    private func stop(reason: ContentActionError) {
        lock.lock()
        guard !finished, stopReason == nil else { lock.unlock(); return }
        stopReason = reason
        if process.isRunning { process.terminate() }
        lock.unlock()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) { [self] in
            lock.lock()
            defer { lock.unlock() }
            if !finished, process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
    }

    private func complete(status: Int32) {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finished = true
        let continuation = self.continuation
        self.continuation = nil
        let reason = stopReason
        process.terminationHandler = nil
        process.arguments = nil
        lock.unlock()
        if let reason { continuation?.resume(throwing: reason) }
        else if status != 0 { continuation?.resume(throwing: ContentActionError.shortcutFailed) }
        else { continuation?.resume() }
    }
}
