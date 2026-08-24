import Foundation

struct TicoLaunchConfiguration {
    static let uiTestingArgument = "--ui-testing"
    static let uiTestingDataDirectoryEnvironment = "TICO_UI_TEST_DATA_DIRECTORY"
    static let uiTestingDefaultsSuiteEnvironment = "TICO_UI_TEST_DEFAULTS_SUITE"
    static let fixedUserHomeEnvironment = "CFFIXED_USER_HOME"
    static let uiTestingPermissionStateFileName = "ui-test-permissions.json"

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

        let permissionStateURL = fileURL(named: Self.uiTestingPermissionStateFileName)
        return PermissionCoordinator(
            accessibilityCheck: {
                Self.loadUITestPermissionState(from: permissionStateURL)
                    .accessibilityGranted
            },
            accessibilityRequest: { false },
            inputMonitoringCheck: {
                Self.loadUITestPermissionState(from: permissionStateURL)
                    .inputMonitoringState
            },
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

    /// Lê permissões simuladas somente do diretório temporário validado do XCUITest.
    ///
    /// O processo do teste pode alterar esse arquivo enquanto o app está aberto,
    /// permitindo validar concessão e revogação sem solicitar ou modificar o TCC real.
    /// Dados ausentes ou inválidos sempre resultam no estado mais restritivo.
    ///
    /// Paralelo com React: funciona como um provider de teste injetado no composition
    /// root, mas o arquivo é relido porque o runner e o aplicativo são processos separados.
    private static func loadUITestPermissionState(from url: URL?) -> UITestPermissionState {
        guard let url,
              let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(UITestPermissionState.self, from: data) else {
            return .restricted
        }
        return state
    }
}

private struct UITestPermissionState: Decodable {
    let accessibilityGranted: Bool
    let inputMonitoring: String

    static let restricted = UITestPermissionState(
        accessibilityGranted: false,
        inputMonitoring: InputMonitoringAuthorizationState.notDetermined.rawValue
    )

    var inputMonitoringState: InputMonitoringAuthorizationState {
        InputMonitoringAuthorizationState(rawValue: inputMonitoring) ?? .notDetermined
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
