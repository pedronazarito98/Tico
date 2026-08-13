import AppKit
import Foundation

@MainActor
protocol ContextSnapshotProviding {
    func snapshot(modifiers: Set<InputModifier>, at date: Date) -> ContextSnapshot
}

@MainActor
final class ContextSnapshotService: ContextSnapshotProviding {
    private let workspace: NSWorkspace
    private let windowContextReader: any WindowContextReading

    init(
        workspace: NSWorkspace = .shared,
        windowContextReader: any WindowContextReading = WindowContextReader()
    ) {
        self.workspace = workspace
        self.windowContextReader = windowContextReader
    }

    func snapshot(modifiers: Set<InputModifier>, at date: Date = Date()) -> ContextSnapshot {
        let application = workspace.frontmostApplication
        let windowContext = application.map {
            windowContextReader.focusedWindowContext(
                processIdentifier: $0.processIdentifier
            )
        } ?? WindowContext()
        return ContextSnapshot(
            frontmostApplicationBundleIdentifier: application?.bundleIdentifier,
            frontmostApplicationName: application?.localizedName,
            frontmostWindowTitle: windowContext.title,
            displayIdentifier: windowContext.displayIdentifier,
            modifiers: modifiers,
            capturedAt: date
        )
    }
}
