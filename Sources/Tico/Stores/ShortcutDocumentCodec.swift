import Foundation

struct ShortcutDocumentCodec {
    static let currentVersion = 8

    static func makeDocument(
        version: Int,
        rules: [ShortcutRule],
        reusableWorkflows: [ActionWorkflow],
        customGestureTemplates: [CustomGestureTemplate],
        presets: [GesturePreset]
    ) -> ShortcutDocument {
        ShortcutDocument(
            version: version,
            rules: rules,
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
                    reusableWorkflows: document.reusableWorkflows,
                    customGestureTemplates: document.customGestureTemplates,
                    presets: document.presets
                )
                try DocumentSecurityPolicy.validate(
                    rules: decoded.rules,
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
        if let legacy = try? decoder.decode([LegacyShortcutContextMigration.Rule].self, from: data) {
            let legacyRules = try legacy.map(LegacyShortcutContextMigration().migrate)
            try DocumentSecurityPolicy.validate(
                rules: legacyRules,
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
    let reusableWorkflows: [ActionWorkflow]
    let customGestureTemplates: [CustomGestureTemplate]
    let presets: [GesturePreset]

    private enum CodingKeys: String, CodingKey {
        case version
        case rules
        case reusableWorkflows
        case customGestureTemplates
        case presets
    }

    init(
        version: Int,
        rules: [ShortcutRule],
        reusableWorkflows: [ActionWorkflow],
        customGestureTemplates: [CustomGestureTemplate],
        presets: [GesturePreset]
    ) {
        self.version = version
        self.rules = rules
        self.reusableWorkflows = reusableWorkflows
        self.customGestureTemplates = customGestureTemplates
        self.presets = presets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        let migration = try LegacyShortcutContextMigration(from: decoder)
        rules = try container.decode([LegacyShortcutContextMigration.Rule].self, forKey: .rules)
            .map(migration.migrate)
        reusableWorkflows = try container.decodeIfPresent(
            [ActionWorkflow].self,
            forKey: .reusableWorkflows
        ) ?? []
        customGestureTemplates = try container.decodeIfPresent(
            [CustomGestureTemplate].self,
            forKey: .customGestureTemplates
        ) ?? []
        presets = try (container.decodeIfPresent([LegacyShortcutContextMigration.Preset].self, forKey: .presets) ?? [])
            .map(migration.migrate)
    }
}

private struct ShortcutDocumentHeader: Decodable {
    let version: Int
}

struct DecodedShortcutDocument {
    var version: Int
    var rules: [ShortcutRule]
    var reusableWorkflows: [ActionWorkflow] = []
    var customGestureTemplates: [CustomGestureTemplate] = []
    var presets: [GesturePreset] = []
}
