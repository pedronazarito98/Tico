import Foundation

enum TriggerDefinition: Hashable, Sendable {
    case keyboard(keyCode: UInt16, modifiers: Set<InputModifier>)
    case mouseButton(button: Int, modifiers: Set<InputModifier>)
    case trackpad(spec: TrackpadTriggerSpec)
    case customTrackpad(template: CustomGestureTemplate)
    case sequence(TriggerSequence)

    static func trackpad(
        gesture: TrackpadGesture,
        fingerCount: Int = 3,
        region: TrackpadRegion = .any
    ) -> Self {
        .trackpad(spec: TrackpadTriggerSpec(
            gesture: gesture,
            fingerCount: fingerCount,
            region: region
        ))
    }
}

extension TriggerDefinition: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case keyCode
        case modifiers
        case button
        case gesture
        case fingerCount
        case region
        case spec
        case template
        case sequence
    }

    private enum Kind: String, Codable {
        case keyboard
        case mouseButton
        case trackpad
        case customTrackpad
        case sequence
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .type)

        switch kind {
        case .keyboard:
            self = .keyboard(
                keyCode: try container.decode(UInt16.self, forKey: .keyCode),
                modifiers: try container.decodeIfPresent(Set<InputModifier>.self, forKey: .modifiers) ?? []
            )
        case .mouseButton:
            self = .mouseButton(
                button: try container.decode(Int.self, forKey: .button),
                modifiers: try container.decodeIfPresent(Set<InputModifier>.self, forKey: .modifiers) ?? []
            )
        case .trackpad:
            if let spec = try container.decodeIfPresent(TrackpadTriggerSpec.self, forKey: .spec) {
                self = .trackpad(spec: spec)
            } else {
                let gesture = try container.decode(TrackpadGesture.self, forKey: .gesture)
                self = .trackpad(
                    gesture: gesture,
                    fingerCount: try container.decodeIfPresent(Int.self, forKey: .fingerCount)
                        ?? gesture.defaultFingerCount,
                    region: try container.decodeIfPresent(TrackpadRegion.self, forKey: .region) ?? .any
                )
            }
        case .customTrackpad:
            self = .customTrackpad(
                template: try container.decode(CustomGestureTemplate.self, forKey: .template)
            )
        case .sequence:
            self = .sequence(try container.decode(TriggerSequence.self, forKey: .sequence))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .keyboard(keyCode, modifiers):
            try container.encode(Kind.keyboard, forKey: .type)
            try container.encode(keyCode, forKey: .keyCode)
            try container.encode(modifiers, forKey: .modifiers)
        case let .mouseButton(button, modifiers):
            try container.encode(Kind.mouseButton, forKey: .type)
            try container.encode(button, forKey: .button)
            try container.encode(modifiers, forKey: .modifiers)
        case let .trackpad(spec):
            try container.encode(Kind.trackpad, forKey: .type)
            try container.encode(spec, forKey: .spec)
        case let .customTrackpad(template):
            try container.encode(Kind.customTrackpad, forKey: .type)
            try container.encode(template, forKey: .template)
        case let .sequence(sequence):
            try container.encode(Kind.sequence, forKey: .type)
            try container.encode(sequence, forKey: .sequence)
        }
    }
}
