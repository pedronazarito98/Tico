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
}
