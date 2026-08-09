import Combine
import Foundation

/// Owns the transient state and valid transitions of a rule editor.
///
/// Persistence and platform effects remain outside the session. The view uses
/// this object as the single source of truth for the draft, dirty state,
/// validation feedback, conflict confirmation, presets, and recording mode.
@MainActor
final class RuleEditingSession: ObservableObject {
    @Published var draft: ShortcutRule
    @Published var urlText: String
    @Published var recordingMode: TriggerRecordingMode?
    @Published var advancedTrackpadOptionsAreExpanded = false
    @Published var saveError: String?
    @Published var pendingConflictSave: ShortcutRule?

    private var originalRule: ShortcutRule

    init(rule: ShortcutRule) {
        draft = rule
        originalRule = rule
        if case let .openURL(url) = rule.action {
            urlText = url.absoluteString
        } else {
            urlText = "https://"
        }
    }

    var hasUnsavedChanges: Bool {
        draftForPersistence != originalRule
    }

    var draftForPersistence: ShortcutRule {
        draft
    }

    var urlIsValid: Bool {
        guard case .openURL = draft.action else { return true }
        guard let url = URL(string: urlText), let scheme = url.scheme else {
            return false
        }
        return scheme == "https" || scheme == "http"
    }

    var canSave: Bool {
        let hasUsableTrigger: Bool
        if case let .customTrackpad(template) = draft.trigger {
            hasUsableTrigger = template.samplePaths.count >= CustomGestureTemplate.minimumSampleCount
                && !template.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else if case let .sequence(sequence) = draft.trigger {
            hasUsableTrigger = sequence.isValid
        } else {
            hasUsableTrigger = true
        }

        return !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && urlIsValid
            && hasUsableTrigger
            && draft.workflow.isValid
    }

    func markSaved(_ value: ShortcutRule) {
        draft = value
        originalRule = value
        pendingConflictSave = nil
        saveError = nil
        synchronizeURLText()
    }

    func revert() {
        draft = originalRule
        pendingConflictSave = nil
        saveError = nil
        synchronizeURLText()
    }

    func stageConflictSave(_ value: ShortcutRule) {
        pendingConflictSave = value
    }

    func clearPendingConflict() {
        pendingConflictSave = nil
    }

    func recordSaveError(_ error: Error) {
        saveError = error.localizedDescription
    }

    func clearSaveError() {
        saveError = nil
    }

    func makePreset() -> GesturePreset {
        GesturePreset(
            name: draft.name,
            summary: draft.notes,
            trigger: draft.trigger,
            workflow: draft.workflow,
            profileID: draft.profileID
        )
    }

    func applyPreset(_ preset: GesturePreset) {
        draft.trigger = preset.trigger
        draft.workflow = preset.workflow
        draft.profileID = preset.profileID
    }

    func beginRecording(_ mode: TriggerRecordingMode) {
        recordingMode = mode
    }

    func finishRecording() {
        recordingMode = nil
    }

    private func synchronizeURLText() {
        if case let .openURL(url) = draft.action {
            urlText = url.absoluteString
        } else {
            urlText = "https://"
        }
    }
}
