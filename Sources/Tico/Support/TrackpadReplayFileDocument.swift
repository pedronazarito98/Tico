import SwiftUI
import UniformTypeIdentifiers

struct TrackpadReplayFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var replay: TrackpadReplayDocument

    init(replay: TrackpadReplayDocument) {
        self.replay = replay
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw TrackpadFrameProviderError.invalidReplay
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        replay = try decoder.decode(TrackpadReplayDocument.self, from: data)
        guard replay.version <= TrackpadReplayDocument.currentVersion else {
            throw TrackpadFrameProviderError.invalidReplay
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try ReplayFrameProvider.encode(replay))
    }
}
