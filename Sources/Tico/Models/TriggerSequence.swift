import Foundation

enum SequenceAmbiguityPolicy: String, Codable, CaseIterable, Hashable, Sendable {
    case waitForTimeout
    case acceptImmediately
    case cancelOnMismatch
}

struct TriggerSequence: Codable, Hashable, Sendable {
    var steps: [TriggerStep]
    var maximumInterval: TimeInterval
    var ambiguityPolicy: SequenceAmbiguityPolicy

    init(
        steps: [TriggerStep],
        maximumInterval: TimeInterval = 0.8,
        ambiguityPolicy: SequenceAmbiguityPolicy = .waitForTimeout
    ) {
        self.steps = Array(steps.prefix(5))
        self.maximumInterval = min(max(maximumInterval, 0.15), 5)
        self.ambiguityPolicy = ambiguityPolicy
    }

    var isValid: Bool {
        (2...5).contains(steps.count)
    }

    func isPrefix(of other: TriggerSequence) -> Bool {
        steps.count < other.steps.count
            && Array(other.steps.prefix(steps.count)) == steps
    }
}

enum TriggerStep: Hashable, Sendable {
    case keyboard(keyCode: UInt16, modifiers: Set<InputModifier>)
    case mouseButton(button: Int, modifiers: Set<InputModifier>)
    case trackpad(spec: TrackpadTriggerSpec)
    case customTrackpad(template: CustomGestureTemplate)

    init?(_ trigger: TriggerDefinition) {
        switch trigger {
        case let .keyboard(keyCode, modifiers):
            self = .keyboard(keyCode: keyCode, modifiers: modifiers)
        case let .mouseButton(button, modifiers):
            self = .mouseButton(button: button, modifiers: modifiers)
        case let .trackpad(spec):
            self = .trackpad(spec: spec)
        case let .customTrackpad(template):
            self = .customTrackpad(template: template)
        case .sequence:
            return nil
        }
    }

    var triggerDefinition: TriggerDefinition {
        switch self {
        case let .keyboard(keyCode, modifiers):
            .keyboard(keyCode: keyCode, modifiers: modifiers)
        case let .mouseButton(button, modifiers):
            .mouseButton(button: button, modifiers: modifiers)
        case let .trackpad(spec):
            .trackpad(spec: spec)
        case let .customTrackpad(template):
            .customTrackpad(template: template)
        }
    }
}

extension TriggerStep: Codable {
    init(from decoder: Decoder) throws {
        guard let step = TriggerStep(try TriggerDefinition(from: decoder)) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Uma sequência não pode conter outra sequência.")
            )
        }
        self = step
    }

    func encode(to encoder: Encoder) throws {
        try triggerDefinition.encode(to: encoder)
    }
}

struct AdvancedGestureMetadata: Codable, Hashable, Sendable {
    var tapCount: Int
    var tapInterval: TimeInterval?
    var anchorFingerCount: Int
    var addedFingerCount: Int
    var removedFingerCount: Int
    var entryOrder: [Int]
    var exitOrder: [Int]

    init(
        tapCount: Int = 1,
        tapInterval: TimeInterval? = nil,
        anchorFingerCount: Int = 0,
        addedFingerCount: Int = 0,
        removedFingerCount: Int = 0,
        entryOrder: [Int] = [],
        exitOrder: [Int] = []
    ) {
        self.tapCount = max(1, tapCount)
        self.tapInterval = tapInterval
        self.anchorFingerCount = max(0, anchorFingerCount)
        self.addedFingerCount = max(0, addedFingerCount)
        self.removedFingerCount = max(0, removedFingerCount)
        self.entryOrder = entryOrder
        self.exitOrder = exitOrder
    }
}
