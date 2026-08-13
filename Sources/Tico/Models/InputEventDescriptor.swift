import Foundation

enum InputModifier: String, Codable, CaseIterable, Hashable, Sendable {
    case command
    case option
    case control
    case shift
    case capsLock
    case function
}

enum InputEventKind: String, Codable, CaseIterable, Hashable, Sendable {
    case keyboard
    case mouseButton
    case trackpadGesture
}

enum TrackpadGesture: String, Codable, CaseIterable, Hashable, Sendable {
    case tap
    case hold
    case tipTapLeft
    case tipTapRight
    case addFinger
    case removeFinger
    case fingerChord
    case swipeLeft
    case swipeRight
    case swipeUp
    case swipeDown
    case pinchIn
    case pinchOut
    case rotateClockwise
    case rotateCounterclockwise

    var defaultFingerCount: Int {
        switch self {
        case .pinchIn, .pinchOut, .rotateClockwise, .rotateCounterclockwise: 2
        case .tap, .hold, .tipTapLeft, .tipTapRight, .addFinger, .removeFinger,
             .fingerChord, .swipeLeft, .swipeRight, .swipeUp, .swipeDown:
            3
        }
    }

    var requiresRawContacts: Bool {
        switch self {
        case .tipTapLeft, .tipTapRight, .addFinger, .removeFinger, .fingerChord:
            true
        case .tap, .hold, .swipeLeft, .swipeRight, .swipeUp, .swipeDown,
             .pinchIn, .pinchOut, .rotateClockwise, .rotateCounterclockwise:
            false
        }
    }
}

enum TrackpadRegion: String, Codable, CaseIterable, Hashable, Sendable {
    case any
    // Legacy quadrants. Their geometry must remain stable for migrated rules.
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case topEdge
    case bottomEdge
    case leftEdge
    case rightEdge
    case cornerTopLeft
    case cornerTopRight
    case cornerBottomLeft
    case cornerBottomRight
    case gridTopLeft
    case gridTopCenter
    case gridTopRight
    case gridMiddleLeft
    case gridCenter
    case gridMiddleRight
    case gridBottomLeft
    case gridBottomCenter
    case gridBottomRight

    func contains(_ point: TrackpadPoint) -> Bool {
        switch self {
        case .any:
            true
        case .topLeft:
            point.x < 0.5 && point.y >= 0.5
        case .topRight:
            point.x >= 0.5 && point.y >= 0.5
        case .bottomLeft:
            point.x < 0.5 && point.y < 0.5
        case .bottomRight:
            point.x >= 0.5 && point.y < 0.5
        case .topEdge:
            point.y >= 0.85
        case .bottomEdge:
            point.y <= 0.15
        case .leftEdge:
            point.x <= 0.15
        case .rightEdge:
            point.x >= 0.85
        case .cornerTopLeft:
            point.x <= 0.2 && point.y >= 0.8
        case .cornerTopRight:
            point.x >= 0.8 && point.y >= 0.8
        case .cornerBottomLeft:
            point.x <= 0.2 && point.y <= 0.2
        case .cornerBottomRight:
            point.x >= 0.8 && point.y <= 0.2
        case .gridTopLeft:
            point.x < 1 / 3 && point.y >= 2 / 3
        case .gridTopCenter:
            point.x >= 1 / 3 && point.x < 2 / 3 && point.y >= 2 / 3
        case .gridTopRight:
            point.x >= 2 / 3 && point.y >= 2 / 3
        case .gridMiddleLeft:
            point.x < 1 / 3 && point.y >= 1 / 3 && point.y < 2 / 3
        case .gridCenter:
            point.x >= 1 / 3 && point.x < 2 / 3
                && point.y >= 1 / 3 && point.y < 2 / 3
        case .gridMiddleRight:
            point.x >= 2 / 3 && point.y >= 1 / 3 && point.y < 2 / 3
        case .gridBottomLeft:
            point.x < 1 / 3 && point.y < 1 / 3
        case .gridBottomCenter:
            point.x >= 1 / 3 && point.x < 2 / 3 && point.y < 1 / 3
        case .gridBottomRight:
            point.x >= 2 / 3 && point.y < 1 / 3
        }
    }
}

struct InputEventDescriptor: Codable, Hashable, Sendable {
    let kind: InputEventKind
    let keyCode: UInt16?
    let modifiers: Set<InputModifier>
    let mouseButton: Int?
    let gesture: TrackpadGesture?
    let fingerCount: Int?
    let trackpadRegion: TrackpadRegion?
    let gestureEvent: GestureEvent?
    let advancedGesture: AdvancedGestureMetadata?
    let trackpadPath: [TrackpadPoint]
    let timestamp: Date

    init(
        kind: InputEventKind,
        keyCode: UInt16? = nil,
        modifiers: Set<InputModifier> = [],
        mouseButton: Int? = nil,
        gesture: TrackpadGesture? = nil,
        fingerCount: Int? = nil,
        trackpadRegion: TrackpadRegion? = nil,
        gestureEvent: GestureEvent? = nil,
        advancedGesture: AdvancedGestureMetadata? = nil,
        trackpadPath: [TrackpadPoint] = [],
        timestamp: Date = Date()
    ) {
        self.kind = kind
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.mouseButton = mouseButton
        self.gesture = gesture
        self.fingerCount = fingerCount
        self.trackpadRegion = trackpadRegion
        self.gestureEvent = gestureEvent
        self.advancedGesture = advancedGesture
        self.trackpadPath = trackpadPath
        self.timestamp = timestamp
    }

    static func keyboard(
        keyCode: UInt16,
        modifiers: Set<InputModifier> = [],
        timestamp: Date = Date()
    ) -> Self {
        Self(kind: .keyboard, keyCode: keyCode, modifiers: modifiers, timestamp: timestamp)
    }

    static func mouseButton(
        _ button: Int,
        modifiers: Set<InputModifier> = [],
        timestamp: Date = Date()
    ) -> Self {
        Self(kind: .mouseButton, modifiers: modifiers, mouseButton: button, timestamp: timestamp)
    }

    static func trackpad(
        _ gesture: TrackpadGesture,
        fingerCount: Int? = nil,
        region: TrackpadRegion = .any,
        timestamp: Date = Date()
    ) -> Self {
        Self(
            kind: .trackpadGesture,
            gesture: gesture,
            fingerCount: fingerCount ?? gesture.defaultFingerCount,
            trackpadRegion: region,
            timestamp: timestamp
        )
    }

    static func trackpad(_ event: GestureEvent) -> Self {
        Self(
            kind: .trackpadGesture,
            gesture: event.kind,
            fingerCount: event.fingerCount,
            trackpadRegion: event.startRegion,
            gestureEvent: event,
            advancedGesture: event.advanced,
            trackpadPath: event.path,
            timestamp: event.occurredAt
        )
    }

    static func unclassifiedTrackpadPath(_ features: GestureFeatures) -> Self {
        Self(
            kind: .trackpadGesture,
            fingerCount: features.maximumFingerCount,
            trackpadRegion: features.startRegion,
            trackpadPath: features.centroidPath,
            timestamp: features.occurredAt
        )
    }

    func withModifiers(_ modifiers: Set<InputModifier>) -> Self {
        Self(
            kind: kind,
            keyCode: keyCode,
            modifiers: modifiers,
            mouseButton: mouseButton,
            gesture: gesture,
            fingerCount: fingerCount,
            trackpadRegion: trackpadRegion,
            gestureEvent: gestureEvent,
            advancedGesture: advancedGesture,
            trackpadPath: trackpadPath,
            timestamp: timestamp
        )
    }
}
