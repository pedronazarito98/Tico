import Foundation

enum ContinuousWindowOperation: String, Codable, CaseIterable, Hashable, Sendable {
    case moveHorizontal
    case moveVertical
    case resizeWidth
    case resizeHeight
    case resizeProportionally
}

enum ContinuousResponseCurve: String, Codable, CaseIterable, Hashable, Sendable {
    case precise
    case linear
    case accelerated

    func map(_ value: Double) -> Double {
        let clamped = min(max(value, -1), 1)
        switch self {
        case .precise:
            return clamped * 0.45
        case .linear:
            return clamped
        case .accelerated:
            return clamped.sign == .minus
                ? -pow(abs(clamped), 1.45)
                : pow(clamped, 1.45)
        }
    }
}

