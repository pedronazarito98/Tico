import Foundation

struct TrackpadProviderCapabilities: Equatable, Sendable {
    var rawContacts: Bool
    var pressure: Bool
    var stableDeviceIdentity: Bool

    static let privateMultitouch = Self(
        rawContacts: true,
        pressure: true,
        stableDeviceIdentity: false
    )
    static let replay = Self(
        rawContacts: true,
        pressure: true,
        stableDeviceIdentity: true
    )
}

enum TrackpadFrameProviderError: LocalizedError, Equatable {
    case unavailable(String)
    case alreadyRunning
    case invalidReplay

    var errorDescription: String? {
        switch self {
        case let .unavailable(reason): reason
        case .alreadyRunning: "O provedor de frames já está em execução."
        case .invalidReplay: "A sessão de replay não contém frames válidos."
        }
    }
}

protocol TrackpadFrameProvider: AnyObject {
    var capabilities: TrackpadProviderCapabilities { get }
    var isRunning: Bool { get }
    func start(onFrame: @escaping @Sendable (RawTrackpadFrame) -> Void) throws
    func stop()
}
