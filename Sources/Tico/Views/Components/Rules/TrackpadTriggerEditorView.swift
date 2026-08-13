import SwiftUI

struct TrackpadTriggerEditorView: View {
    @Binding var trigger: TriggerDefinition
    @Binding var advancedOptionsAreExpanded: Bool
    let captureMode: TrackpadCaptureMode
    let detectedTrackpads: [TrackpadHardwareInfo]
    let deviceCapabilities: [String: TrackpadDeviceCapability]

    var body: some View {
        Picker("Gesto", selection: trackpadGesture) {
            ForEach(TrackpadGesture.allCases, id: \.self) { gesture in
                Text(gesture.displayName).tag(gesture)
            }
        }
        HStack {
            Stepper(
                "Mínimo: \(trackpadMinimumFingerCount.wrappedValue)",
                value: trackpadMinimumFingerCount,
                in: 2...trackpadMaximumFingerCount.wrappedValue
            )
            Stepper(
                "Máximo: \(trackpadMaximumFingerCount.wrappedValue)",
                value: trackpadMaximumFingerCount,
                in: trackpadMinimumFingerCount.wrappedValue...5
            )
        }
        Picker("Região inicial", selection: trackpadRegion) {
            ForEach(TrackpadRegion.allCases, id: \.self) { region in
                Text(region.displayName).tag(region)
            }
        }
        if currentTrackpadSpec.gesture == .tap {
            Stepper(
                "Quantidade de toques: \(trackpadTapCount.wrappedValue)",
                value: trackpadTapCount,
                in: 1...3
            )
            if trackpadTapCount.wrappedValue > 1 {
                LabeledContent("Intervalo entre toques") {
                    HStack {
                        Slider(
                            value: trackpadMaximumTapInterval,
                            in: 0.15...1,
                            step: 0.05
                        )
                        .frame(width: 160)
                        Text(
                            trackpadMaximumTapInterval.wrappedValue,
                            format: .number.precision(.fractionLength(2))
                        )
                        .monospacedDigit()
                        Text("s")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        if currentTrackpadSpec.gesture.requiresRawContacts {
            Stepper(
                "Dedos âncora: \(trackpadAnchorFingerCount.wrappedValue)",
                value: trackpadAnchorFingerCount,
                in: 1...4
            )
        }
        if currentTrackpadSpec.gesture == .fingerChord {
            TextField("Ordem de entrada (ex.: 1,2,3)", text: trackpadEntryOrderText)
            TextField("Ordem de saída (ex.: 3,2,1)", text: trackpadExitOrderText)
        }
        VStack(alignment: .leading, spacing: 7) {
            Text("Modificadores mantidos durante o gesto")
                .font(.caption)
                .foregroundStyle(.secondary)
            trackpadModifierToggles
        }
        trackpadCapabilityNotice
        DisclosureGroup(
            "Ajustes avançados",
            isExpanded: $advancedOptionsAreExpanded
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Exigir região final", isOn: trackpadEndRegionIsEnabled)
                if trackpadEndRegionIsEnabled.wrappedValue {
                    Picker("Região final", selection: trackpadEndRegion) {
                        ForEach(TrackpadRegion.allCases.filter { $0 != .any }, id: \.self) { region in
                            Text(region.displayName).tag(region)
                        }
                    }
                }
                LabeledContent("Sensibilidade") {
                    HStack {
                        Slider(value: trackpadSensitivity, in: 0.25...2, step: 0.05)
                            .frame(width: 180)
                        Text(
                            trackpadSensitivity.wrappedValue,
                            format: .number.precision(.fractionLength(2))
                        )
                        .monospacedDigit()
                        .frame(width: 38, alignment: .trailing)
                    }
                }
                optionalThreshold(
                    title: "Velocidade mínima",
                    value: trackpadMinimumVelocity,
                    enabled: trackpadMinimumVelocityIsEnabled,
                    range: 0...4
                )
                optionalThreshold(
                    title: "Velocidade máxima",
                    value: trackpadMaximumVelocity,
                    enabled: trackpadMaximumVelocityIsEnabled,
                    range: 0...8
                )
                optionalThreshold(
                    title: "Pressão mínima",
                    value: trackpadPressureThreshold,
                    enabled: trackpadPressureThresholdIsEnabled,
                    range: 0...1
                )
                Toggle("Usar faixa de pressão", isOn: trackpadPressureRangeIsEnabled)
                if trackpadPressureRangeIsEnabled.wrappedValue {
                    HStack {
                        Text("De")
                        Slider(
                            value: trackpadPressureMinimum,
                            in: 0...trackpadPressureMaximum.wrappedValue,
                            step: 0.02
                        )
                        Text(
                            trackpadPressureMinimum.wrappedValue,
                            format: .number.precision(.fractionLength(2))
                        )
                        Text("até")
                        Slider(
                            value: trackpadPressureMaximum,
                            in: trackpadPressureMinimum.wrappedValue...1,
                            step: 0.02
                        )
                        Text(
                            trackpadPressureMaximum.wrappedValue,
                            format: .number.precision(.fractionLength(2))
                        )
                    }
                    .font(.caption)
                }
                Picker("Dispositivo", selection: trackpadDeviceSelection) {
                    Text("Qualquer trackpad").tag(Self.anyDeviceTag)
                    Text("Trackpad padrão").tag(Self.defaultDeviceTag)
                    Divider()
                    ForEach(detectedTrackpads) { trackpad in
                        Text(trackpad.name).tag(trackpad.id)
                    }
                }
                if case .device = currentTrackpadSpec.deviceScope {
                    Toggle(
                        "Usar o trackpad padrão se este dispositivo desaparecer",
                        isOn: trackpadAllowsDeviceFallback
                    )
                }
                pressureCapabilityNotice
            }
            .padding(.top, 8)
        }
        Text("Captura global avançada experimental. Gestos reservados pelo macOS podem continuar executando a ação do sistema.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private static let anyDeviceTag = "__any_device__"
    private static let defaultDeviceTag = "__default_device__"

    private var currentTrackpadSpec: TrackpadTriggerSpec {
        if case let .trackpad(spec) = trigger {
            return spec
        }
        return TrackpadTriggerSpec(gesture: .tap, fingerCount: 3)
    }

    private var trackpadGesture: Binding<TrackpadGesture> {
        Binding(
            get: { currentTrackpadSpec.gesture },
            set: { value in
                var spec = currentTrackpadSpec
                spec.gesture = value
                trigger = .trackpad(spec: spec)
            }
        )
    }

    private var trackpadMinimumFingerCount: Binding<Int> {
        Binding(
            get: { currentTrackpadSpec.fingerCount.lowerBound },
            set: { value in
                var spec = currentTrackpadSpec
                spec.fingerCount = value...max(value, spec.fingerCount.upperBound)
                trigger = .trackpad(spec: spec)
            }
        )
    }

    private var trackpadMaximumFingerCount: Binding<Int> {
        Binding(
            get: { currentTrackpadSpec.fingerCount.upperBound },
            set: { value in
                var spec = currentTrackpadSpec
                spec.fingerCount = min(value, spec.fingerCount.lowerBound)...value
                trigger = .trackpad(spec: spec)
            }
        )
    }

    private var trackpadRegion: Binding<TrackpadRegion> {
        Binding(
            get: { currentTrackpadSpec.startRegion },
            set: { value in
                var spec = currentTrackpadSpec
                spec.startRegion = value
                trigger = .trackpad(spec: spec)
            }
        )
    }

    private var trackpadSensitivity: Binding<Double> {
        Binding(
            get: { currentTrackpadSpec.sensitivity },
            set: { value in
                var spec = currentTrackpadSpec
                spec.sensitivity = value
                trigger = .trackpad(spec: spec)
            }
        )
    }

    private var trackpadTapCount: Binding<Int> {
        Binding(
            get: { currentTrackpadSpec.tapCount },
            set: { value in
                var spec = currentTrackpadSpec
                spec.tapCount = value
                trigger = .trackpad(spec: spec)
            }
        )
    }

    private var trackpadMaximumTapInterval: Binding<Double> {
        Binding(
            get: { currentTrackpadSpec.effectiveMaximumTapInterval },
            set: { value in
                var spec = currentTrackpadSpec
                spec.maximumTapInterval = value
                trigger = .trackpad(spec: spec)
            }
        )
    }

    private var trackpadAnchorFingerCount: Binding<Int> {
        Binding(
            get: { currentTrackpadSpec.anchorFingerCount ?? 2 },
            set: { value in
                var spec = currentTrackpadSpec
                spec.anchorFingerCount = value
                trigger = .trackpad(spec: spec)
            }
        )
    }

    private var trackpadEntryOrderText: Binding<String> {
        chordOrderBinding(keyPath: \.entryOrder)
    }

    private var trackpadExitOrderText: Binding<String> {
        chordOrderBinding(keyPath: \.exitOrder)
    }

    private var trackpadEndRegionIsEnabled: Binding<Bool> {
        Binding(
            get: { currentTrackpadSpec.endRegion != nil },
            set: { isEnabled in
                var spec = currentTrackpadSpec
                spec.endRegion = isEnabled ? (spec.endRegion ?? .topRight) : nil
                trigger = .trackpad(spec: spec)
            }
        )
    }

    private var trackpadEndRegion: Binding<TrackpadRegion> {
        Binding(
            get: { currentTrackpadSpec.endRegion ?? .topRight },
            set: { region in
                var spec = currentTrackpadSpec
                spec.endRegion = region
                trigger = .trackpad(spec: spec)
            }
        )
    }

    private var trackpadMinimumVelocityIsEnabled: Binding<Bool> {
        optionalTrackpadValueIsEnabled(keyPath: \.minimumVelocity, defaultValue: 0.1)
    }

    private var trackpadMinimumVelocity: Binding<Double> {
        optionalTrackpadValue(keyPath: \.minimumVelocity, defaultValue: 0.1)
    }

    private var trackpadMaximumVelocityIsEnabled: Binding<Bool> {
        optionalTrackpadValueIsEnabled(keyPath: \.maximumVelocity, defaultValue: 2)
    }

    private var trackpadMaximumVelocity: Binding<Double> {
        optionalTrackpadValue(keyPath: \.maximumVelocity, defaultValue: 2)
    }

    private var trackpadPressureThresholdIsEnabled: Binding<Bool> {
        optionalTrackpadValueIsEnabled(keyPath: \.pressureThreshold, defaultValue: 0.25)
    }

    private var trackpadPressureThreshold: Binding<Double> {
        optionalTrackpadValue(keyPath: \.pressureThreshold, defaultValue: 0.25)
    }

    private var trackpadPressureRangeIsEnabled: Binding<Bool> {
        Binding(
            get: { currentTrackpadSpec.pressureRange != nil },
            set: { enabled in
                var spec = currentTrackpadSpec
                spec.pressureRange = enabled ? (spec.pressureRange ?? 0.15...0.75) : nil
                trigger = .trackpad(spec: spec)
            }
        )
    }

    private var trackpadPressureMinimum: Binding<Double> {
        Binding(
            get: { currentTrackpadSpec.pressureRange?.lowerBound ?? 0.15 },
            set: { value in
                var spec = currentTrackpadSpec
                spec.pressureRange = value...max(
                    value,
                    spec.pressureRange?.upperBound ?? 0.75
                )
                trigger = .trackpad(spec: spec)
            }
        )
    }

    private var trackpadPressureMaximum: Binding<Double> {
        Binding(
            get: { currentTrackpadSpec.pressureRange?.upperBound ?? 0.75 },
            set: { value in
                var spec = currentTrackpadSpec
                spec.pressureRange = min(
                    value,
                    spec.pressureRange?.lowerBound ?? 0.15
                )...value
                trigger = .trackpad(spec: spec)
            }
        )
    }

    private var trackpadDeviceSelection: Binding<String> {
        Binding(
            get: {
                switch currentTrackpadSpec.deviceScope {
                case .any: Self.anyDeviceTag
                case .defaultDevice: Self.defaultDeviceTag
                case let .device(id): id
                }
            },
            set: { value in
                var spec = currentTrackpadSpec
                if value == Self.anyDeviceTag {
                    spec.deviceScope = .any
                } else if value == Self.defaultDeviceTag {
                    spec.deviceScope = .defaultDevice
                } else {
                    spec.deviceScope = .device(id: value)
                }
                trigger = .trackpad(spec: spec)
            }
        )
    }

    private var trackpadAllowsDeviceFallback: Binding<Bool> {
        Binding(
            get: { currentTrackpadSpec.allowsDeviceFallback },
            set: { value in
                var spec = currentTrackpadSpec
                spec.allowsDeviceFallback = value
                trigger = .trackpad(spec: spec)
            }
        )
    }

    private var trackpadModifierToggles: some View {
        HStack {
            ForEach(InputModifier.allCases, id: \.self) { modifier in
                Toggle(modifier.symbol, isOn: Binding(
                    get: { currentTrackpadSpec.requiredModifiers?.contains(modifier) ?? false },
                    set: { enabled in
                        var spec = currentTrackpadSpec
                        var modifiers = spec.requiredModifiers ?? []
                        if enabled {
                            modifiers.insert(modifier)
                        } else {
                            modifiers.remove(modifier)
                        }
                        spec.requiredModifiers = modifiers.isEmpty ? nil : modifiers
                        trigger = .trackpad(spec: spec)
                    }
                ))
                .toggleStyle(.button)
                .help(modifier.displayName)
            }
        }
    }

    @ViewBuilder
    private var trackpadCapabilityNotice: some View {
        switch captureMode.availability(for: currentTrackpadSpec.gesture) {
        case .available:
            EmptyView()
        case let .degraded(message):
            Label(message, systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        case let .unavailable(message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private var pressureCapabilityNotice: some View {
        let capability: TrackpadDeviceCapability? = {
            switch currentTrackpadSpec.deviceScope {
            case .any, .defaultDevice:
                return deviceCapabilities["default"]
            case let .device(id):
                return deviceCapabilities[id]
            }
        }()
        if let capability, capability.hasReliablePressure {
            Label(
                "Pressão observada: \(capability.minimumObservedPressure ?? 0, format: .number.precision(.fractionLength(2)))–\(capability.maximumObservedPressure ?? 0, format: .number.precision(.fractionLength(2)))",
                systemImage: "checkmark.circle.fill"
            )
            .font(.caption)
            .foregroundStyle(.green)
        } else if currentTrackpadSpec.pressureThreshold != nil
                    || currentTrackpadSpec.pressureRange != nil {
            Label(
                "Ainda não há amostras suficientes para confirmar pressão confiável neste dispositivo.",
                systemImage: "exclamationmark.triangle"
            )
            .font(.caption)
            .foregroundStyle(.orange)
        }
    }

    private func optionalThreshold(
        title: String,
        value: Binding<Double>,
        enabled: Binding<Bool>,
        range: ClosedRange<Double>
    ) -> some View {
        HStack {
            Toggle(title, isOn: enabled)
                .frame(width: 170, alignment: .leading)
            Slider(value: value, in: range, step: 0.05)
                .disabled(!enabled.wrappedValue)
            Text(value.wrappedValue, format: .number.precision(.fractionLength(2)))
                .monospacedDigit()
                .frame(width: 40, alignment: .trailing)
                .foregroundStyle(enabled.wrappedValue ? .primary : .secondary)
        }
    }

    private func chordOrderBinding(
        keyPath: WritableKeyPath<TrackpadTriggerSpec, [Int]?>
    ) -> Binding<String> {
        Binding(
            get: {
                (currentTrackpadSpec[keyPath: keyPath] ?? [])
                    .map(String.init)
                    .joined(separator: ",")
            },
            set: { text in
                var spec = currentTrackpadSpec
                let values = text
                    .split(separator: ",")
                    .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
                    .filter { (1...5).contains($0) }
                spec[keyPath: keyPath] = values.isEmpty ? nil : values
                trigger = .trackpad(spec: spec)
            }
        )
    }

    private func optionalTrackpadValue(
        keyPath: WritableKeyPath<TrackpadTriggerSpec, Double?>,
        defaultValue: Double
    ) -> Binding<Double> {
        Binding(
            get: { currentTrackpadSpec[keyPath: keyPath] ?? defaultValue },
            set: { value in
                var spec = currentTrackpadSpec
                spec[keyPath: keyPath] = value
                trigger = .trackpad(spec: spec)
            }
        )
    }

    private func optionalTrackpadValueIsEnabled(
        keyPath: WritableKeyPath<TrackpadTriggerSpec, Double?>,
        defaultValue: Double
    ) -> Binding<Bool> {
        Binding(
            get: { currentTrackpadSpec[keyPath: keyPath] != nil },
            set: { enabled in
                var spec = currentTrackpadSpec
                spec[keyPath: keyPath] = enabled
                    ? (spec[keyPath: keyPath] ?? defaultValue)
                    : nil
                trigger = .trackpad(spec: spec)
            }
        )
    }
}
