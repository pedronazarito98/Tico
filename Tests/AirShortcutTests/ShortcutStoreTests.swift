import Foundation
import XCTest
@testable import AirShortcut

final class ShortcutStoreTests: XCTestCase {
    private var temporaryDirectories: [URL] = []

    override func tearDownWithError() throws {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories.removeAll()
    }

    func testMissingFileSeedsExamplesAndWritesVersionedDocument() throws {
        let fileURL = makeFileURL()

        let store = ShortcutStore(fileURL: fileURL, seedExamples: true)

        XCTAssertEqual(store.rules.count, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any]
        )
        XCTAssertEqual(json["version"] as? Int, ShortcutStore.currentDocumentVersion)
        XCTAssertNotNil(json["rules"] as? [[String: Any]])
    }

    func testExistingEmptyDocumentDoesNotSeedExamples() throws {
        let fileURL = makeFileURL()
        let initialStore = ShortcutStore(fileURL: fileURL, seedExamples: false)
        try initialStore.replaceAll(with: [])

        let reloadedStore = ShortcutStore(fileURL: fileURL, seedExamples: true)

        XCTAssertTrue(reloadedStore.rules.isEmpty)
        XCTAssertNil(reloadedStore.lastError)
    }

    func testInjectedRepositoryOwnsTheStorePathAndPersistence() throws {
        let fileURL = makeFileURL()
        let repository = FileShortcutRepository(fileURL: fileURL)
        let store = ShortcutStore(repository: repository, seedExamples: false)
        let rule = makeRule()

        XCTAssertEqual(store.fileURL, fileURL)
        try store.add(rule)

        let reloadedStore = ShortcutStore(
            repository: FileShortcutRepository(fileURL: fileURL),
            seedExamples: false
        )
        XCTAssertEqual(reloadedStore.rules, [rule])
    }

    func testCRUDPersistsAcrossStoreInstances() throws {
        let fileURL = makeFileURL()
        let updateDate = Date(timeIntervalSince1970: 1_800_000_000)
        let store = ShortcutStore(
            fileURL: fileURL,
            seedExamples: false,
            now: { updateDate }
        )
        let originalDate = Date(timeIntervalSince1970: 1_700_000_000)
        let rule = makeRule(createdAt: originalDate)

        try store.add(rule)
        XCTAssertEqual(store.rules, [rule])

        var changedRule = rule
        changedRule.name = "Changed name"
        changedRule.notes = "Changed notes"
        try store.update(changedRule)
        try store.setEnabled(false, for: rule.id)

        let reloadedStore = ShortcutStore(fileURL: fileURL, seedExamples: true)
        let persistedRule = try XCTUnwrap(reloadedStore.rules.first)
        XCTAssertEqual(persistedRule.name, "Changed name")
        XCTAssertEqual(persistedRule.notes, "Changed notes")
        XCTAssertFalse(persistedRule.isEnabled)
        XCTAssertEqual(persistedRule.createdAt, originalDate)
        XCTAssertEqual(persistedRule.updatedAt, updateDate)

        try reloadedStore.delete(id: rule.id)
        XCTAssertTrue(reloadedStore.rules.isEmpty)
        XCTAssertThrowsError(try reloadedStore.delete(id: rule.id)) { error in
            XCTAssertEqual(error as? ShortcutStoreError, .ruleNotFound(rule.id))
        }
    }

    func testDuplicateRuleIsRejectedWithoutChangingPersistedRules() throws {
        let fileURL = makeFileURL()
        let store = ShortcutStore(fileURL: fileURL, seedExamples: false)
        let rule = makeRule()
        try store.add(rule)

        XCTAssertThrowsError(try store.add(rule)) { error in
            XCTAssertEqual(error as? ShortcutStoreError, .duplicateRule(rule.id))
        }

        let reloadedStore = ShortcutStore(fileURL: fileURL, seedExamples: false)
        XCTAssertEqual(reloadedStore.rules, [rule])
    }

    func testLegacyTopLevelArrayIsMigratedOnLoad() throws {
        let fileURL = makeFileURL()
        let rule = makeRule()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode([rule]).write(to: fileURL)

        let store = ShortcutStore(fileURL: fileURL, seedExamples: true)

        XCTAssertEqual(store.rules, [rule])
        XCTAssertNil(store.lastError)
    }

    func testVersionOneTrackpadRuleDefaultsAdvancedFields() throws {
        let fileURL = makeFileURL()
        let store = ShortcutStore(fileURL: fileURL, seedExamples: false)
        let rule = ShortcutRule(
            name: "Legacy trackpad",
            trigger: .trackpad(gesture: .swipeLeft),
            action: .notification(title: "Test", body: "")
        )
        try store.replaceAll(with: [rule])

        var document = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any]
        )
        document["version"] = 1
        var rules = try XCTUnwrap(document["rules"] as? [[String: Any]])
        var trigger = try XCTUnwrap(rules[0]["trigger"] as? [String: Any])
        trigger.removeValue(forKey: "fingerCount")
        trigger.removeValue(forKey: "region")
        rules[0]["trigger"] = trigger
        document["rules"] = rules
        try JSONSerialization.data(withJSONObject: document).write(to: fileURL)

        let reloaded = ShortcutStore(fileURL: fileURL, seedExamples: false)
        XCTAssertEqual(
            reloaded.rules.first?.trigger,
            .trackpad(gesture: .swipeLeft, fingerCount: 3, region: .any)
        )
    }

    func testVersionTwoTrackpadRuleMigratesToSpecAndCreatesBackup() throws {
        let fileURL = makeFileURL()
        let originalStore = ShortcutStore(fileURL: fileURL, seedExamples: false)
        let rule = ShortcutRule(
            name: "Legacy v2 trackpad",
            trigger: .trackpad(gesture: .swipeRight, fingerCount: 4, region: .topLeft),
            action: .notification(title: "Test", body: ""),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        try originalStore.replaceAll(with: [rule])

        var document = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any]
        )
        document["version"] = 2
        var rules = try XCTUnwrap(document["rules"] as? [[String: Any]])
        var trigger = try XCTUnwrap(rules[0]["trigger"] as? [String: Any])
        trigger.removeValue(forKey: "spec")
        trigger["gesture"] = TrackpadGesture.swipeRight.rawValue
        trigger["fingerCount"] = 4
        trigger["region"] = TrackpadRegion.topLeft.rawValue
        rules[0]["trigger"] = trigger
        document["rules"] = rules
        try JSONSerialization.data(withJSONObject: document).write(to: fileURL)

        let migrated = ShortcutStore(fileURL: fileURL, seedExamples: false)

        XCTAssertEqual(migrated.rules, [rule])
        let migratedJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any]
        )
        XCTAssertEqual(migratedJSON["version"] as? Int, ShortcutStore.currentDocumentVersion)
        let migratedRules = try XCTUnwrap(migratedJSON["rules"] as? [[String: Any]])
        let migratedTrigger = try XCTUnwrap(migratedRules[0]["trigger"] as? [String: Any])
        XCTAssertNotNil(migratedTrigger["spec"])

        let backupURL = fileURL
            .deletingPathExtension()
            .appendingPathExtension("v2.backup.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path))
        let backupJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: backupURL)) as? [String: Any]
        )
        XCTAssertEqual(backupJSON["version"] as? Int, 2)
    }

    func testExportAndReplaceImportRoundTrip() throws {
        let sourceURL = makeFileURL(fileName: "source.json")
        let exportURL = sourceURL.deletingLastPathComponent().appendingPathComponent("export.json")
        let destinationURL = makeFileURL(fileName: "destination.json")
        let rule = makeRule()
        let sourceStore = ShortcutStore(fileURL: sourceURL, seedExamples: false)
        try sourceStore.add(rule)
        try sourceStore.exportRules(to: exportURL)

        let destinationStore = ShortcutStore(fileURL: destinationURL, seedExamples: false)
        try destinationStore.add(makeRule(name: "Will be replaced"))
        try destinationStore.importRules(from: exportURL)

        var importedRule = rule
        importedRule.isEnabled = false
        XCTAssertEqual(destinationStore.rules, [importedRule])
        XCTAssertEqual(
            ShortcutStore(fileURL: destinationURL, seedExamples: false).rules,
            [importedRule]
        )
    }

    func testCustomTrackpadTemplatePersistsAcrossStoreInstances() throws {
        let fileURL = makeFileURL()
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let template = CustomGestureTemplate(
            name: "Meu L",
            fingerCount: 3...3,
            samplePaths: [
                [
                    TrackpadPoint(x: 0, y: 0),
                    TrackpadPoint(x: 0, y: 1),
                    TrackpadPoint(x: 1, y: 1)
                ],
                [
                    TrackpadPoint(x: 0, y: 0),
                    TrackpadPoint(x: 0, y: 0.9),
                    TrackpadPoint(x: 1, y: 0.9)
                ],
                [
                    TrackpadPoint(x: 0, y: 0),
                    TrackpadPoint(x: 0.1, y: 1),
                    TrackpadPoint(x: 1, y: 1)
                ]
            ],
            createdAt: timestamp
        )
        let rule = ShortcutRule(
            name: "Gesto livre",
            trigger: .customTrackpad(template: template),
            action: .notification(title: "Feito", body: ""),
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let store = ShortcutStore(fileURL: fileURL, seedExamples: false)

        try store.add(rule)

        XCTAssertEqual(
            ShortcutStore(fileURL: fileURL, seedExamples: false).rules,
            [rule]
        )
    }

    func testMergeImportUpdatesMatchingIDsAndAppendsNewRules() throws {
        let directory = makeTemporaryDirectory()
        let destinationURL = directory.appendingPathComponent("destination.json")
        let importURL = directory.appendingPathComponent("import.json")
        let sharedID = UUID()
        let existing = makeRule(id: sharedID, name: "Old")
        let retained = makeRule(name: "Retained")
        let updated = makeRule(id: sharedID, name: "Updated")
        let appended = makeRule(name: "Appended")

        let destinationStore = ShortcutStore(fileURL: destinationURL, seedExamples: false)
        try destinationStore.replaceAll(with: [existing, retained])
        let importStore = ShortcutStore(fileURL: importURL, seedExamples: false)
        try importStore.replaceAll(with: [updated, appended])

        try destinationStore.importRules(from: importURL, strategy: .merge)

        var disabledUpdated = updated
        disabledUpdated.isEnabled = false
        var disabledAppended = appended
        disabledAppended.isEnabled = false
        XCTAssertEqual(
            destinationStore.rules,
            [disabledUpdated, retained, disabledAppended]
        )
    }

    func testUnsupportedDocumentVersionDoesNotSeedExamples() throws {
        let fileURL = makeFileURL()
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("{\"version\":999,\"rules\":[]}".utf8).write(to: fileURL)

        let store = ShortcutStore(fileURL: fileURL, seedExamples: true)

        XCTAssertTrue(store.rules.isEmpty)
        XCTAssertNotNil(store.lastError)
        XCTAssertThrowsError(try store.load()) { error in
            XCTAssertEqual(error as? ShortcutStoreError, .unsupportedVersion(999))
        }
    }

    func testEventLogIsPersistedAndBounded() throws {
        let fileURL = makeFileURL(fileName: "events.json")
        let store = EventLogStore(fileURL: fileURL, maximumEntryCount: 2)
        let rule = makeRule()

        try store.record(rule: rule, result: .succeeded("one"))
        try store.record(rule: rule, result: .failed("two"))
        try store.record(rule: rule, result: .succeeded("three"))

        XCTAssertEqual(store.entries.map(\.result.message), ["three", "two"])
        let reloadedStore = EventLogStore(fileURL: fileURL, maximumEntryCount: 2)
        XCTAssertEqual(reloadedStore.entries.map(\.result.message), ["three", "two"])
    }

    private func makeRule(
        id: UUID = UUID(),
        name: String = "Open website",
        createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> ShortcutRule {
        ShortcutRule(
            id: id,
            name: name,
            trigger: .keyboard(keyCode: 49, modifiers: [.command, .shift]),
            action: .openURL(url: URL(string: "https://example.com")!),
            notes: "Test rule",
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }

    private func makeFileURL(fileName: String = "shortcuts.json") -> URL {
        makeTemporaryDirectory().appendingPathComponent(fileName)
    }

    private func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AirShortcutTests-\(UUID().uuidString)", isDirectory: true)
        temporaryDirectories.append(directory)
        return directory
    }
}
