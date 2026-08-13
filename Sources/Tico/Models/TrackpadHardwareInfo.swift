import Foundation

struct TrackpadHardwareInfo: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let transport: String
    let isBuiltIn: Bool

    var isMagicTrackpad: Bool {
        name.localizedCaseInsensitiveContains("Magic Trackpad")
    }
}
