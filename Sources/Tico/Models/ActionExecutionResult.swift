import Foundation

struct ActionExecutionResult: Codable, Hashable, Sendable {
    var success: Bool
    var message: String
    var executedAt: Date

    init(success: Bool, message: String, executedAt: Date = Date()) {
        self.success = success
        self.message = message
        self.executedAt = executedAt
    }

    static func succeeded(_ message: String, executedAt: Date = Date()) -> Self {
        Self(success: true, message: message, executedAt: executedAt)
    }

    static func failed(_ message: String, executedAt: Date = Date()) -> Self {
        Self(success: false, message: message, executedAt: executedAt)
    }
}
