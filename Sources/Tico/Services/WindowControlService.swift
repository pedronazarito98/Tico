import AppKit
import ApplicationServices
import Foundation

protocol WindowControlling {
    func perform(
        _ operation: WindowOperation,
        target: ApplicationTarget
    ) async throws
}

enum WindowControlError: LocalizedError, Equatable {
    case accessibilityRequired
    case applicationNotRunning
    case windowNotFound
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .accessibilityRequired:
            "Conceda Acessibilidade ao \(TicoBrand.displayName) para controlar janelas."
        case .applicationNotRunning:
            "O aplicativo escolhido não está em execução."
        case .windowNotFound:
            "Nenhuma janela controlável foi encontrada para o aplicativo."
        case let .operationFailed(message):
            "Não foi possível controlar a janela: \(message)"
        }
    }
}

final class WindowControlService: WindowControlling {
    private let workspace: NSWorkspace
    private let accessibilityCheck: () -> Bool
    private var savedFrames: [pid_t: CGRect] = [:]

    init(
        workspace: NSWorkspace = .shared,
        accessibilityCheck: @escaping () -> Bool = AXIsProcessTrusted
    ) {
        self.workspace = workspace
        self.accessibilityCheck = accessibilityCheck
    }

    func perform(
        _ operation: WindowOperation,
        target: ApplicationTarget
    ) async throws {
        guard accessibilityCheck() else {
            throw WindowControlError.accessibilityRequired
        }
        guard let application = runningApplication(for: target) else {
            throw WindowControlError.applicationNotRunning
        }
        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
        let windows = try copyWindows(from: applicationElement)
        guard !windows.isEmpty else {
            throw WindowControlError.windowNotFound
        }

        if operation == .tileAll {
            try tile(windows)
            return
        }

        let window = (try? copyElement(
            attribute: kAXFocusedWindowAttribute as CFString,
            from: applicationElement
        )) ?? windows[0]
        let visibleFrame = visibleFrame(for: window)
        if operation != .restore,
           operation != .close,
           operation != .minimize,
           savedFrames[application.processIdentifier] == nil,
           let currentFrame = try? copyFrame(from: window) {
            savedFrames[application.processIdentifier] = currentFrame
        }
        switch operation {
        case .close:
            let closeButton = try copyElement(
                attribute: kAXCloseButtonAttribute as CFString,
                from: window
            )
            try requireSuccess(AXUIElementPerformAction(closeButton, kAXPressAction as CFString))
        case .minimize:
            try requireSuccess(
                AXUIElementSetAttributeValue(
                    window,
                    kAXMinimizedAttribute as CFString,
                    kCFBooleanTrue
                )
            )
        case .maximize:
            try set(frame: targetFrame(for: .maximize, visible: visibleFrame), on: window)
        case .restore:
            guard let savedFrame = savedFrames.removeValue(
                forKey: application.processIdentifier
            ) else {
                throw WindowControlError.operationFailed("não há frame anterior salvo")
            }
            try set(frame: savedFrame, on: window)
        case .center:
            let currentSize = (try? copySize(from: window)) ?? CGSize(width: 900, height: 650)
            let visible = visibleFrame
            let frame = CGRect(
                x: visible.midX - currentSize.width / 2,
                y: visible.midY - currentSize.height / 2,
                width: min(currentSize.width, visible.width),
                height: min(currentSize.height, visible.height)
            )
            try set(frame: frame, on: window)
        case .leftHalf, .rightHalf, .topHalf, .bottomHalf,
             .leftThird, .centerThird, .rightThird,
             .topLeftQuarter, .topRightQuarter,
             .bottomLeftQuarter, .bottomRightQuarter:
            try set(frame: targetFrame(for: operation, visible: visibleFrame), on: window)
        case .nextDisplay:
            try moveToNextDisplay(window, currentVisibleFrame: visibleFrame)
        case .tileAll:
            break
        }
    }

    private func runningApplication(for target: ApplicationTarget) -> NSRunningApplication? {
        switch target {
        case .frontmost:
            workspace.frontmostApplication
        case let .bundleIdentifier(identifier):
            NSRunningApplication.runningApplications(withBundleIdentifier: identifier).first
        }
    }

    private func copyWindows(from application: AXUIElement) throws -> [AXUIElement] {
        var value: CFTypeRef?
        try requireSuccess(
            AXUIElementCopyAttributeValue(
                application,
                kAXWindowsAttribute as CFString,
                &value
            )
        )
        return value as? [AXUIElement] ?? []
    }

    private func copyElement(
        attribute: CFString,
        from element: AXUIElement
    ) throws -> AXUIElement {
        var value: CFTypeRef?
        try requireSuccess(AXUIElementCopyAttributeValue(element, attribute, &value))
        guard let result = AccessibilityValueDecoder.element(value) else {
            throw WindowControlError.windowNotFound
        }
        return result
    }

    private func copySize(from window: AXUIElement) throws -> CGSize {
        var value: CFTypeRef?
        try requireSuccess(
            AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &value)
        )
        guard let size = AccessibilityValueDecoder.size(value) else {
            throw WindowControlError.operationFailed("tamanho indisponível")
        }
        return size
    }

    private func copyPosition(from window: AXUIElement) throws -> CGPoint {
        var value: CFTypeRef?
        try requireSuccess(
            AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &value)
        )
        guard let position = AccessibilityValueDecoder.point(value) else {
            throw WindowControlError.operationFailed("posição indisponível")
        }
        return position
    }

    private func copyFrame(from window: AXUIElement) throws -> CGRect {
        CGRect(origin: try copyPosition(from: window), size: try copySize(from: window))
    }

    private func set(frame: CGRect, on window: AXUIElement) throws {
        var position = frame.origin
        var size = frame.size
        guard let positionValue = AXValueCreate(.cgPoint, &position),
              let sizeValue = AXValueCreate(.cgSize, &size) else {
            throw WindowControlError.operationFailed("frame inválido")
        }
        try requireSuccess(
            AXUIElementSetAttributeValue(
                window,
                kAXPositionAttribute as CFString,
                positionValue
            )
        )
        try requireSuccess(
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        )
    }

    private func tile(_ windows: [AXUIElement]) throws {
        let visible = primaryVisibleFrame
        let columns = windows.count == 1 ? 1 : 2
        let rows = Int(ceil(Double(windows.count) / Double(columns)))
        let cellWidth = visible.width / Double(columns)
        let cellHeight = visible.height / Double(max(rows, 1))
        for (index, window) in windows.enumerated() {
            let column = index % columns
            let row = index / columns
            try set(
                frame: CGRect(
                    x: visible.minX + Double(column) * cellWidth,
                    y: visible.minY + Double(row) * cellHeight,
                    width: cellWidth,
                    height: cellHeight
                ),
                on: window
            )
        }
    }

    private func targetFrame(for operation: WindowOperation, visible: CGRect) -> CGRect {
        switch operation {
        case .leftHalf:
            return CGRect(x: visible.minX, y: visible.minY, width: visible.width / 2, height: visible.height)
        case .rightHalf:
            return CGRect(x: visible.midX, y: visible.minY, width: visible.width / 2, height: visible.height)
        case .topHalf:
            return CGRect(x: visible.minX, y: visible.minY, width: visible.width, height: visible.height / 2)
        case .bottomHalf:
            return CGRect(x: visible.minX, y: visible.midY, width: visible.width, height: visible.height / 2)
        case .maximize:
            return visible
        case .leftThird:
            return CGRect(x: visible.minX, y: visible.minY, width: visible.width / 3, height: visible.height)
        case .centerThird:
            return CGRect(x: visible.minX + visible.width / 3, y: visible.minY, width: visible.width / 3, height: visible.height)
        case .rightThird:
            return CGRect(x: visible.minX + visible.width * 2 / 3, y: visible.minY, width: visible.width / 3, height: visible.height)
        case .topLeftQuarter:
            return CGRect(x: visible.minX, y: visible.minY, width: visible.width / 2, height: visible.height / 2)
        case .topRightQuarter:
            return CGRect(x: visible.midX, y: visible.minY, width: visible.width / 2, height: visible.height / 2)
        case .bottomLeftQuarter:
            return CGRect(x: visible.minX, y: visible.midY, width: visible.width / 2, height: visible.height / 2)
        case .bottomRightQuarter:
            return CGRect(x: visible.midX, y: visible.midY, width: visible.width / 2, height: visible.height / 2)
        case .close, .minimize, .restore, .center, .nextDisplay, .tileAll:
            return visible
        }
    }

    private func moveToNextDisplay(
        _ window: AXUIElement,
        currentVisibleFrame: CGRect
    ) throws {
        let frames = NSScreen.screens.map(convertedVisibleFrame)
        guard frames.count > 1,
              let currentIndex = frames.firstIndex(where: {
                  abs($0.minX - currentVisibleFrame.minX) < 2
                      && abs($0.minY - currentVisibleFrame.minY) < 2
              }) else {
            throw WindowControlError.operationFailed("nenhum outro monitor disponível")
        }
        let next = frames[(currentIndex + 1) % frames.count]
        let current = try copyFrame(from: window)
        let xRatio = (current.minX - currentVisibleFrame.minX)
            / max(currentVisibleFrame.width, 1)
        let yRatio = (current.minY - currentVisibleFrame.minY)
            / max(currentVisibleFrame.height, 1)
        let frame = CGRect(
            x: next.minX + xRatio * next.width,
            y: next.minY + yRatio * next.height,
            width: min(current.width, next.width),
            height: min(current.height, next.height)
        )
        try set(frame: frame, on: window)
    }

    private func visibleFrame(for window: AXUIElement) -> CGRect {
        guard let frame = try? copyFrame(from: window) else {
            return primaryVisibleFrame
        }
        return NSScreen.screens
            .map(convertedVisibleFrame)
            .first(where: { $0.intersects(frame) })
            ?? primaryVisibleFrame
    }

    private func convertedVisibleFrame(_ screen: NSScreen) -> CGRect {
        let visible = screen.visibleFrame
        return CGRect(
            x: visible.minX,
            y: screen.frame.maxY - visible.maxY,
            width: visible.width,
            height: visible.height
        )
    }

    private var primaryVisibleFrame: CGRect {
        guard let screen = NSScreen.main else {
            return CGRect(x: 0, y: 0, width: 1440, height: 900)
        }
        return convertedVisibleFrame(screen)
    }

    private func requireSuccess(_ error: AXError) throws {
        guard error == .success else {
            throw WindowControlError.operationFailed("AXError \(error.rawValue)")
        }
    }
}
