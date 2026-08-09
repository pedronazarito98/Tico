import Foundation

struct ShortcutDocumentCodec {
    static let currentVersion = 6

    static func makeDocument(
        version: Int,
        rules: [ShortcutRule],
        profiles: [ShortcutProfile],
        reusableWorkflows: [ActionWorkflow],
        customGestureTemplates: [CustomGestureTemplate],
        presets: [GesturePreset]
    ) -> ShortcutDocument {
        ShortcutDocument(
            version: version,
            rules: rules,
            profiles: profiles,
            reusableWorkflows: reusableWorkflows,
            customGestureTemplates: customGestureTemplates,
            presets: presets
        )
    }

    static func encode(_ document: ShortcutDocument) throws -> Data {
        try makeEncoder().encode(document)
    }

    static func decode(_ data: Data) throws -> DecodedShortcutDocument {
        guard data.count <= DocumentSecurityPolicy.maximumDocumentBytes else {
            throw ShortcutStoreError.invalidDocument
        }

        let decoder = makeDecoder()

        if let header = try? decoder.decode(ShortcutDocumentHeader.self, from: data) {
            guard header.version <= currentVersion else {
                throw ShortcutStoreError.unsupportedVersion(header.version)
            }

            do {
                let document = try decoder.decode(ShortcutDocument.self, from: data)
                let decoded = DecodedShortcutDocument(
                    version: document.version,
                    rules: document.rules,
                    profiles: document.profiles,
                    reusableWorkflows: document.reusableWorkflows,
                    customGestureTemplates: document.customGestureTemplates,
                    presets: document.presets
                )
                try DocumentSecurityPolicy.validate(
                    rules: decoded.rules,
                    profiles: decoded.profiles,
                    reusableWorkflows: decoded.reusableWorkflows,
                    customTemplates: decoded.customGestureTemplates,
                    presets: decoded.presets
                )
                return decoded
            } catch {
                throw ShortcutStoreError.invalidDocument
            }
        }

        // Version 0 stored the rules as a top-level array. Accepting it provides
        // a small, deterministic migration path for early development builds.
        if let legacyRules = try? decoder.decode([ShortcutRule].self, from: data) {
            try DocumentSecurityPolicy.validate(
                rules: legacyRules,
                profiles: [],
                reusableWorkflows: [],
                customTemplates: [],
                presets: []
            )
            return DecodedShortcutDocument(version: 0, rules: legacyRules)
        }

        throw ShortcutStoreError.invalidDocument
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }
}

struct ShortcutDocument: Codable {
    let version: Int
    let rules: [ShortcutRule]
    let profiles: [ShortcutProfile]
    let reusableWorkflows: [ActionWorkflow]
    let customGestureTemplates: [CustomGestureTemplate]
    let presets: [GesturePreset]

    private enum CodingKeys: String, CodingKey {
        case version
        case rules
        case profiles
        case reusableWorkflows
        case customGestureTemplates
        case presets
    }

    init(
        version: Int,
        rules: [ShortcutRule],
        profiles: [ShortcutProfile],
        reusableWorkflows: [ActionWorkflow],
        customGestureTemplates: [CustomGestureTemplate],
        presets: [GesturePreset]
    ) {
        self.version = version
        self.rules = rules
        self.profiles = profiles
        self.reusableWorkflows = reusableWorkflows
        self.customGestureTemplates = customGestureTemplates
        self.presets = presets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        rules = try container.decode([ShortcutRule].self, forKey: .rules)
        profiles = try container.decodeIfPresent([ShortcutProfile].self, forKey: .profiles) ?? []
        reusableWorkflows = try container.decodeIfPresent(
            [ActionWorkflow].self,
            forKey: .reusableWorkflows
        ) ?? []
        customGestureTemplates = try container.decodeIfPresent(
            [CustomGestureTemplate].self,
            forKey: .customGestureTemplates
        ) ?? []
        presets = try container.decodeIfPresent([GesturePreset].self, forKey: .presets) ?? []
    }
}

private struct ShortcutDocumentHeader: Decodable {
    let version: Int
}

struct DecodedShortcutDocument {
    var version: Int
    var rules: [ShortcutRule]
    var profiles: [ShortcutProfile] = []
    var reusableWorkflows: [ActionWorkflow] = []
    var customGestureTemplates: [CustomGestureTemplate] = []
    var presets: [GesturePreset] = []
}
