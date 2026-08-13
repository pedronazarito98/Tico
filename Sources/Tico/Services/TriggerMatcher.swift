import Foundation

struct TriggerMatcher {
    func matchingRules(
        in rules: [ShortcutRule],
        for event: InputEventDescriptor
    ) -> [ShortcutRule] {
        rules.filter { $0.isEnabled && matches($0.trigger, event: event) }
    }

    func matchingRules(
        in rules: [ShortcutRule],
        for event: InputEventDescriptor,
        context: ContextSnapshot,
        profiles: [ShortcutProfile] = []
    ) -> [ShortcutRule] {
        rules
            .filter {
                $0.matches(context, profiles: profiles)
                    && matches($0.trigger, event: event)
            }
            .sorted {
                let lhsSpecificity = $0.effectiveSpecificity(profiles: profiles)
                let rhsSpecificity = $1.effectiveSpecificity(profiles: profiles)
                if lhsSpecificity != rhsSpecificity {
                    return lhsSpecificity > rhsSpecificity
                }
                return $0.effectivePriority(profiles: profiles)
                    > $1.effectivePriority(profiles: profiles)
            }
    }

    func matches(_ trigger: TriggerDefinition, event: InputEventDescriptor) -> Bool {
        switch trigger {
        case let .keyboard(keyCode, modifiers):
            return event.kind == .keyboard
                && event.keyCode == keyCode
                && event.modifiers == modifiers

        case let .mouseButton(button, modifiers):
            return event.kind == .mouseButton
                && event.mouseButton == button
                && event.modifiers == modifiers

        case let .trackpad(spec):
            guard event.kind == .trackpadGesture,
                  event.gesture == spec.gesture,
                  let fingerCount = event.fingerCount,
                  spec.fingerCount.contains(fingerCount),
                  regionMatches(
                    spec.startRegion,
                    point: event.gestureEvent?.startPosition,
                    fallback: event.trackpadRegion
                  ) else {
                return false
            }
            if event.advancedGesture?.tapCount ?? 1 != spec.tapCount {
                return false
            }
            if spec.tapCount > 1,
               (event.advancedGesture?.tapInterval ?? .greatestFiniteMagnitude)
                    > spec.effectiveMaximumTapInterval {
                return false
            }
            if let anchorFingerCount = spec.anchorFingerCount,
               event.advancedGesture?.anchorFingerCount != anchorFingerCount {
                return false
            }
            if let entryOrder = spec.entryOrder,
               event.advancedGesture?.entryOrder != entryOrder {
                return false
            }
            if let exitOrder = spec.exitOrder,
               event.advancedGesture?.exitOrder != exitOrder {
                return false
            }
            if let requiredModifiers = spec.requiredModifiers,
               event.modifiers != requiredModifiers {
                return false
            }
            if let endRegion = spec.endRegion,
               endRegion != .any,
               !regionMatches(
                    endRegion,
                    point: event.gestureEvent?.endPosition,
                    fallback: event.gestureEvent?.endRegion
               ) {
                return false
            }
            if let minimumVelocity = spec.minimumVelocity,
               (event.gestureEvent?.velocity ?? 0) < minimumVelocity {
                return false
            }
            if let maximumVelocity = spec.maximumVelocity,
               (event.gestureEvent?.velocity ?? .greatestFiniteMagnitude) > maximumVelocity {
                return false
            }
            if let pressureThreshold = spec.pressureThreshold,
               (event.gestureEvent?.pressure ?? 0) < pressureThreshold {
                return false
            }
            if let pressureRange = spec.pressureRange,
               !pressureRange.contains(event.gestureEvent?.pressure ?? -1) {
                return false
            }
            switch spec.deviceScope {
            case .any:
                return true
            case .defaultDevice:
                return event.gestureEvent?.deviceID == nil
            case let .device(id):
                return event.gestureEvent?.deviceID == id
                    || (spec.allowsDeviceFallback && event.gestureEvent?.deviceID == nil)
            }

        case let .customTrackpad(template):
            guard event.kind == .trackpadGesture,
                  let fingerCount = event.fingerCount,
                  template.fingerCount.contains(fingerCount) else {
                return false
            }
            return CustomGesturePath.matches(event.trackpadPath, template: template)

        case .sequence:
            return false
        }
    }

    func matchesStep(_ step: TriggerStep, event: InputEventDescriptor) -> Bool {
        matches(step.triggerDefinition, event: event)
    }

    private func regionMatches(
        _ region: TrackpadRegion,
        point: TrackpadPoint?,
        fallback: TrackpadRegion?
    ) -> Bool {
        if region == .any { return true }
        if let point { return region.contains(point) }
        return fallback == region
    }
}
