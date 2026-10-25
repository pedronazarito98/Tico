import Foundation

struct RuleTextMatcher: Codable, Hashable, Sendable {
    enum Mode: String, Codable, CaseIterable, Hashable, Sendable {
        case contains
        case beginsWith
        case exact
    }

    var value: String
    var mode: Mode
    var isCaseSensitive: Bool

    init(value: String, mode: Mode = .contains, isCaseSensitive: Bool = false) {
        self.value = value
        self.mode = mode
        self.isCaseSensitive = isCaseSensitive
    }

    func matches(_ candidate: String?) -> Bool {
        guard let candidate, !value.isEmpty else { return false }
        let lhs = isCaseSensitive ? candidate : candidate.localizedLowercase
        let rhs = isCaseSensitive ? value : value.localizedLowercase
        switch mode {
        case .contains:
            return lhs.contains(rhs)
        case .beginsWith:
            return lhs.hasPrefix(rhs)
        case .exact:
            return lhs == rhs
        }
    }
}

enum RuleCondition: Codable, Hashable, Sendable {
    case application(bundleIdentifiers: Set<String>)
    case windowTitle(RuleTextMatcher)
    case display(identifier: String)
    case modifiers(Set<InputModifier>)
    case timeRange(startMinute: Int, endMinute: Int, weekdays: Set<Int>)

    func matches(_ context: ContextSnapshot, calendar: Calendar = .current) -> Bool {
        switch self {
        case let .application(bundleIdentifiers):
            guard let identifier = context.frontmostApplicationBundleIdentifier else {
                return false
            }
            return bundleIdentifiers.contains(identifier)
        case let .windowTitle(matcher):
            return matcher.matches(context.frontmostWindowTitle)
        case let .display(identifier):
            return context.displayIdentifier == identifier
        case let .modifiers(modifiers):
            return context.modifiers == modifiers
        case let .timeRange(startMinute, endMinute, weekdays):
            let weekday = calendar.component(.weekday, from: context.capturedAt)
            guard weekdays.isEmpty || weekdays.contains(weekday) else { return false }
            let minute = calendar.component(.hour, from: context.capturedAt) * 60
                + calendar.component(.minute, from: context.capturedAt)
            let start = min(max(startMinute, 0), 1_439)
            let end = min(max(endMinute, 0), 1_439)
            if start <= end {
                return (start...end).contains(minute)
            }
            return minute >= start || minute <= end
        }
    }
}
