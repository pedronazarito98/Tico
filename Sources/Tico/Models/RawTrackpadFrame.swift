import Foundation

struct TrackpadPoint: Codable, Equatable, Hashable, Sendable {
    var x: Double
    var y: Double

    func distance(to other: Self) -> Double {
        hypot(other.x - x, other.y - y)
    }
}

struct RawTrackpadTouch: Codable, Equatable, Sendable {
    var identifier: Int32
    var state: Int32
    var position: TrackpadPoint
    var velocity: TrackpadPoint
    var pressure: Double

    var isActivelyTouching: Bool {
        state == 3 || state == 4
    }
}

struct RawTrackpadFrame: Codable, Equatable, Sendable {
    var touches: [RawTrackpadTouch]
    var deviceTimestamp: Double
    var frameNumber: Int32
    var receivedAt: Date
    var deviceID: String?

    init(
        touches: [RawTrackpadTouch],
        deviceTimestamp: Double,
        frameNumber: Int32,
        receivedAt: Date,
        deviceID: String? = nil
    ) {
        self.touches = touches
        self.deviceTimestamp = deviceTimestamp
        self.frameNumber = frameNumber
        self.receivedAt = receivedAt
        self.deviceID = deviceID
    }
}
