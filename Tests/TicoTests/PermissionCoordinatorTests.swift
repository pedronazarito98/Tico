import XCTest
@testable import Tico

@MainActor
final class PermissionCoordinatorTests: XCTestCase {
    func testAccessibilityAlsoAuthorizesGlobalCapture() {
        let coordinator = makeCoordinator(
            accessibilityGranted: true,
            inputMonitoring: .denied
        )

        XCTAssertTrue(coordinator.status.canCaptureGlobalInput)
        XCTAssertFalse(coordinator.status.inputMonitoringGranted)
    }

    func testInputMonitoringRequestRefreshesAuthorizationState() {
        var state = InputMonitoringAuthorizationState.notDetermined
        var requestCount = 0
        let coordinator = PermissionCoordinator(
            accessibilityCheck: { false },
            accessibilityRequest: { false },
            inputMonitoringCheck: { state },
            inputMonitoringRequest: {
                requestCount += 1
                state = .granted
                return true
            },
            settingsOpener: { _ in }
        )

        let refreshed = coordinator.requestInputMonitoring()

        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(refreshed.inputMonitoring, .granted)
        XCTAssertTrue(refreshed.canCaptureGlobalInput)
    }

    func testRefreshRevokesCaptureWhenCurrentAuthorizationIsDenied() {
        var state = InputMonitoringAuthorizationState.granted
        let coordinator = PermissionCoordinator(
            accessibilityCheck: { false },
            accessibilityRequest: { false },
            inputMonitoringCheck: { state },
            inputMonitoringRequest: { false },
            settingsOpener: { _ in }
        )
        XCTAssertTrue(coordinator.status.canCaptureGlobalInput)

        state = .denied
        let refreshed = coordinator.refresh()

        XCTAssertEqual(refreshed.inputMonitoring, .denied)
        XCTAssertFalse(refreshed.canCaptureGlobalInput)
        XCTAssertEqual(coordinator.status, refreshed)
    }

    func testUITestConfigurationReflectsGrantAndRevocationFromIsolatedFile() throws {
        let identifier = UUID().uuidString
        let dataDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TicoUITests-\(identifier)", isDirectory: true)
        let defaultsSuite = "com.pedronazarito.Tico.permission-tests.\(identifier)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsSuite))
        try FileManager.default.createDirectory(
            at: dataDirectory,
            withIntermediateDirectories: true
        )
        defer {
            defaults.removePersistentDomain(forName: defaultsSuite)
            try? FileManager.default.removeItem(at: dataDirectory)
        }

        let configuration = TicoLaunchConfiguration(
            dataDirectory: dataDirectory,
            defaults: defaults,
            isUITesting: true
        )
        let stateURL = dataDirectory.appendingPathComponent(
            TicoLaunchConfiguration.uiTestingPermissionStateFileName
        )
        try writePermissionState(
            accessibilityGranted: true,
            inputMonitoring: .granted,
            to: stateURL
        )

        let coordinator = configuration.makePermissionCoordinator()
        XCTAssertTrue(coordinator.status.accessibilityGranted)
        XCTAssertEqual(coordinator.status.inputMonitoring, .granted)
        XCTAssertTrue(coordinator.status.canCaptureGlobalInput)

        try writePermissionState(
            accessibilityGranted: false,
            inputMonitoring: .denied,
            to: stateURL
        )
        let refreshed = coordinator.refresh()

        XCTAssertFalse(refreshed.accessibilityGranted)
        XCTAssertEqual(refreshed.inputMonitoring, .denied)
        XCTAssertFalse(refreshed.canCaptureGlobalInput)
    }

    func testInputMonitoringSettingsUsesPrivacyListenEventPane() {
        var openedURL: URL?
        let coordinator = PermissionCoordinator(
            accessibilityCheck: { false },
            accessibilityRequest: { false },
            inputMonitoringCheck: { .denied },
            inputMonitoringRequest: { false },
            settingsOpener: { openedURL = $0 }
        )

        coordinator.openInputMonitoringSettings()

        XCTAssertTrue(openedURL?.absoluteString.contains("Privacy_ListenEvent") == true)
    }

    func testRevealApplicationUsesCurrentBundleURL() {
        let expectedURL = URL(fileURLWithPath: "/tmp/Tico.app")
        var revealedURL: URL?
        let coordinator = PermissionCoordinator(
            accessibilityCheck: { false },
            accessibilityRequest: { false },
            inputMonitoringCheck: { .denied },
            inputMonitoringRequest: { false },
            settingsOpener: { _ in },
            applicationURL: { expectedURL },
            fileRevealer: { revealedURL = $0 }
        )

        coordinator.revealApplicationInFinder()

        XCTAssertEqual(revealedURL, expectedURL)
    }

    private func makeCoordinator(
        accessibilityGranted: Bool,
        inputMonitoring: InputMonitoringAuthorizationState
    ) -> PermissionCoordinator {
        PermissionCoordinator(
            accessibilityCheck: { accessibilityGranted },
            accessibilityRequest: { accessibilityGranted },
            inputMonitoringCheck: { inputMonitoring },
            inputMonitoringRequest: { inputMonitoring == .granted },
            settingsOpener: { _ in }
        )
    }

    private func writePermissionState(
        accessibilityGranted: Bool,
        inputMonitoring: InputMonitoringAuthorizationState,
        to url: URL
    ) throws {
        let json = """
        {
          "accessibilityGranted": \(accessibilityGranted),
          "inputMonitoring": "\(inputMonitoring.rawValue)"
        }
        """
        try Data(json.utf8).write(to: url, options: .atomic)
    }
}
