import Combine
import Foundation

enum ShortcutImportStrategy: String, Codable, CaseIterable, Sendable {
    case replace
    case merge
}

enum ShortcutStoreError: LocalizedError, Equatable {
    case duplicateRule(UUID)
    case ruleNotFound(UUID)
    case unsupportedVersion(Int)
    case invalidDocument

    var errorDescription: String? {
        switch self {
        case let .duplicateRule(id):
            return "A shortcut rule with id \(id.uuidString) already exists."
        case let .ruleNotFound(id):
            return "Shortcut rule \(id.uuidString) was not found."
        case let .unsupportedVersion(version):
            return "Shortcut document version \(version) is not supported."
        case .invalidDocument:
            return "O documento de atalhos não contém um JSON válido para o \(TicoBrand.displayName)."
        }
    }
}

final class ShortcutStore: ObservableObject {
    static let currentDocumentVersion = ShortcutDocumentCodec.currentVersion

    @Published private(set) var rules: [ShortcutRule] = []
    @Published private(set) var profiles: [ShortcutProfile] = []
    @Published private(set) var reusableWorkflows: [ActionWorkflow] = []
    @Published private(set) var customGestureTemplates: [CustomGestureTemplate] = []
    @Published private(set) var presets: [GesturePreset] = []
    @Published private(set) var lastError: String?

    let fileURL: URL

    private let fileManager: FileManager
    private let seedExamples: Bool
    private let now: () -> Date
    private let conflictAnalyzer = RuleConflictAnalyzer()

    init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default,
        seedExamples: Bool = true,
        now: @escaping () -> Date = Date.init
    ) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)
        self.seedExamples = seedExamples
        self.now = now

        do {
            try load()
        } catch {
            lastError = error.localizedDescription
        }
    }

    static func defaultFileURL(fileManager: FileManager = .default) -> URL {
        let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.temporaryDirectory

        return applicationSupport
            .appendingPathComponent(
                TicoBrand.legacyApplicationSupportDirectoryName,
                isDirectory: true
            )
            .appendingPathComponent("shortcuts.json", isDirectory: false)
    }

    func load() throws {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            if seedExamples {
                rules = Self.exampleRules(createdAt: now())
                try writeDocument(to: fileURL)
            } else {
                rules = []
            }
            lastError = nil
            return
        }

        do {
            let data = try DocumentSecurityPolicy.readBoundedData(from: fileURL)
            let decoded = try ShortcutDocumentCodec.decode(data)
            rules = decoded.rules
            profiles = decoded.profiles
            reusableWorkflows = decoded.reusableWorkflows
            customGestureTemplates = decoded.customGestureTemplates
            presets = decoded.presets
            if decoded.version < Self.currentDocumentVersion {
                try backupDocumentIfNeeded(data, version: decoded.version)
                try writeDocument(to: fileURL)
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    func save() throws {
        do {
            try writeDocument(to: fileURL)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    @discardableResult
    func add(_ rule: ShortcutRule) throws -> ShortcutRule {
        guard !rules.contains(where: { $0.id == rule.id }) else {
            throw ShortcutStoreError.duplicateRule(rule.id)
        }

        try commit { rules in
            rules.append(rule)
        }
        return rule
    }

    @discardableResult
    func create(
        name: String,
        isEnabled: Bool = true,
        trigger: TriggerDefinition,
        action: ShortcutAction,
        notes: String = ""
    ) throws -> ShortcutRule {
        let timestamp = now()
        let rule = ShortcutRule(
            name: name,
            isEnabled: isEnabled,
            trigger: trigger,
            action: action,
            notes: notes,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        return try add(rule)
    }

    func update(_ rule: ShortcutRule) throws {
        guard let index = rules.firstIndex(where: { $0.id == rule.id }) else {
            throw ShortcutStoreError.ruleNotFound(rule.id)
        }

        try commit { rules in
            var updatedRule = rule
            updatedRule.createdAt = rules[index].createdAt
            updatedRule.updatedAt = now()
            rules[index] = updatedRule
        }
    }

    func conflicts(for rule: ShortcutRule) -> [RuleConflict] {
        conflictAnalyzer.conflicts(for: rule, among: rules, profiles: profiles)
    }

    func replaceConflictingRules(with rule: ShortcutRule) throws {
        let conflictIDs = Set(
            conflicts(for: rule)
                .filter { $0.severity == .replacementRequired }
                .map(\.existingRuleID)
        )
        guard let existingIndex = rules.firstIndex(where: { $0.id == rule.id }) else {
            throw ShortcutStoreError.ruleNotFound(rule.id)
        }
        let originalCreatedAt = rules[existingIndex].createdAt

        try commit { rules in
            rules.removeAll { conflictIDs.contains($0.id) }
            guard let index = rules.firstIndex(where: { $0.id == rule.id }) else {
                throw ShortcutStoreError.ruleNotFound(rule.id)
            }
            var updatedRule = rule
            updatedRule.createdAt = originalCreatedAt
            updatedRule.updatedAt = now()
            rules[index] = updatedRule
        }
    }

    func delete(id: UUID) throws {
        guard let index = rules.firstIndex(where: { $0.id == id }) else {
            throw ShortcutStoreError.ruleNotFound(id)
        }

        try commit { rules in
            rules.remove(at: index)
        }
    }

    func setEnabled(_ isEnabled: Bool, for id: UUID) throws {
        guard let index = rules.firstIndex(where: { $0.id == id }) else {
            throw ShortcutStoreError.ruleNotFound(id)
        }

        try commit { rules in
            rules[index].isEnabled = isEnabled
            rules[index].updatedAt = now()
        }
    }

    func replaceAll(with rules: [ShortcutRule]) throws {
        try commit { storedRules in
            storedRules = rules
        }
    }

    @discardableResult
    func addProfile(_ profile: ShortcutProfile) throws -> ShortcutProfile {
        let previous = profiles
        profiles.append(profile)
        do {
            try writeDocument(to: fileURL)
            return profile
        } catch {
            profiles = previous
            throw error
        }
    }

    func updateProfile(_ profile: ShortcutProfile) throws {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else {
            throw ShortcutStoreError.invalidDocument
        }
        let previous = profiles
        profiles[index] = profile
        do {
            try writeDocument(to: fileURL)
        } catch {
            profiles = previous
            throw error
        }
    }

    func deleteProfile(id: UUID) throws {
        let previousProfiles = profiles
        let previousRules = rules
        profiles.removeAll { $0.id == id }
        for index in rules.indices where rules[index].profileID == id {
            rules[index].profileID = nil
        }
        do {
            try writeDocument(to: fileURL)
        } catch {
            profiles = previousProfiles
            rules = previousRules
            throw error
        }
    }

    func setProfileEnabled(_ isEnabled: Bool, id: UUID) throws {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else {
            throw ShortcutStoreError.invalidDocument
        }
        var value = profiles[index]
        value.isEnabled = isEnabled
        try updateProfile(value)
    }

    func saveReusableWorkflow(_ workflow: ActionWorkflow) throws {
        let previous = reusableWorkflows
        if let index = reusableWorkflows.firstIndex(where: { $0.id == workflow.id }) {
            reusableWorkflows[index] = workflow
        } else {
            reusableWorkflows.append(workflow)
        }
        do {
            try writeDocument(to: fileURL)
        } catch {
            reusableWorkflows = previous
            throw error
        }
    }

    func saveCustomGestureTemplate(_ template: CustomGestureTemplate) throws {
        let previous = customGestureTemplates
        if let index = customGestureTemplates.firstIndex(where: { $0.id == template.id }) {
            customGestureTemplates[index] = template
        } else {
            customGestureTemplates.append(template)
        }
        do {
            try writeDocument(to: fileURL)
        } catch {
            customGestureTemplates = previous
            throw error
        }
    }

    func duplicateCustomGestureTemplate(id: UUID) throws -> CustomGestureTemplate {
        guard var copy = customGestureTemplates.first(where: { $0.id == id }) else {
            throw ShortcutStoreError.invalidDocument
        }
        copy.id = UUID()
        copy.name += " — cópia"
        copy.createdAt = now()
        try saveCustomGestureTemplate(copy)
        return copy
    }

    func deleteCustomGestureTemplate(id: UUID) throws {
        let isInUse = rules.contains { rule in
            if case let .customTrackpad(template) = rule.trigger {
                return template.id == id
            }
            return false
        }
        guard !isInUse else {
            throw ShortcutStoreError.invalidDocument
        }
        let previous = customGestureTemplates
        customGestureTemplates.removeAll { $0.id == id }
        do {
            try writeDocument(to: fileURL)
        } catch {
            customGestureTemplates = previous
            throw error
        }
    }

    func savePreset(_ preset: GesturePreset) throws {
        let previous = presets
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
        } else {
            presets.append(preset)
        }
        do {
            try writeDocument(to: fileURL)
        } catch {
            presets = previous
            throw error
        }
    }

    func exportRules(to destinationURL: URL) throws {
        do {
            try writeDocument(to: destinationURL)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    func importRules(
        from sourceURL: URL,
        strategy: ShortcutImportStrategy = .replace
    ) throws {
        do {
            var imported = try ShortcutDocumentCodec.decode(
                DocumentSecurityPolicy.readBoundedData(from: sourceURL)
            )
            for index in imported.rules.indices {
                imported.rules[index].isEnabled = false
            }
            let previous = (
                rules,
                profiles,
                reusableWorkflows,
                customGestureTemplates,
                presets
            )
            switch strategy {
            case .replace:
                rules = imported.rules
            case .merge:
                rules = Self.merged(rules, imported.rules)
            }
            switch strategy {
            case .replace:
                profiles = imported.profiles
                reusableWorkflows = imported.reusableWorkflows
                customGestureTemplates = imported.customGestureTemplates
                presets = imported.presets
            case .merge:
                profiles = Self.merged(profiles, imported.profiles)
                reusableWorkflows = Self.merged(reusableWorkflows, imported.reusableWorkflows)
                customGestureTemplates = Self.merged(
                    customGestureTemplates,
                    imported.customGestureTemplates
                )
                presets = Self.merged(presets, imported.presets)
            }
            do {
                try writeDocument(to: fileURL)
                lastError = nil
            } catch {
                (
                    rules,
                    profiles,
                    reusableWorkflows,
                    customGestureTemplates,
                    presets
                ) = previous
                throw error
            }
        } catch {
            lastError = error.localizedDescription
            throw error
        }
    }

    static func exampleRules(createdAt: Date = Date()) -> [ShortcutRule] {
        [
            ShortcutRule(
                name: "Open Safari",
                trigger: .keyboard(keyCode: 1, modifiers: [.command, .shift]),
                action: .openApplication(bundleIdentifier: "com.apple.Safari"),
                notes: "Example shortcut. Edit or delete it at any time.",
                createdAt: createdAt,
                updatedAt: createdAt
            ),
            ShortcutRule(
                name: "Abrir site de exemplo do \(TicoBrand.displayName)",
                trigger: .mouseButton(button: 3, modifiers: []),
                action: .openURL(url: URL(string: "https://www.apple.com/macos/")!),
                notes: "Example for an extra mouse button.",
                createdAt: createdAt,
                updatedAt: createdAt
            )
        ]
    }

    private func commit(_ mutation: (inout [ShortcutRule]) throws -> Void) throws {
        let previousRules = rules

        do {
            try mutation(&rules)
            try writeDocument(to: fileURL)
            lastError = nil
        } catch {
            rules = previousRules
            lastError = error.localizedDescription
            throw error
        }
    }

    private func writeDocument(to destinationURL: URL) throws {
        synchronizeEmbeddedTemplates()
        let directoryURL = destinationURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let document = ShortcutDocument(
            version: Self.currentDocumentVersion,
            rules: rules,
            profiles: profiles,
            reusableWorkflows: reusableWorkflows,
            customGestureTemplates: customGestureTemplates,
            presets: presets
        )
        try ShortcutDocumentCodec.encode(document).write(to: destinationURL, options: .atomic)
    }

    private func synchronizeEmbeddedTemplates() {
        for rule in rules {
            guard case let .customTrackpad(template) = rule.trigger else { continue }
            if let index = customGestureTemplates.firstIndex(where: { $0.id == template.id }) {
                customGestureTemplates[index] = template
            } else {
                customGestureTemplates.append(template)
            }
        }
    }

    private static func merged<T: Identifiable>(
        _ existing: [T],
        _ imported: [T]
    ) -> [T] where T.ID: Equatable {
        var result = existing
        for value in imported {
            if let index = result.firstIndex(where: { $0.id == value.id }) {
                result[index] = value
            } else {
                result.append(value)
            }
        }
        return result
    }

    private func backupDocumentIfNeeded(_ data: Data, version: Int) throws {
        let backupURL = fileURL
            .deletingPathExtension()
            .appendingPathExtension("v\(version).backup.json")
        guard !fileManager.fileExists(atPath: backupURL.path) else { return }
        try data.write(to: backupURL, options: .atomic)
    }

}
