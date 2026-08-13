import Foundation
import XCTest
@testable import Tico

final class ActionRunnerTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_234)

    func testOpenApplicationRoutesBundleIdentifierAndReturnsSuccess() async {
        let applicationLauncher = ApplicationLauncherSpy()
        let runner = makeRunner(applicationLauncher: applicationLauncher)

        let result = await runner.execute(.openApplication(bundleIdentifier: "com.apple.TextEdit"))

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.executedAt, fixedDate)
        XCTAssertEqual(applicationLauncher.bundleIdentifiers, ["com.apple.TextEdit"])
    }

    func testOpenURLRoutesURL() async {
        let urlLauncher = URLLauncherSpy()
        let runner = makeRunner(urlLauncher: urlLauncher)
        let url = URL(string: "https://example.com/path")!

        let result = await runner.execute(.openURL(url: url))

        XCTAssertTrue(result.success)
        XCTAssertEqual(urlLauncher.urls, [url])
    }

    func testNotificationRoutesTitleAndBody() async {
        let notificationService = NotificationServiceSpy()
        let runner = makeRunner(notificationService: notificationService)

        let result = await runner.execute(.notification(title: "Título", body: "Corpo"))

        XCTAssertTrue(result.success)
        XCTAssertEqual(notificationService.notifications, [.init(title: "Título", body: "Corpo")])
    }

    func testServiceFailureBecomesFailedExecutionResult() async {
        let urlLauncher = URLLauncherSpy()
        urlLauncher.error = TestError.expected
        let runner = makeRunner(urlLauncher: urlLauncher)

        let result = await runner.execute(.openURL(url: URL(string: "https://example.com")!))

        XCTAssertFalse(result.success)
        XCTAssertEqual(result.message, TestError.expected.localizedDescription)
        XCTAssertEqual(result.executedAt, fixedDate)
    }

    func testShellScriptWithoutApprovalHandlerIsRejectedWithoutExecution() async {
        let shellRunner = ShellScriptRunnerSpy()
        let runner = makeRunner(shellScriptRunner: shellRunner)

        let result = await runner.execute(.shellScript(command: "echo unsafe"))

        XCTAssertFalse(result.success)
        XCTAssertTrue(result.message.contains("aprovação explícita"))
        XCTAssertTrue(shellRunner.invocations.isEmpty)
    }

    func testShellScriptRejectedByApprovalHandlerIsNotExecuted() async {
        let shellRunner = ShellScriptRunnerSpy()
        let runner = makeRunner(shellScriptRunner: shellRunner)

        let result = await runner.execute(
            .shellScript(command: "echo unsafe"),
            scriptApproval: { _ in false }
        )

        XCTAssertFalse(result.success)
        XCTAssertTrue(shellRunner.invocations.isEmpty)
    }

    func testApprovedShellScriptReceivesExplicitApprovalAndTimeout() async {
        let shellRunner = ShellScriptRunnerSpy()
        shellRunner.result = ShellScriptExecutionResult(
            terminationStatus: 0,
            standardOutput: "ok",
            standardError: "",
            timedOut: false,
            duration: 0.1,
            outputWasTruncated: false
        )
        let runner = makeRunner(shellScriptRunner: shellRunner, scriptTimeout: 7)

        let result = await runner.execute(
            .shellScript(command: "printf ok"),
            scriptApproval: { command in command == "printf ok" }
        )

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.message, "ok")
        XCTAssertEqual(
            shellRunner.invocations,
            [.init(command: "printf ok", approved: true, timeout: 7)]
        )
    }

    func testTimedOutShellScriptReturnsFailure() async {
        let shellRunner = ShellScriptRunnerSpy()
        shellRunner.result = ShellScriptExecutionResult(
            terminationStatus: 15,
            standardOutput: "",
            standardError: "",
            timedOut: true,
            duration: 2,
            outputWasTruncated: false
        )
        let runner = makeRunner(shellScriptRunner: shellRunner)

        let result = await runner.execute(
            .shellScript(command: "sleep 60"),
            scriptApproval: { _ in true }
        )

        XCTAssertFalse(result.success)
        XCTAssertTrue(result.message.contains("tempo limite"))
    }

    func testConcreteShellRunnerRequiresApprovalBeforeLaunchingProcess() async {
        let runner = ShellScriptRunner()

        do {
            _ = try await runner.run(command: "printf no", approved: false, timeout: 1)
            XCTFail("A execução deveria exigir aprovação")
        } catch let error as ShellScriptRunnerError {
            XCTAssertEqual(error, .approvalRequired)
        } catch {
            XCTFail("Erro inesperado: \(error)")
        }
    }

    private func makeRunner(
        applicationLauncher: any ApplicationLaunching = ApplicationLauncherSpy(),
        urlLauncher: any URLLaunching = URLLauncherSpy(),
        notificationService: any NotificationDelivering = NotificationServiceSpy(),
        shellScriptRunner: any ShellScriptRunning = ShellScriptRunnerSpy(),
        scriptTimeout: TimeInterval = 15
    ) -> ActionRunner {
        ActionRunner(
            applicationLauncher: applicationLauncher,
            urlLauncher: urlLauncher,
            notificationService: notificationService,
            shellScriptRunner: shellScriptRunner,
            scriptTimeout: scriptTimeout,
            now: { self.fixedDate }
        )
    }
}

private enum TestError: LocalizedError {
    case expected

    var errorDescription: String? { "Falha esperada" }
}

private final class ApplicationLauncherSpy: ApplicationLaunching {
    var bundleIdentifiers: [String] = []
    var error: Error?

    func launch(bundleIdentifier: String) async throws {
        bundleIdentifiers.append(bundleIdentifier)
        if let error { throw error }
    }
}

private final class URLLauncherSpy: URLLaunching {
    var urls: [URL] = []
    var error: Error?

    func open(_ url: URL) throws {
        urls.append(url)
        if let error { throw error }
    }
}

private struct DeliveredNotification: Equatable {
    let title: String
    let body: String
}

private final class NotificationServiceSpy: NotificationDelivering {
    var notifications: [DeliveredNotification] = []
    var error: Error?

    func deliver(title: String, body: String) async throws {
        notifications.append(.init(title: title, body: body))
        if let error { throw error }
    }
}

private struct ShellInvocation: Equatable {
    let command: String
    let approved: Bool
    let timeout: TimeInterval
}

private final class ShellScriptRunnerSpy: ShellScriptRunning {
    var invocations: [ShellInvocation] = []
    var error: Error?
    var result = ShellScriptExecutionResult(
        terminationStatus: 0,
        standardOutput: "",
        standardError: "",
        timedOut: false,
        duration: 0,
        outputWasTruncated: false
    )

    func run(
        command: String,
        approved: Bool,
        timeout: TimeInterval
    ) async throws -> ShellScriptExecutionResult {
        invocations.append(.init(command: command, approved: approved, timeout: timeout))
        if let error { throw error }
        return result
    }
}
