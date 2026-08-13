import Foundation

enum DocumentSecurityPolicy {
    static let maximumDocumentBytes = 8 * 1_024 * 1_024
    static let maximumRules = 1_000
    static let maximumProfiles = 200
    static let maximumReusableWorkflows = 200
    static let maximumCustomTemplates = 200
    static let maximumPresets = 500
    static let maximumStringLength = 65_536
    static let maximumTemplatePoints = 256

    static func readBoundedData(from url: URL) throws -> Data {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey])
        guard values.isRegularFile != false,
              url.isFileURL else {
            throw ShortcutStoreError.invalidDocument
        }
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maximumDocumentBytes + 1) ?? Data()
        guard data.count <= maximumDocumentBytes,
              try (handle.read(upToCount: 1) ?? Data()).isEmpty else {
            throw ShortcutStoreError.invalidDocument
        }
        return data
    }

    static func validate(
        rules: [ShortcutRule],
        profiles: [ShortcutProfile],
        reusableWorkflows: [ActionWorkflow],
        customTemplates: [CustomGestureTemplate],
        presets: [GesturePreset]
    ) throws {
        guard rules.count <= maximumRules,
              profiles.count <= maximumProfiles,
              reusableWorkflows.count <= maximumReusableWorkflows,
              customTemplates.count <= maximumCustomTemplates,
              presets.count <= maximumPresets else {
            throw ShortcutStoreError.invalidDocument
        }

        try rules.forEach(validate)
        try profiles.forEach(validate)
        try reusableWorkflows.forEach(validate)
        try customTemplates.forEach(validate)
        for preset in presets {
            try validateString(preset.name)
            try validateString(preset.summary)
            try validate(preset.trigger)
            try validate(preset.workflow)
        }
    }

    static func validate(_ rule: ShortcutRule) throws {
        guard (-10...10).contains(rule.priority),
              rule.conditions.count <= 100 else {
            throw ShortcutStoreError.invalidDocument
        }
        try validateString(rule.name)
        try validateString(rule.notes)
        try validate(rule.trigger)
        try validate(rule.workflow)
    }

    static func validate(_ profile: ShortcutProfile) throws {
        guard (-10...10).contains(profile.priority),
              profile.applicationBundleIdentifiers.count <= 100,
              profile.conditions.count <= 100 else {
            throw ShortcutStoreError.invalidDocument
        }
        try validateString(profile.name)
        try profile.applicationBundleIdentifiers.forEach(validateString)
    }

    static func validate(_ workflow: ActionWorkflow) throws {
        guard (1...20).contains(workflow.steps.count),
              workflow.timeout.isFinite,
              (1...600).contains(workflow.timeout) else {
            throw ShortcutStoreError.invalidDocument
        }
        try validateString(workflow.name)
        for step in workflow.steps {
            guard step.delayBefore.isFinite,
                  (0...300).contains(step.delayBefore) else {
                throw ShortcutStoreError.invalidDocument
            }
            if let timeout = step.timeout {
                guard timeout.isFinite, (0.25...300).contains(timeout) else {
                    throw ShortcutStoreError.invalidDocument
                }
            }
            try validateString(step.name)
            try validate(step.action)
        }
    }

    static func validate(_ trigger: TriggerDefinition) throws {
        switch trigger {
        case .keyboard:
            return
        case let .mouseButton(button, _):
            guard (0...31).contains(button) else {
                throw ShortcutStoreError.invalidDocument
            }
        case let .trackpad(spec):
            try validate(spec)
        case let .customTrackpad(template):
            try validate(template)
        case let .sequence(sequence):
            guard (2...5).contains(sequence.steps.count),
                  sequence.maximumInterval.isFinite,
                  (0.15...5).contains(sequence.maximumInterval) else {
                throw ShortcutStoreError.invalidDocument
            }
            for step in sequence.steps {
                try validate(step.triggerDefinition)
            }
        }
    }

    static func validate(_ spec: TrackpadTriggerSpec) throws {
        guard spec.fingerCount.lowerBound >= 1,
              spec.fingerCount.upperBound <= 5,
              (1...3).contains(spec.tapCount),
              spec.sensitivity.isFinite,
              (0.25...2).contains(spec.sensitivity) else {
            throw ShortcutStoreError.invalidDocument
        }
        try validateFinite(spec.maximumTapInterval, range: 0.15...1)
        try validateFinite(spec.minimumVelocity, range: 0...100)
        try validateFinite(spec.maximumVelocity, range: 0...100)
        try validateFinite(spec.pressureThreshold, range: 0...1)
        if let pressureRange = spec.pressureRange {
            guard pressureRange.lowerBound.isFinite,
                  pressureRange.upperBound.isFinite,
                  pressureRange.lowerBound >= 0,
                  pressureRange.upperBound <= 1 else {
                throw ShortcutStoreError.invalidDocument
            }
        }
        guard (spec.entryOrder?.count ?? 0) <= 5,
              (spec.exitOrder?.count ?? 0) <= 5 else {
            throw ShortcutStoreError.invalidDocument
        }
    }

    static func validate(_ template: CustomGestureTemplate) throws {
        guard template.fingerCount.lowerBound >= 1,
              template.fingerCount.upperBound <= 5,
              (CustomGestureTemplate.minimumSampleCount...CustomGestureTemplate.maximumSampleCount)
                .contains(template.samplePaths.count),
              template.tolerance.isFinite,
              (0.05...0.5).contains(template.tolerance) else {
            throw ShortcutStoreError.invalidDocument
        }
        try validateString(template.name)
        for path in template.samplePaths {
            guard (2...maximumTemplatePoints).contains(path.count),
                  path.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else {
                throw ShortcutStoreError.invalidDocument
            }
        }
    }

    static func validate(_ action: ShortcutAction) throws {
        switch action {
        case let .openApplication(bundleIdentifier):
            try validateString(bundleIdentifier)
        case let .openURL(url):
            guard let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https" else {
                throw ShortcutStoreError.invalidDocument
            }
            try validateString(url.absoluteString)
        case let .notification(title, body):
            try validateString(title)
            try validateString(body)
        case let .shellScript(command):
            try validateString(command)
        case let .appleScript(source):
            try validateString(source)
        case let .macOSShortcut(name, input):
            try validateString(name)
            if let input { try validateString(input) }
        case .keyboardShortcut:
            return
        case let .setClipboard(text):
            try validateString(text)
        case let .application(target, _),
             let .window(target, _),
             let .continuousWindow(target, _, _):
            if case let .bundleIdentifier(identifier) = target {
                try validateString(identifier)
            }
        }
    }

    private static func validateFinite(
        _ value: Double?,
        range: ClosedRange<Double>
    ) throws {
        guard let value else { return }
        guard value.isFinite, range.contains(value) else {
            throw ShortcutStoreError.invalidDocument
        }
    }

    private static func validateString(_ value: String) throws {
        guard value.utf8.count <= maximumStringLength else {
            throw ShortcutStoreError.invalidDocument
        }
    }
}
