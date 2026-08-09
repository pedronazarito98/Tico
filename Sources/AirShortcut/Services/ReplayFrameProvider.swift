import Foundation

struct TrackpadReplayDocument: Codable, Equatable, Sendable {
    static let currentVersion = 1
    static let maximumFrameCount = 10_000
    static let maximumTouchesPerFrame = 32
    static let maximumTotalTouches = 100_000
    static let maximumDuration: TimeInterval = 24 * 60 * 60
    static let maximumNameLength = 256
    static let maximumDeviceIDLength = 256

    var version: Int
    var name: String
    var frames: [RawTrackpadFrame]
    var createdAt: Date?

    init(
        name: String,
        frames: [RawTrackpadFrame],
        version: Int = currentVersion,
        createdAt: Date? = Date()
    ) {
        self.version = version
        self.name = name
        self.frames = frames
        self.createdAt = createdAt
    }
}

/// Scheduled playback callbacks run on `queue`; the owning
/// `TrackpadGestureService` serializes lifecycle calls to `start` and `stop`.
/// `generation` invalidates callbacks from a previous playback and must not be
/// accessed directly by another owner.
final class ReplayFrameProvider: TrackpadFrameProvider, @unchecked Sendable {
    let capabilities = TrackpadProviderCapabilities.replay
    private(set) var isRunning = false

    let document: TrackpadReplayDocument
    private let queue: DispatchQueue
    private let playbackSpeed: Double
    private var generation = UUID()

    init(
        document: TrackpadReplayDocument,
        playbackSpeed: Double = 1,
        queue: DispatchQueue = DispatchQueue(label: "com.pedronazarito.AirShortcut.replay")
    ) {
        self.document = document
        self.playbackSpeed = playbackSpeed.isFinite
            ? min(max(playbackSpeed, 0.01), 100)
            : 1
        self.queue = queue
    }

    convenience init(data: Data, playbackSpeed: Double = 1) throws {
        guard data.count <= DocumentSecurityPolicy.maximumDocumentBytes else {
            throw TrackpadFrameProviderError.invalidReplay
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let document = try decoder.decode(TrackpadReplayDocument.self, from: data)
        try Self.validate(document)
        self.init(document: document, playbackSpeed: playbackSpeed)
    }

    convenience init(contentsOf url: URL, playbackSpeed: Double = 1) throws {
        let data: Data
        do {
            data = try DocumentSecurityPolicy.readBoundedData(from: url)
        } catch {
            throw TrackpadFrameProviderError.invalidReplay
        }
        try self.init(data: data, playbackSpeed: playbackSpeed)
    }

    func start(onFrame: @escaping @Sendable (RawTrackpadFrame) -> Void) throws {
        guard !isRunning else { throw TrackpadFrameProviderError.alreadyRunning }
        try Self.validate(document)
        isRunning = true
        let currentGeneration = UUID()
        generation = currentGeneration
        scheduleFrame(
            at: 0,
            previousDate: document.frames[0].receivedAt,
            generation: currentGeneration,
            onFrame: onFrame
        )
    }

    func stop() {
        isRunning = false
        generation = UUID()
    }

    func replaySynchronously(onFrame: (RawTrackpadFrame) -> Void) {
        for frame in document.frames.prefix(TrackpadReplayDocument.maximumFrameCount) {
            var bounded = frame
            bounded.touches = Array(
                frame.touches.prefix(TrackpadReplayDocument.maximumTouchesPerFrame)
            )
            onFrame(bounded)
        }
    }

    static func encode(_ document: TrackpadReplayDocument) throws -> Data {
        try validate(document)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(document)
    }

    private func scheduleFrame(
        at index: Int,
        previousDate: Date,
        generation currentGeneration: UUID,
        onFrame: @escaping @Sendable (RawTrackpadFrame) -> Void
    ) {
        guard index < document.frames.count else {
            isRunning = false
            return
        }
        let frame = document.frames[index]
        let interval = index == 0
            ? 0
            : frame.receivedAt.timeIntervalSince(previousDate) / playbackSpeed
        let delay = min(max(interval, 0), TrackpadReplayDocument.maximumDuration)
        queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self,
                  self.isRunning,
                  self.generation == currentGeneration else {
                return
            }
            onFrame(frame)
            self.scheduleFrame(
                at: index + 1,
                previousDate: frame.receivedAt,
                generation: currentGeneration,
                onFrame: onFrame
            )
        }
    }

    static func validate(_ document: TrackpadReplayDocument) throws {
        guard document.version <= TrackpadReplayDocument.currentVersion,
              !document.frames.isEmpty,
              document.frames.count <= TrackpadReplayDocument.maximumFrameCount,
              document.name.utf8.count <= TrackpadReplayDocument.maximumNameLength else {
            throw TrackpadFrameProviderError.invalidReplay
        }

        var totalTouches = 0
        var previousDate = document.frames[0].receivedAt
        let firstDate = previousDate
        for frame in document.frames {
            totalTouches += frame.touches.count
            guard frame.touches.count <= TrackpadReplayDocument.maximumTouchesPerFrame,
                  totalTouches <= TrackpadReplayDocument.maximumTotalTouches,
                  frame.deviceTimestamp.isFinite,
                  frame.receivedAt.timeIntervalSince1970.isFinite,
                  frame.receivedAt >= previousDate,
                  frame.receivedAt.timeIntervalSince(firstDate)
                    <= TrackpadReplayDocument.maximumDuration,
                  (frame.deviceID?.utf8.count ?? 0)
                    <= TrackpadReplayDocument.maximumDeviceIDLength,
                  frame.touches.allSatisfy(Self.isValid) else {
                throw TrackpadFrameProviderError.invalidReplay
            }
            previousDate = frame.receivedAt
        }
    }

    private static func isValid(_ touch: RawTrackpadTouch) -> Bool {
        touch.position.x.isFinite
            && touch.position.y.isFinite
            && touch.velocity.x.isFinite
            && touch.velocity.y.isFinite
            && touch.pressure.isFinite
            && (-10...10).contains(touch.position.x)
            && (-10...10).contains(touch.position.y)
            && (-1_000...1_000).contains(touch.velocity.x)
            && (-1_000...1_000).contains(touch.velocity.y)
            && (-10...10).contains(touch.pressure)
    }
}
