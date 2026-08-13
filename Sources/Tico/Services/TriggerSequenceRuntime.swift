import Foundation

struct TriggerRuntimeEvaluation {
    var matchedRules: [ShortcutRule]
    var nextDeadline: Date?
}

struct TriggerSequenceRuntime {
    private struct Progress {
        var stepIndex: Int
        var lastEventAt: Date
    }

    private struct PendingMatch {
        var ruleID: UUID
        var deadline: Date
        var context: ContextSnapshot
    }

    private var progressByRuleID: [UUID: Progress] = [:]
    private var pendingMatches: [UUID: PendingMatch] = [:]
    private let matcher = TriggerMatcher()

    mutating func process(
        event: InputEventDescriptor,
        rules: [ShortcutRule],
        context: ContextSnapshot,
        profiles: [ShortcutProfile] = []
    ) -> TriggerRuntimeEvaluation {
        var matched = flushExpired(rules: rules, at: event.timestamp, profiles: profiles)
        let eligibleRules = rules.filter {
            $0.matches(context, profiles: profiles)
        }

        let simpleMatches = matcher.matchingRules(
            in: eligibleRules.filter {
                if case .sequence = $0.trigger { return false }
                return true
            },
            for: event,
            context: context,
            profiles: profiles
        )
        for rule in simpleMatches {
            if let deadline = tapAmbiguityDeadline(
                for: rule,
                among: eligibleRules,
                event: event
            ) {
                pendingMatches[rule.id] = PendingMatch(
                    ruleID: rule.id,
                    deadline: deadline,
                    context: context
                )
                suppressPendingTapPrefixes(of: rule, rules: eligibleRules)
            } else {
                matched.append(rule)
                suppressPendingTapPrefixes(of: rule, rules: eligibleRules)
            }
        }

        for rule in eligibleRules {
            guard case let .sequence(sequence) = rule.trigger, sequence.isValid else {
                continue
            }
            let oldProgress = progressByRuleID[rule.id]
            let hasExpired = oldProgress.map {
                event.timestamp.timeIntervalSince($0.lastEventAt) > sequence.maximumInterval
            } ?? false
            var stepIndex = hasExpired ? 0 : (oldProgress?.stepIndex ?? 0)

            if matcher.matchesStep(sequence.steps[stepIndex], event: event) {
                stepIndex += 1
            } else if matcher.matchesStep(sequence.steps[0], event: event) {
                stepIndex = 1
            } else {
                if sequence.ambiguityPolicy == .cancelOnMismatch {
                    pendingMatches[rule.id] = nil
                }
                progressByRuleID[rule.id] = nil
                continue
            }

            if stepIndex < sequence.steps.count {
                progressByRuleID[rule.id] = Progress(
                    stepIndex: stepIndex,
                    lastEventAt: event.timestamp
                )
                continue
            }

            progressByRuleID[rule.id] = nil
            let longerSequences = eligibleRules.filter { other in
                guard case let .sequence(otherSequence) = other.trigger else { return false }
                return other.id != rule.id && sequence.isPrefix(of: otherSequence)
            }
            if !longerSequences.isEmpty, sequence.ambiguityPolicy == .waitForTimeout {
                pendingMatches[rule.id] = PendingMatch(
                    ruleID: rule.id,
                    deadline: event.timestamp.addingTimeInterval(sequence.maximumInterval),
                    context: context
                )
            } else {
                matched.append(rule)
                suppressPendingPrefixes(of: sequence, rules: eligibleRules)
            }
        }

        return TriggerRuntimeEvaluation(
            matchedRules: deduplicatedAndSorted(matched, profiles: profiles),
            nextDeadline: pendingMatches.values.map(\.deadline).min()
        )
    }

    mutating func flushExpired(
        rules: [ShortcutRule],
        at date: Date = Date(),
        profiles: [ShortcutProfile] = []
    ) -> [ShortcutRule] {
        let expired = pendingMatches.values.filter { $0.deadline <= date }
        for pending in expired {
            pendingMatches[pending.ruleID] = nil
        }
        return deduplicatedAndSorted(
            expired.compactMap { pending in
                rules.first {
                    $0.id == pending.ruleID
                        && $0.matches(pending.context, profiles: profiles)
                }
            },
            profiles: profiles
        )
    }

    mutating func reset() {
        progressByRuleID.removeAll()
        pendingMatches.removeAll()
    }

    private mutating func suppressPendingPrefixes(
        of completed: TriggerSequence,
        rules: [ShortcutRule]
    ) {
        let pendingIDs = pendingMatches.keys
        for id in pendingIDs {
            guard let rule = rules.first(where: { $0.id == id }),
                  case let .sequence(sequence) = rule.trigger,
                  sequence.isPrefix(of: completed) else {
                continue
            }
            pendingMatches[id] = nil
        }
    }

    private func tapAmbiguityDeadline(
        for rule: ShortcutRule,
        among rules: [ShortcutRule],
        event: InputEventDescriptor
    ) -> Date? {
        guard case let .trackpad(spec) = rule.trigger,
              spec.gesture == .tap,
              (event.advancedGesture?.tapCount ?? 1) == spec.tapCount else {
            return nil
        }
        let longerIntervals = rules.compactMap { other -> TimeInterval? in
            guard other.id != rule.id,
                  case let .trackpad(otherSpec) = other.trigger,
                  sameTapFamily(spec, otherSpec),
                  otherSpec.tapCount > spec.tapCount else {
                return nil
            }
            return otherSpec.effectiveMaximumTapInterval
        }
        guard let interval = longerIntervals.max() else { return nil }
        return event.timestamp.addingTimeInterval(interval)
    }

    private mutating func suppressPendingTapPrefixes(
        of completedRule: ShortcutRule,
        rules: [ShortcutRule]
    ) {
        guard case let .trackpad(completedSpec) = completedRule.trigger,
              completedSpec.gesture == .tap else {
            return
        }
        for id in pendingMatches.keys {
            guard let pendingRule = rules.first(where: { $0.id == id }),
                  case let .trackpad(pendingSpec) = pendingRule.trigger,
                  sameTapFamily(pendingSpec, completedSpec),
                  pendingSpec.tapCount < completedSpec.tapCount else {
                continue
            }
            pendingMatches[id] = nil
        }
    }

    private func sameTapFamily(
        _ lhs: TrackpadTriggerSpec,
        _ rhs: TrackpadTriggerSpec
    ) -> Bool {
        var lhs = lhs
        var rhs = rhs
        lhs.tapCount = 1
        rhs.tapCount = 1
        lhs.maximumTapInterval = nil
        rhs.maximumTapInterval = nil
        return lhs == rhs
    }

    private func deduplicatedAndSorted(
        _ rules: [ShortcutRule],
        profiles: [ShortcutProfile]
    ) -> [ShortcutRule] {
        var seen = Set<UUID>()
        let sorted = rules
            .filter { seen.insert($0.id).inserted }
            .sorted {
                let lhsSpecificity = $0.effectiveSpecificity(profiles: profiles)
                let rhsSpecificity = $1.effectiveSpecificity(profiles: profiles)
                if lhsSpecificity != rhsSpecificity {
                    return lhsSpecificity > rhsSpecificity
                }
                return $0.effectivePriority(profiles: profiles)
                    > $1.effectivePriority(profiles: profiles)
            }
        var accepted: [ShortcutRule] = []
        let conflictAnalyzer = RuleConflictAnalyzer()
        for rule in sorted {
            let isShadowed = accepted.contains {
                $0.effectiveSpecificity(profiles: profiles)
                    > rule.effectiveSpecificity(profiles: profiles)
                    && !conflictAnalyzer.conflicts(
                        for: rule,
                        among: [$0],
                        profiles: profiles
                    ).isEmpty
            }
            if !isShadowed {
                accepted.append(rule)
            }
        }
        return accepted
    }
}
