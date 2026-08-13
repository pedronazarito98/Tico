import ApplicationServices
import AppKit
import Combine
import CoreGraphics
import Foundation
import IOKit.hidsystem
import OSLog

enum InputMonitoringAuthorizationState: String, Equatable, Sendable {
    case notDetermined
    case denied
    case granted

    var isGranted: Bool { self == .granted }
}

struct PermissionStatus: Equatable, Sendable {
    var accessibilityGranted: Bool
    var inputMonitoring: InputMonitoringAuthorizationState

    var inputMonitoringGranted: Bool {
        inputMonitoring.isGranted
    }

    var canCaptureGlobalInput: Bool {
        // Accessibility includes listening access. Input Monitoring is the
        // narrower permission and remains the preferred path for this app.
        inputMonitoringGranted || accessibilityGranted
    }
}

@MainActor
final class PermissionCoordinator: ObservableObject {
    @Published private(set) var status: PermissionStatus

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.pedronazarito.Tico",
        category: "Permissions"
    )
    private let accessibilityCheck: () -> Bool
    private let accessibilityRequest: () -> Bool
    private let inputMonitoringCheck: () -> InputMonitoringAuthorizationState
    private let inputMonitoringRequest: () -> Bool
    private let settingsOpener: (URL) -> Void
    private let applicationURL: () -> URL
    private let fileRevealer: (URL) -> Void

    init(
        accessibilityCheck: @escaping () -> Bool = { AXIsProcessTrusted() },
        accessibilityRequest: @escaping () -> Bool = {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            return AXIsProcessTrustedWithOptions(options as CFDictionary)
        },
        inputMonitoringCheck: @escaping () -> InputMonitoringAuthorizationState = {
            if CGPreflightListenEventAccess() {
                return .granted
            }

            switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
            case kIOHIDAccessTypeGranted:
                return .granted
            case kIOHIDAccessTypeDenied:
                return .denied
            default:
                return .notDetermined
            }
        },
        inputMonitoringRequest: @escaping () -> Bool = {
            // IOHIDRequestAccess reliably registers the app in the Input
            // Monitoring pane. The CoreGraphics request covers CGEventTap.
            let hidGranted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            let eventGranted = CGRequestListenEventAccess()
            return hidGranted || eventGranted
        },
        settingsOpener: @escaping (URL) -> Void = { NSWorkspace.shared.open($0) },
        applicationURL: @escaping () -> URL = { Bundle.main.bundleURL },
        fileRevealer: @escaping (URL) -> Void = {
            NSWorkspace.shared.activateFileViewerSelecting([$0])
        }
    ) {
        self.accessibilityCheck = accessibilityCheck
        self.accessibilityRequest = accessibilityRequest
        self.inputMonitoringCheck = inputMonitoringCheck
        self.inputMonitoringRequest = inputMonitoringRequest
        self.settingsOpener = settingsOpener
        self.applicationURL = applicationURL
        self.fileRevealer = fileRevealer
        status = PermissionStatus(
            accessibilityGranted: accessibilityCheck(),
            inputMonitoring: inputMonitoringCheck()
        )
    }

    @discardableResult
    func refresh() -> PermissionStatus {
        let refreshedStatus = PermissionStatus(
            accessibilityGranted: accessibilityCheck(),
            inputMonitoring: inputMonitoringCheck()
        )
        if refreshedStatus != status {
            status = refreshedStatus
        }
        logger.info(
            "Permission refresh: accessibility=\(refreshedStatus.accessibilityGranted, privacy: .public), inputMonitoring=\(refreshedStatus.inputMonitoring.rawValue, privacy: .public)"
        )
        return refreshedStatus
    }

    @discardableResult
    func requestAccessibility() -> PermissionStatus {
        logger.info("Requesting Accessibility access")
        _ = accessibilityRequest()
        return refresh()
    }

    @discardableResult
    func requestInputMonitoring() -> PermissionStatus {
        logger.info("Requesting Input Monitoring access")
        _ = inputMonitoringRequest()
        return refresh()
    }

    func openAccessibilitySettings() {
        openSettingsPane("Privacy_Accessibility")
    }

    func openInputMonitoringSettings() {
        openSettingsPane("Privacy_ListenEvent")
    }

    func revealApplicationInFinder() {
        fileRevealer(applicationURL())
    }

    private func openSettingsPane(_ pane: String) {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?\(pane)"
        ) else { return }
        settingsOpener(url)
    }
}
