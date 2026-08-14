import AppKit
import SwiftUI
import XCTest
@testable import Tico

final class MacOS26ShellBehaviorTests: XCTestCase {
    // SwiftUI resolves AX nodes asynchronously; retaining the hidden host window
    // avoids deallocating its accessibility graph while later XCTest work is running.
    @MainActor private static var retainedAccessibilityWindows: [NSWindow] = []

    func testReselectingCurrentSectionClearsSearchAndPreservesDestination() throws {
        let selection = try XCTUnwrap(
            ShellNavigationSelection.resolve(
                requestedSection: .laboratory,
                currentSection: .laboratory
            )
        )

        XCTAssertEqual(selection.selectedSection, .laboratory)
        XCTAssertFalse(selection.changesDestination)
        XCTAssertEqual(selection.searchText, "")
        XCTAssertTrue(selection.dismissesSearch)
    }

    func testCaptureGlassStateDistinguishesPermissionPausedActiveAndLimitedModes() {
        XCTAssertEqual(
            CaptureGlassState.resolve(
                captureIsRunning: false,
                permissionsAreReady: false,
                captureMode: .stopped
            ),
            .permissionRequired
        )
        XCTAssertEqual(
            CaptureGlassState.resolve(
                captureIsRunning: false,
                permissionsAreReady: true,
                captureMode: .stopped
            ),
            .paused
        )
        XCTAssertEqual(
            CaptureGlassState.resolve(
                captureIsRunning: true,
                permissionsAreReady: true,
                captureMode: .advancedGlobal
            ),
            .active
        )
        XCTAssertEqual(
            CaptureGlassState.resolve(
                captureIsRunning: true,
                permissionsAreReady: true,
                captureMode: .systemGestureFallback
            ),
            .limited
        )
    }

    @MainActor
    func testDiagnosticIconIsExcludedFromTheRenderedAccessibilityTree() throws {
        let application = NSApplication.shared
        let enhancedAccessibilityWasEnabled =
            (application.value(forKey: "accessibilityEnhancedUserInterface") as? Bool) ?? false
        application.setValue(true, forKey: "accessibilityEnhancedUserInterface")
        defer {
            application.setValue(
                enhancedAccessibilityWasEnabled,
                forKey: "accessibilityEnhancedUserInterface"
            )
        }

        let marker = "Resumo acessível"
        let host = NSHostingView(
            rootView: HStack {
                DiagnosticStatusIcon(outcome: .ignored)
                Text(marker)
            }
            .frame(width: 300, height: 100)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = host
        window.orderFrontRegardless()
        Self.retainedAccessibilityWindows.append(window)

        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        let elements = accessibilityElements(in: host)
        window.orderOut(nil)
        XCTAssertTrue(
            elements.contains { $0.value == marker },
            "A árvore AX precisa estar materializada para validar o ícone decorativo."
        )
        XCTAssertFalse(
            elements.contains { $0.role == NSAccessibility.Role.image.rawValue },
            "O ícone de diagnóstico é decorativo e não deve ser anunciado como imagem."
        )
    }

    @MainActor
    private func accessibilityElements(in root: NSView) -> [AccessibilityElementSnapshot] {
        let rootObject = root as NSObject
        return accessibilityChildren(of: rootObject).flatMap(accessibilityTree)
    }

    @MainActor
    private func accessibilityTree(from object: NSObject) -> [AccessibilityElementSnapshot] {
        let snapshot = AccessibilityElementSnapshot(
            role: accessibilityAttribute(named: "accessibilityRole", in: object) as? String,
            value: accessibilityAttribute(named: "accessibilityValue", in: object) as? String
        )
        return [snapshot] + accessibilityChildren(of: object).flatMap(accessibilityTree)
    }

    @MainActor
    private func accessibilityChildren(of object: NSObject) -> [NSObject] {
        (accessibilityAttribute(named: "accessibilityChildren", in: object) as? [Any])?
            .compactMap { $0 as? NSObject } ?? []
    }

    @MainActor
    private func accessibilityAttribute(named name: String, in object: NSObject) -> Any? {
        let selector = NSSelectorFromString(name)
        guard object.responds(to: selector) else { return nil }
        return object.perform(selector)?.takeUnretainedValue()
    }
}

private struct AccessibilityElementSnapshot {
    let role: String?
    let value: String?
}
