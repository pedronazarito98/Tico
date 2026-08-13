import Foundation

enum RuleScope: Hashable, Sendable {
    case global
    case applications(bundleIdentifiers: Set<String>)

    var bundleIdentifiers: Set<String> {
        switch self {
        case .global:
            []
        case let .applications(bundleIdentifiers):
            bundleIdentifiers
        }
    }

    func matches(_ context: ContextSnapshot) -> Bool {
        switch self {
        case .global:
            return true
        case let .applications(bundleIdentifiers):
            guard let identifier = context.frontmostApplicationBundleIdentifier else {
                return false
            }
            return bundleIdentifiers.contains(identifier)
        }
    }

    func overlaps(_ other: RuleScope) -> Bool {
        switch (self, other) {
        case (.global, _), (_, .global):
            true
        case let (.applications(lhs), .applications(rhs)):
            !lhs.isDisjoint(with: rhs)
        }
    }

    var specificity: Int {
        switch self {
        case .global: 0
        case .applications: 1
        }
    }
}

extension RuleScope: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case bundleIdentifiers
    }

    private enum Kind: String, Codable {
        case global
        case applications
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .global:
            self = .global
        case .applications:
            self = .applications(
                bundleIdentifiers: try container.decode(Set<String>.self, forKey: .bundleIdentifiers)
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .global:
            try container.encode(Kind.global, forKey: .type)
        case let .applications(bundleIdentifiers):
            try container.encode(Kind.applications, forKey: .type)
            try container.encode(bundleIdentifiers, forKey: .bundleIdentifiers)
        }
    }
}

struct ContextSnapshot: Equatable, Sendable {
    var frontmostApplicationBundleIdentifier: String?
    var frontmostApplicationName: String?
    var frontmostWindowTitle: String?
    var displayIdentifier: String?
    var modifiers: Set<InputModifier>
    var capturedAt: Date

    init(
        frontmostApplicationBundleIdentifier: String? = nil,
        frontmostApplicationName: String? = nil,
        frontmostWindowTitle: String? = nil,
        displayIdentifier: String? = nil,
        modifiers: Set<InputModifier> = [],
        capturedAt: Date = Date()
    ) {
        self.frontmostApplicationBundleIdentifier = frontmostApplicationBundleIdentifier
        self.frontmostApplicationName = frontmostApplicationName
        self.frontmostWindowTitle = frontmostWindowTitle
        self.displayIdentifier = displayIdentifier
        self.modifiers = modifiers
        self.capturedAt = capturedAt
    }
}

struct ApplicationChoice: Identifiable, Hashable, Sendable {
    var bundleIdentifier: String
    var name: String
    var applicationURL: URL?
    var isRunning: Bool

    var id: String { bundleIdentifier }
}

enum ApplicationTarget: Hashable, Sendable {
    case frontmost
    case bundleIdentifier(String)
}

extension ApplicationTarget: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case bundleIdentifier
    }

    private enum Kind: String, Codable {
        case frontmost
        case bundleIdentifier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .frontmost:
            self = .frontmost
        case .bundleIdentifier:
            self = .bundleIdentifier(
                try container.decode(String.self, forKey: .bundleIdentifier)
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .frontmost:
            try container.encode(Kind.frontmost, forKey: .type)
        case let .bundleIdentifier(identifier):
            try container.encode(Kind.bundleIdentifier, forKey: .type)
            try container.encode(identifier, forKey: .bundleIdentifier)
        }
    }
}

enum ApplicationOperation: String, Codable, CaseIterable, Hashable, Sendable {
    case open
    case activate
    case hide
    case quit
}

enum WindowOperation: String, Codable, CaseIterable, Hashable, Sendable {
    case close
    case minimize
    case maximize
    case restore
    case center
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case leftThird
    case centerThird
    case rightThird
    case topLeftQuarter
    case topRightQuarter
    case bottomLeftQuarter
    case bottomRightQuarter
    case nextDisplay
    case tileAll
}
