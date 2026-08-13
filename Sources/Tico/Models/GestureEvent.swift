import Foundation

enum GesturePhase: String, Codable, Sendable {
    case began
    case changed
    case ended
    case cancelled
}

struct GestureEvent: Codable, Hashable, Sendable {
    let id: UUID
    let sessionID: UUID
    let kind: TrackpadGesture
    let phase: GesturePhase
    let fingerCount: Int
    let deviceID: String?
    let startRegion: TrackpadRegion
    let endRegion: TrackpadRegion
    let startPosition: TrackpadPoint?
    let endPosition: TrackpadPoint?
    let path: [TrackpadPoint]
    let progress: Double?
    let velocity: Double?
    let pressure: Double?
    let confidence: Double
    let advanced: AdvancedGestureMetadata?
    let occurredAt: Date

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        kind: TrackpadGesture,
        phase: GesturePhase,
        fingerCount: Int,
        deviceID: String? = nil,
        startRegion: TrackpadRegion,
        endRegion: TrackpadRegion,
        startPosition: TrackpadPoint? = nil,
        endPosition: TrackpadPoint? = nil,
        path: [TrackpadPoint] = [],
        progress: Double? = nil,
        velocity: Double? = nil,
        pressure: Double? = nil,
        confidence: Double,
        advanced: AdvancedGestureMetadata? = nil,
        occurredAt: Date
    ) {
        self.id = id
        self.sessionID = sessionID
        self.kind = kind
        self.phase = phase
        self.fingerCount = fingerCount
        self.deviceID = deviceID
        self.startRegion = startRegion
        self.endRegion = endRegion
        self.startPosition = startPosition
        self.endPosition = endPosition
        self.path = path
        self.progress = progress
        self.velocity = velocity
        self.pressure = pressure
        self.confidence = min(max(confidence, 0), 1)
        self.advanced = advanced
        self.occurredAt = occurredAt
    }
}

enum DeviceScope: Codable, Hashable, Sendable {
    case any
    case defaultDevice
    case device(id: String)
}

struct TrackpadTriggerSpec: Codable, Hashable, Sendable {
    var gesture: TrackpadGesture
    var fingerCount: ClosedRange<Int>
    var tapCount: Int
    var maximumTapInterval: TimeInterval?
    var startRegion: TrackpadRegion
    var endRegion: TrackpadRegion?
    var minimumVelocity: Double?
    var maximumVelocity: Double?
    var pressureThreshold: Double?
    var pressureRange: ClosedRange<Double>?
    var sensitivity: Double
    var deviceScope: DeviceScope
    var allowsDeviceFallback: Bool
    var anchorFingerCount: Int?
    var entryOrder: [Int]?
    var exitOrder: [Int]?
    var requiredModifiers: Set<InputModifier>?

    init(
        gesture: TrackpadGesture,
        fingerCount: ClosedRange<Int>,
        tapCount: Int = 1,
        maximumTapInterval: TimeInterval? = nil,
        startRegion: TrackpadRegion = .any,
        endRegion: TrackpadRegion? = nil,
        minimumVelocity: Double? = nil,
        maximumVelocity: Double? = nil,
        pressureThreshold: Double? = nil,
        pressureRange: ClosedRange<Double>? = nil,
        sensitivity: Double = 1,
        deviceScope: DeviceScope = .any,
        allowsDeviceFallback: Bool = true,
        anchorFingerCount: Int? = nil,
        entryOrder: [Int]? = nil,
        exitOrder: [Int]? = nil,
        requiredModifiers: Set<InputModifier>? = nil
    ) {
        self.gesture = gesture
        self.fingerCount = fingerCount
        self.tapCount = max(1, tapCount)
        self.maximumTapInterval = maximumTapInterval
        self.startRegion = startRegion
        self.endRegion = endRegion
        self.minimumVelocity = minimumVelocity
        self.maximumVelocity = maximumVelocity
        self.pressureThreshold = pressureThreshold
        if let pressureRange {
            let lower = min(max(pressureRange.lowerBound, 0), 1)
            let upper = min(max(pressureRange.upperBound, 0), 1)
            self.pressureRange = lower...max(lower, upper)
        } else {
            self.pressureRange = nil
        }
        self.sensitivity = min(max(sensitivity, 0.25), 2)
        self.deviceScope = deviceScope
        self.allowsDeviceFallback = allowsDeviceFallback
        self.anchorFingerCount = anchorFingerCount
        self.entryOrder = entryOrder
        self.exitOrder = exitOrder
        self.requiredModifiers = requiredModifiers
    }

    init(
        gesture: TrackpadGesture,
        fingerCount: Int,
        region: TrackpadRegion = .any
    ) {
        self.init(
            gesture: gesture,
            fingerCount: fingerCount...fingerCount,
            startRegion: region
        )
    }

    var effectiveMaximumTapInterval: TimeInterval {
        min(max(maximumTapInterval ?? 0.42, 0.15), 1)
    }

    private enum CodingKeys: String, CodingKey {
        case gesture
        case fingerCount
        case tapCount
        case maximumTapInterval
        case startRegion
        case endRegion
        case minimumVelocity
        case maximumVelocity
        case pressureThreshold
        case pressureRange
        case sensitivity
        case deviceScope
        case allowsDeviceFallback
        case anchorFingerCount
        case entryOrder
        case exitOrder
        case requiredModifiers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let gesture = try container.decode(TrackpadGesture.self, forKey: .gesture)
        let decodedFingerCount = try container.decodeIfPresent(
            SafeRangeBounds<Int>.self,
            forKey: .fingerCount
        )
        let fingerCount: ClosedRange<Int>
        if let decodedFingerCount {
            guard decodedFingerCount.lowerBound <= decodedFingerCount.upperBound else {
                throw DecodingError.dataCorruptedError(
                    forKey: .fingerCount,
                    in: container,
                    debugDescription: "A faixa de dedos está invertida."
                )
            }
            fingerCount = decodedFingerCount.lowerBound...decodedFingerCount.upperBound
        } else {
            fingerCount = gesture.defaultFingerCount...gesture.defaultFingerCount
        }
        let decodedPressureRange = try container.decodeIfPresent(
            SafeRangeBounds<Double>.self,
            forKey: .pressureRange
        )
        let pressureRange: ClosedRange<Double>?
        if let decodedPressureRange {
            guard decodedPressureRange.lowerBound.isFinite,
                  decodedPressureRange.upperBound.isFinite,
                  decodedPressureRange.lowerBound <= decodedPressureRange.upperBound else {
                throw DecodingError.dataCorruptedError(
                    forKey: .pressureRange,
                    in: container,
                    debugDescription: "A faixa de pressão é inválida."
                )
            }
            pressureRange = decodedPressureRange.lowerBound...decodedPressureRange.upperBound
        } else {
            pressureRange = nil
        }
        self.init(
            gesture: gesture,
            fingerCount: fingerCount,
            tapCount: try container.decodeIfPresent(Int.self, forKey: .tapCount) ?? 1,
            maximumTapInterval: try container.decodeIfPresent(
                TimeInterval.self,
                forKey: .maximumTapInterval
            ),
            startRegion: try container.decodeIfPresent(
                TrackpadRegion.self,
                forKey: .startRegion
            ) ?? .any,
            endRegion: try container.decodeIfPresent(
                TrackpadRegion.self,
                forKey: .endRegion
            ),
            minimumVelocity: try container.decodeIfPresent(
                Double.self,
                forKey: .minimumVelocity
            ),
            maximumVelocity: try container.decodeIfPresent(
                Double.self,
                forKey: .maximumVelocity
            ),
            pressureThreshold: try container.decodeIfPresent(
                Double.self,
                forKey: .pressureThreshold
            ),
            pressureRange: pressureRange,
            sensitivity: try container.decodeIfPresent(
                Double.self,
                forKey: .sensitivity
            ) ?? 1,
            deviceScope: try container.decodeIfPresent(
                DeviceScope.self,
                forKey: .deviceScope
            ) ?? .any,
            allowsDeviceFallback: try container.decodeIfPresent(
                Bool.self,
                forKey: .allowsDeviceFallback
            ) ?? true,
            anchorFingerCount: try container.decodeIfPresent(
                Int.self,
                forKey: .anchorFingerCount
            ),
            entryOrder: try container.decodeIfPresent([Int].self, forKey: .entryOrder),
            exitOrder: try container.decodeIfPresent([Int].self, forKey: .exitOrder),
            requiredModifiers: try container.decodeIfPresent(
                Set<InputModifier>.self,
                forKey: .requiredModifiers
            )
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(gesture, forKey: .gesture)
        try container.encode(fingerCount, forKey: .fingerCount)
        try container.encode(tapCount, forKey: .tapCount)
        try container.encodeIfPresent(maximumTapInterval, forKey: .maximumTapInterval)
        try container.encode(startRegion, forKey: .startRegion)
        try container.encodeIfPresent(endRegion, forKey: .endRegion)
        try container.encodeIfPresent(minimumVelocity, forKey: .minimumVelocity)
        try container.encodeIfPresent(maximumVelocity, forKey: .maximumVelocity)
        try container.encodeIfPresent(pressureThreshold, forKey: .pressureThreshold)
        try container.encodeIfPresent(pressureRange, forKey: .pressureRange)
        try container.encode(sensitivity, forKey: .sensitivity)
        try container.encode(deviceScope, forKey: .deviceScope)
        try container.encode(allowsDeviceFallback, forKey: .allowsDeviceFallback)
        try container.encodeIfPresent(anchorFingerCount, forKey: .anchorFingerCount)
        try container.encodeIfPresent(entryOrder, forKey: .entryOrder)
        try container.encodeIfPresent(exitOrder, forKey: .exitOrder)
        try container.encodeIfPresent(requiredModifiers, forKey: .requiredModifiers)
    }
}

private struct SafeRangeBounds<Value: Codable & Comparable>: Codable {
    let lowerBound: Value
    let upperBound: Value

    private enum CodingKeys: String, CodingKey {
        case lowerBound
        case upperBound
    }

    init(from decoder: Decoder) throws {
        if var values = try? decoder.unkeyedContainer() {
            lowerBound = try values.decode(Value.self)
            upperBound = try values.decode(Value.self)
        } else {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            lowerBound = try container.decode(Value.self, forKey: .lowerBound)
            upperBound = try container.decode(Value.self, forKey: .upperBound)
        }
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.unkeyedContainer()
        try values.encode(lowerBound)
        try values.encode(upperBound)
    }
}
