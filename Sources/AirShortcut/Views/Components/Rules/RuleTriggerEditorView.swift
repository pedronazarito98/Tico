import SwiftUI

struct RuleTriggerEditorView: View {
    @Binding var trigger: TriggerDefinition
    @Binding var advancedTrackpadOptionsAreExpanded: Bool
    let captureMode: TrackpadCaptureMode
    let detectedTrackpads: [TrackpadHardwareInfo]
    let deviceCapabilities: [String: TrackpadDeviceCapability]

    var body: some View {
        Picker("Tipo de gatilho", selection: triggerKind) {
            ForEach(EditorTriggerKind.allCases) { kind in
                Label(kind.title, systemImage: kind.systemImage).tag(kind)
            }
        }

        triggerFields
    }

    @ViewBuilder
    private var triggerFields: some View {
        switch trigger {
        case .keyboard:
            Stepper(
                "Código da tecla: \(keyboardKeyCode.wrappedValue)",
                value: keyboardKeyCode,
                in: 0...255
            )
            modifierToggles
        case .mouseButton:
            Stepper(
                "Número do botão: \(mouseButton.wrappedValue)",
                value: mouseButton,
                in: 0...31
            )
            modifierToggles
        case .trackpad:
            TrackpadTriggerEditorView(
                trigger: $trigger,
                advancedOptionsAreExpanded: $advancedTrackpadOptionsAreExpanded,
                captureMode: captureMode,
                detectedTrackpads: detectedTrackpads,
                deviceCapabilities: deviceCapabilities
            )
        case let .customTrackpad(template):
            HStack(alignment: .top, spacing: 16) {
                GesturePathPreview(path: template.representativePath)
                    .frame(width: 180, height: 130)
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Nome do gesto", text: customGestureName)
                    LabeledContent("Dedos") {
                        Text(template.fingerCount.displayText)
                    }
                    LabeledContent("Amostras") {
                        Text("\(template.samplePaths.count)")
                    }
                    LabeledContent("Tolerância") {
                        HStack {
                            Slider(value: customGestureTolerance, in: 0.05...0.5, step: 0.01)
                                .frame(width: 150)
                            Text(
                                customGestureTolerance.wrappedValue,
                                format: .number.precision(.fractionLength(2))
                            )
                            .monospacedDigit()
                        }
                    }
                }
            }
            Text("A trajetória é comparada localmente; posição e tamanho são normalizados, mas a direção é preservada.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case let .sequence(sequence):
            SequenceEditorView(
                sequence: Binding(
                    get: { sequence },
                    set: { trigger = .sequence($0) }
                )
            )
        }
    }

    private var triggerKind: Binding<EditorTriggerKind> {
        Binding(
            get: {
                switch trigger {
                case .keyboard: .keyboard
                case .mouseButton: .mouseButton
                case .trackpad: .trackpad
                case .customTrackpad: .customTrackpad
                case .sequence: .sequence
                }
            },
            set: { kind in
                switch kind {
                case .keyboard:
                    trigger = .keyboard(keyCode: 49, modifiers: [.command])
                case .mouseButton:
                    trigger = .mouseButton(button: 3, modifiers: [])
                case .trackpad:
                    trigger = .trackpad(gesture: .tap, fingerCount: 3, region: .any)
                case .customTrackpad:
                    trigger = .customTrackpad(
                        template: CustomGestureTemplate(
                            name: "Meu gesto",
                            fingerCount: 3...3,
                            samplePaths: []
                        )
                    )
                case .sequence:
                    trigger = .sequence(
                        TriggerSequence(steps: [
                            .trackpad(spec: TrackpadTriggerSpec(gesture: .swipeUp, fingerCount: 3)),
                            .trackpad(spec: TrackpadTriggerSpec(gesture: .swipeRight, fingerCount: 3))
                        ])
                    )
                }
            }
        )
    }

    private var keyboardKeyCode: Binding<UInt16> {
        Binding(
            get: {
                if case let .keyboard(keyCode, _) = trigger { return keyCode }
                return 0
            },
            set: { newValue in
                trigger = .keyboard(keyCode: newValue, modifiers: currentModifiers)
            }
        )
    }

    private var mouseButton: Binding<Int> {
        Binding(
            get: {
                if case let .mouseButton(button, _) = trigger { return button }
                return 0
            },
            set: { newValue in
                trigger = .mouseButton(button: newValue, modifiers: currentModifiers)
            }
        )
    }

    private var customGestureName: Binding<String> {
        Binding(
            get: {
                if case let .customTrackpad(template) = trigger {
                    return template.name
                }
                return ""
            },
            set: { value in
                guard case var .customTrackpad(template) = trigger else { return }
                template.name = value
                trigger = .customTrackpad(template: template)
            }
        )
    }

    private var customGestureTolerance: Binding<Double> {
        Binding(
            get: {
                if case let .customTrackpad(template) = trigger {
                    return template.tolerance
                }
                return 0.2
            },
            set: { value in
                guard case var .customTrackpad(template) = trigger else { return }
                template.tolerance = min(max(value, 0.05), 0.5)
                trigger = .customTrackpad(template: template)
            }
        )
    }

    private var currentModifiers: Set<InputModifier> {
        switch trigger {
        case let .keyboard(_, modifiers), let .mouseButton(_, modifiers): modifiers
        case .trackpad, .customTrackpad, .sequence: []
        }
    }

    private var modifierToggles: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Modificadores")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                ForEach(InputModifier.allCases, id: \.self) { modifier in
                    Toggle(modifier.symbol, isOn: modifierBinding(modifier))
                        .toggleStyle(.button)
                        .help(modifier.displayName)
                }
            }
        }
    }

    private func modifierBinding(_ modifier: InputModifier) -> Binding<Bool> {
        Binding(
            get: { currentModifiers.contains(modifier) },
            set: { isEnabled in
                var modifiers = currentModifiers
                if isEnabled {
                    modifiers.insert(modifier)
                } else {
                    modifiers.remove(modifier)
                }
                switch trigger {
                case let .keyboard(keyCode, _):
                    trigger = .keyboard(keyCode: keyCode, modifiers: modifiers)
                case let .mouseButton(button, _):
                    trigger = .mouseButton(button: button, modifiers: modifiers)
                case .trackpad, .customTrackpad, .sequence:
                    break
                }
            }
        )
    }
}

private enum EditorTriggerKind: String, CaseIterable, Identifiable {
    case keyboard
    case mouseButton
    case trackpad
    case customTrackpad
    case sequence

    var id: Self { self }

    var title: String {
        switch self {
        case .keyboard: "Teclado"
        case .mouseButton: "Mouse"
        case .trackpad: "Trackpad"
        case .customTrackpad: "Personalizado"
        case .sequence: "Sequência"
        }
    }

    var systemImage: String {
        switch self {
        case .keyboard: "keyboard"
        case .mouseButton: "computermouse"
        case .trackpad: "rectangle.and.hand.point.up.left"
        case .customTrackpad: "scribble.variable"
        case .sequence: "point.3.connected.trianglepath.dotted"
        }
    }
}
