import Foundation

struct TicoLaunchConfiguration {
    static let uiTestingArgument = "--ui-testing"
    static let uiTestingDataDirectoryEnvironment = "TICO_UI_TEST_DATA_DIRECTORY"
    static let uiTestingDefaultsSuiteEnvironment = "TICO_UI_TEST_DEFAULTS_SUITE"
    static let fixedUserHomeEnvironment = "CFFIXED_USER_HOME"

    let dataDirectory: URL?
    let defaults: UserDefaults
    let isUITesting: Bool

    @MainActor
    static func current(processInfo: ProcessInfo = .processInfo) -> TicoLaunchConfiguration {
        guard processInfo.arguments.contains(uiTestingArgument) else {
            return TicoLaunchConfiguration(
                dataDirectory: nil,
                defaults: .standard,
                isUITesting: false
            )
        }

        guard let directoryPath = processInfo.environment[uiTestingDataDirectoryEnvironment],
              let defaultsSuite = processInfo.environment[uiTestingDefaultsSuiteEnvironment],
              let fixedUserHomePath = processInfo.environment[fixedUserHomeEnvironment],
              !defaultsSuite.isEmpty else {
            preconditionFailure(
                "UI testing requires isolated data, defaults, and user home values."
            )
        }

        let dataDirectory = URL(fileURLWithPath: directoryPath, isDirectory: true)
            .standardizedFileURL
        let fixedUserHome = URL(fileURLWithPath: fixedUserHomePath, isDirectory: true)
            .standardizedFileURL
        guard dataDirectory.lastPathComponent.hasPrefix("TicoUITests-") else {
            preconditionFailure("UI testing data must use a TicoUITests-* directory.")
        }
        guard fixedUserHome == dataDirectory else {
            preconditionFailure("UI testing user home must match its isolated data directory.")
        }
        guard let defaults = UserDefaults(suiteName: defaultsSuite) else {
            preconditionFailure("UI testing defaults suite could not be created.")
        }

        return TicoLaunchConfiguration(
            dataDirectory: dataDirectory,
            defaults: defaults,
            isUITesting: true
        )
    }

    func fileURL(named name: String) -> URL? {
        dataDirectory?.appendingPathComponent(name, isDirectory: false)
    }

    @MainActor
    func makePermissionCoordinator() -> PermissionCoordinator {
        guard isUITesting else { return PermissionCoordinator() }

        return PermissionCoordinator(
            accessibilityCheck: { false },
            accessibilityRequest: { false },
            inputMonitoringCheck: { .notDetermined },
            inputMonitoringRequest: { false },
            settingsOpener: { _ in },
            applicationURL: { Bundle.main.bundleURL },
            fileRevealer: { _ in }
        )
    }

    func makeMacOSShortcutCatalog() -> any MacOSShortcutRunning {
        if isUITesting {
            return UITestMacOSShortcutRunner()
        }

        return MacOSShortcutRunner()
    }
}

private struct UITestMacOSShortcutRunner: MacOSShortcutRunning {
    func run(name: String, input: String?, timeout: TimeInterval) async throws -> String {
        ""
    }

    func list() async throws -> [String] {
        []
    }
}
