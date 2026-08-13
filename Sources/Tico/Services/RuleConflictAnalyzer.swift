import Foundation

struct RuleConflictAnalyzer {
    func conflicts(
        for candidate: ShortcutRule,
        among rules: [ShortcutRule],
        profiles: [ShortcutProfile] = []
    ) -> [RuleConflict] {
        rules.compactMap { existing in
            guard existing.id != candidate.id,
                  existing.isEnabled,
                  candidate.isEnabled,
                  contextsOverlap(existing, candidate, profiles: profiles) else {
                return nil
            }

            if existing.trigger == candidate.trigger,
               contextsAreEquivalent(existing, candidate) {
                return RuleConflict(
                    existingRuleID: existing.id,
                    existingRuleName: existing.name,
                    kind: .identical,
                    severity: .replacementRequired,
                    message: "“\(existing.name)” já usa exatamente este gatilho no mesmo contexto."
                )
            }

            if isSequencePrefix(existing.trigger, candidate.trigger) {
                return RuleConflict(
                    existingRuleID: existing.id,
                    existingRuleName: existing.name,
                    kind: .sequencePrefix,
                    severity: .warning,
                    message: "“\(existing.name)” é prefixo desta sequência e pode aguardar o timeout."
                )
            }

            if triggersOverlap(existing.trigger, candidate.trigger),
               continuousActionCompetes(existing, candidate) {
                return RuleConflict(
                    existingRuleID: existing.id,
                    existingRuleName: existing.name,
                    kind: .continuousCompetesWithDiscrete,
                    severity: .warning,
                    message: "“\(existing.name)” disputa o mesmo gesto entre uma ação contínua e uma ação discreta."
                )
            }

            if triggersOverlap(existing.trigger, candidate.trigger) {
                let kind: RuleConflictKind = existing.scope.specificity == candidate.scope.specificity
                    ? .overlapping
                    : .globalShadowsApplication
                return RuleConflict(
                    existingRuleID: existing.id,
                    existingRuleName: existing.name,
                    kind: kind,
                    severity: .warning,
                    message: kind == .globalShadowsApplication
                        ? "Uma regra global e uma regra por app usam gestos sobrepostos; a regra específica terá prioridade."
                        : "“\(existing.name)” usa um gatilho que pode se sobrepor a este."
                )
            }

            return nil
        }
    }

    private func continuousActionCompetes(
        _ lhs: ShortcutRule,
        _ rhs: ShortcutRule
    ) -> Bool {
        let lhsIsContinuous = lhs.workflow.enabledSteps.contains {
            if case .continuousWindow = $0.action { return true }
            return false
        }
        let rhsIsContinuous = rhs.workflow.enabledSteps.contains {
            if case .continuousWindow = $0.action { return true }
            return false
        }
        return lhsIsContinuous != rhsIsContinuous
    }

    private func contextsAreEquivalent(
        _ lhs: ShortcutRule,
        _ rhs: ShortcutRule
    ) -> Bool {
        lhs.scope == rhs.scope
            && lhs.profileID == rhs.profileID
            && lhs.conditions == rhs.conditions
    }

    private func contextsOverlap(
        _ lhs: ShortcutRule,
        _ rhs: ShortcutRule,
        profiles: [ShortcutProfile]
    ) -> Bool {
        guard lhs.scope.overlaps(rhs.scope),
              conditionsOverlap(lhs.conditions, rhs.conditions) else {
            return false
        }
        guard let lhsID = lhs.profileID, let rhsID = rhs.profileID else {
            return true
        }
        guard let lhsProfile = profiles.first(where: { $0.id == lhsID }),
              let rhsProfile = profiles.first(where: { $0.id == rhsID }) else {
            return lhsID == rhsID
        }
        let appScopesOverlap = lhsProfile.applicationBundleIdentifiers.isEmpty
            || rhsProfile.applicationBundleIdentifiers.isEmpty
            || !lhsProfile.applicationBundleIdentifiers.isDisjoint(
                with: rhsProfile.applicationBundleIdentifiers
            )
        return appScopesOverlap
            && conditionsOverlap(lhsProfile.conditions, rhsProfile.conditions)
    }

    private func conditionsOverlap(
        _ lhs: [RuleCondition],
        _ rhs: [RuleCondition]
    ) -> Bool {
        for first in lhs {
            for second in rhs {
                switch (first, second) {
                case let (.application(lhsApps), .application(rhsApps))
                    where lhsApps.isDisjoint(with: rhsApps):
                    return false
                case let (.display(lhsDisplay), .display(rhsDisplay))
                    where lhsDisplay != rhsDisplay:
                    return false
                case let (.modifiers(lhsModifiers), .modifiers(rhsModifiers))
                    where lhsModifiers != rhsModifiers:
                    return false
                case let (.windowTitle(lhsMatcher), .windowTitle(rhsMatcher))
                    where lhsMatcher.mode == .exact
                        && rhsMatcher.mode == .exact
                        && lhsMatcher.value != rhsMatcher.value:
                    return false
                default:
                    continue
                }
            }
        }
        return true
    }

    private func isSequencePrefix(
        _ lhs: TriggerDefinition,
        _ rhs: TriggerDefinition
    ) -> Bool {
        switch (lhs, rhs) {
        case let (.sequence(first), .sequence(second)):
            first.isPrefix(of: second) || second.isPrefix(of: first)
        default:
            false
        }
    }

    private func triggersOverlap(
        _ lhs: TriggerDefinition,
        _ rhs: TriggerDefinition
    ) -> Bool {
        switch (lhs, rhs) {
        case let (.keyboard(lhsCode, lhsModifiers), .keyboard(rhsCode, rhsModifiers)):
            lhsCode == rhsCode && lhsModifiers == rhsModifiers
        case let (.mouseButton(lhsButton, lhsModifiers), .mouseButton(rhsButton, rhsModifiers)):
            lhsButton == rhsButton && lhsModifiers == rhsModifiers
        case let (.trackpad(lhsSpec), .trackpad(rhsSpec)):
            lhsSpec.gesture == rhsSpec.gesture
                && lhsSpec.fingerCount.overlaps(rhsSpec.fingerCount)
                && regionsOverlap(lhsSpec.startRegion, rhsSpec.startRegion)
                && (lhsSpec.requiredModifiers ?? []) == (rhsSpec.requiredModifiers ?? [])
        case let (.customTrackpad(lhsTemplate), .customTrackpad(rhsTemplate)):
            lhsTemplate.fingerCount.overlaps(rhsTemplate.fingerCount)
                && (
                    CustomGesturePath.matches(lhsTemplate.representativePath, template: rhsTemplate)
                    || CustomGesturePath.matches(rhsTemplate.representativePath, template: lhsTemplate)
                )
        case let (.sequence(lhsSequence), .sequence(rhsSequence)):
            lhsSequence.steps == rhsSequence.steps
        default:
            false
        }
    }

    private func regionsOverlap(_ lhs: TrackpadRegion, _ rhs: TrackpadRegion) -> Bool {
        lhs == .any || rhs == .any || lhs == rhs
    }
}

private extension ClosedRange where Bound == Int {
    func overlaps(_ other: Self) -> Bool {
        lowerBound <= other.upperBound && other.lowerBound <= upperBound
    }
}
