import XCTest
@testable import AirShortcut

@MainActor
final class RuleEditingSessionTests: XCTestCase {
    func testSessionOwnsDirtyStateAndRevertTransition() {
        let rule = makeRule()
        let session = RuleEditingSession(rule: rule)

        XCTAssertFalse(session.hasUnsavedChanges)

        session.draft.name = "Regra alterada"

        XCTAssertTrue(session.hasUnsavedChanges)
        session.revert()

        XCTAssertEqual(session.draft, rule)
        XCTAssertFalse(session.hasUnsavedChanges)
        XCTAssertNil(session.pendingConflictSave)
    }

    func testMarkSavedAdvancesBaselineAndPresetUsesCurrentDraft() {
        let rule = makeRule()
        let session = RuleEditingSession(rule: rule)
        var savedRule = rule
        savedRule.name = "Regra salva"
        savedRule.notes = "Notas do preset"

        session.markSaved(savedRule)

        XCTAssertEqual(session.draft, savedRule)
        XCTAssertFalse(session.hasUnsavedChanges)

        let preset = session.makePreset()

        XCTAssertEqual(preset.name, "Regra salva")
        XCTAssertEqual(preset.summary, "Notas do preset")
        XCTAssertEqual(preset.trigger, savedRule.trigger)
        XCTAssertEqual(preset.workflow, savedRule.workflow)
    }

    func testURLValidationStaysLocalToSession() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com"))
        let rule = ShortcutRule(
            name: "Abrir site",
            trigger: .keyboard(keyCode: 49, modifiers: []),
            action: .openURL(url: url)
        )
        let session = RuleEditingSession(rule: rule)

        XCTAssertTrue(session.urlIsValid)
        session.draft.action = .openURL(
            url: try XCTUnwrap(URL(string: "file:///tmp/local"))
        )

        XCTAssertFalse(session.urlIsValid)
        XCTAssertFalse(session.canSave)
    }

    private func makeRule() -> ShortcutRule {
        ShortcutRule(
            name: "Regra de teste",
            trigger: .keyboard(keyCode: 49, modifiers: [.command]),
            action: .notification(title: "Tico", body: "Teste"),
            notes: "Notas iniciais"
        )
    }
}
