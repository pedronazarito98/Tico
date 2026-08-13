import Foundation

enum ShortcutAction: Hashable, Sendable {
    case openApplication(bundleIdentifier: String)
    case openURL(url: URL)
    case notification(title: String, body: String)
    case shellScript(command: String)
    case appleScript(source: String)
    case macOSShortcut(name: String, input: String?)
    case keyboardShortcut(keyCode: UInt16, modifiers: Set<InputModifier>)
    case setClipboard(text: String)
    case application(target: ApplicationTarget, operation: ApplicationOperation)
    case window(target: ApplicationTarget, operation: WindowOperation)
    case continuousWindow(
        target: ApplicationTarget,
        operation: ContinuousWindowOperation,
        curve: ContinuousResponseCurve
    )
}

extension ShortcutAction: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case bundleIdentifier
        case url
        case title
        case body
        case command
        case source
        case name
        case input
        case keyCode
        case modifiers
        case text
        case curve
        case target
        case operation
    }

    private enum Kind: String, Codable {
        case openApplication
        case openURL
        case notification
        case shellScript
        case appleScript
        case macOSShortcut
        case keyboardShortcut
        case setClipboard
        case application
        case window
        case continuousWindow
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .type)

        switch kind {
        case .openApplication:
            self = .openApplication(
                bundleIdentifier: try container.decode(String.self, forKey: .bundleIdentifier)
            )
        case .openURL:
            self = .openURL(url: try container.decode(URL.self, forKey: .url))
        case .notification:
            self = .notification(
                title: try container.decode(String.self, forKey: .title),
                body: try container.decode(String.self, forKey: .body)
            )
        case .shellScript:
            self = .shellScript(command: try container.decode(String.self, forKey: .command))
        case .appleScript:
            self = .appleScript(source: try container.decode(String.self, forKey: .source))
        case .macOSShortcut:
            self = .macOSShortcut(
                name: try container.decode(String.self, forKey: .name),
                input: try container.decodeIfPresent(String.self, forKey: .input)
            )
        case .keyboardShortcut:
            self = .keyboardShortcut(
                keyCode: try container.decode(UInt16.self, forKey: .keyCode),
                modifiers: try container.decodeIfPresent(Set<InputModifier>.self, forKey: .modifiers) ?? []
            )
        case .setClipboard:
            self = .setClipboard(text: try container.decode(String.self, forKey: .text))
        case .application:
            self = .application(
                target: try container.decode(ApplicationTarget.self, forKey: .target),
                operation: try container.decode(ApplicationOperation.self, forKey: .operation)
            )
        case .window:
            self = .window(
                target: try container.decode(ApplicationTarget.self, forKey: .target),
                operation: try container.decode(WindowOperation.self, forKey: .operation)
            )
        case .continuousWindow:
            self = .continuousWindow(
                target: try container.decode(ApplicationTarget.self, forKey: .target),
                operation: try container.decode(ContinuousWindowOperation.self, forKey: .operation),
                curve: try container.decodeIfPresent(
                    ContinuousResponseCurve.self,
                    forKey: .curve
                ) ?? .linear
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .openApplication(bundleIdentifier):
            try container.encode(Kind.openApplication, forKey: .type)
            try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
        case let .openURL(url):
            try container.encode(Kind.openURL, forKey: .type)
            try container.encode(url, forKey: .url)
        case let .notification(title, body):
            try container.encode(Kind.notification, forKey: .type)
            try container.encode(title, forKey: .title)
            try container.encode(body, forKey: .body)
        case let .shellScript(command):
            try container.encode(Kind.shellScript, forKey: .type)
            try container.encode(command, forKey: .command)
        case let .appleScript(source):
            try container.encode(Kind.appleScript, forKey: .type)
            try container.encode(source, forKey: .source)
        case let .macOSShortcut(name, input):
            try container.encode(Kind.macOSShortcut, forKey: .type)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(input, forKey: .input)
        case let .keyboardShortcut(keyCode, modifiers):
            try container.encode(Kind.keyboardShortcut, forKey: .type)
            try container.encode(keyCode, forKey: .keyCode)
            try container.encode(modifiers, forKey: .modifiers)
        case let .setClipboard(text):
            try container.encode(Kind.setClipboard, forKey: .type)
            try container.encode(text, forKey: .text)
        case let .application(target, operation):
            try container.encode(Kind.application, forKey: .type)
            try container.encode(target, forKey: .target)
            try container.encode(operation, forKey: .operation)
        case let .window(target, operation):
            try container.encode(Kind.window, forKey: .type)
            try container.encode(target, forKey: .target)
            try container.encode(operation, forKey: .operation)
        case let .continuousWindow(target, operation, curve):
            try container.encode(Kind.continuousWindow, forKey: .type)
            try container.encode(target, forKey: .target)
            try container.encode(operation, forKey: .operation)
            try container.encode(curve, forKey: .curve)
        }
    }
}
