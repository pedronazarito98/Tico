import SwiftUI

struct SequenceEditorView: View {
    @Binding var sequence: TriggerSequence

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(sequence.steps.indices), id: \.self) { index in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption.bold())
                        .frame(width: 24, height: 24)
                        .background(.tint.opacity(0.14), in: Circle())

                    VStack(alignment: .leading, spacing: 9) {
                        Picker("Entrada", selection: stepKind(at: index)) {
                            ForEach(SequenceStepKind.allCases) { kind in
                                Label(kind.title, systemImage: kind.systemImage).tag(kind)
                            }
                        }
                        .labelsHidden()
                        stepFields(at: index)
                    }

                    VStack(spacing: 4) {
                        Button {
                            moveStep(at: index, offset: -1)
                        } label: {
                            Image(systemName: "chevron.up")
                        }
                        .disabled(index == 0)
                        Button {
                            moveStep(at: index, offset: 1)
                        } label: {
                            Image(systemName: "chevron.down")
                        }
                        .disabled(index == sequence.steps.count - 1)
                        Button(role: .destructive) {
                            sequence.steps.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .disabled(sequence.steps.count <= 2)
                    }
                    .buttonStyle(.borderless)
                }
                .padding(12)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
            }

            HStack {
                Button {
                    sequence.steps.append(.trackpad(spec: TrackpadTriggerSpec(
                        gesture: .tap,
                        fingerCount: 3
                    )))
                } label: {
                    Label("Adicionar etapa", systemImage: "plus")
                }
                .disabled(sequence.steps.count >= 5)
                Spacer()
                Text("\(sequence.steps.count) de 5 etapas")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()
            LabeledContent("Intervalo máximo") {
                HStack {
                    Slider(value: maximumInterval, in: 0.15...3, step: 0.05)
                        .frame(width: 160)
                    Text(sequence.maximumInterval, format: .number.precision(.fractionLength(2)))
                        .monospacedDigit()
                        .frame(width: 44)
                    Text("s")
                        .foregroundStyle(.secondary)
                }
            }
            Picker("Prefixos ambíguos", selection: $sequence.ambiguityPolicy) {
                Text("Aguardar próximo passo").tag(SequenceAmbiguityPolicy.waitForTimeout)
                Text("Executar imediatamente").tag(SequenceAmbiguityPolicy.acceptImmediately)
                Text("Cancelar se divergir").tag(SequenceAmbiguityPolicy.cancelOnMismatch)
            }
        }
    }

    @ViewBuilder
    private func stepFields(at index: Int) -> some View {
        switch sequence.steps[index] {
        case let .keyboard(keyCode, modifiers):
            Stepper(
                "Código da tecla: \(keyCode)",
                value: Binding(
                    get: { keyCode },
                    set: { sequence.steps[index] = .keyboard(keyCode: $0, modifiers: modifiers) }
                ),
                in: 0...255
            )
            modifierButtons(
                modifiers: modifiers,
                onChange: { sequence.steps[index] = .keyboard(keyCode: keyCode, modifiers: $0) }
            )
        case let .mouseButton(button, modifiers):
            Stepper(
                "Botão: \(button)",
                value: Binding(
                    get: { button },
                    set: { sequence.steps[index] = .mouseButton(button: $0, modifiers: modifiers) }
                ),
                in: 0...31
            )
            modifierButtons(
                modifiers: modifiers,
                onChange: { sequence.steps[index] = .mouseButton(button: button, modifiers: $0) }
            )
        case let .trackpad(spec):
            Picker(
                "Gesto",
                selection: Binding(
                    get: { spec.gesture },
                    set: {
                        var value = spec
                        value.gesture = $0
                        sequence.steps[index] = .trackpad(spec: value)
                    }
                )
            ) {
                ForEach(TrackpadGesture.allCases, id: \.self) {
                    Text($0.displayName).tag($0)
                }
            }
            Stepper(
                "Dedos: \(spec.fingerCount.lowerBound)",
                value: Binding(
                    get: { spec.fingerCount.lowerBound },
                    set: {
                        var value = spec
                        value.fingerCount = $0...$0
                        sequence.steps[index] = .trackpad(spec: value)
                    }
                ),
                in: 2...5
            )
            modifierButtons(
                modifiers: spec.requiredModifiers ?? [],
                onChange: {
                    var value = spec
                    value.requiredModifiers = $0.isEmpty ? nil : $0
                    sequence.steps[index] = .trackpad(spec: value)
                }
            )
        case .customTrackpad:
            Text("Use o gravador de gestos para trocar esta amostra personalizada.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func modifierButtons(
        modifiers: Set<InputModifier>,
        onChange: @escaping (Set<InputModifier>) -> Void
    ) -> some View {
        HStack {
            ForEach(InputModifier.allCases, id: \.self) { modifier in
                Toggle(
                    modifier.symbol,
                    isOn: Binding(
                        get: { modifiers.contains(modifier) },
                        set: { enabled in
                            var value = modifiers
                            if enabled {
                                value.insert(modifier)
                            } else {
                                value.remove(modifier)
                            }
                            onChange(value)
                        }
                    )
                )
                .toggleStyle(.button)
                .help(modifier.displayName)
            }
        }
    }

    private func stepKind(at index: Int) -> Binding<SequenceStepKind> {
        Binding(
            get: { SequenceStepKind(sequence.steps[index]) },
            set: { kind in sequence.steps[index] = kind.defaultStep }
        )
    }

    private var maximumInterval: Binding<Double> {
        Binding(
            get: { sequence.maximumInterval },
            set: { sequence.maximumInterval = $0 }
        )
    }

    private func moveStep(at index: Int, offset: Int) {
        let destination = index + offset
        guard sequence.steps.indices.contains(destination) else { return }
        sequence.steps.swapAt(index, destination)
    }
}

private enum SequenceStepKind: String, CaseIterable, Identifiable {
    case keyboard
    case mouse
    case trackpad

    init(_ step: TriggerStep) {
        switch step {
        case .keyboard: self = .keyboard
        case .mouseButton: self = .mouse
        case .trackpad, .customTrackpad: self = .trackpad
        }
    }

    var id: Self { self }

    var title: String {
        switch self {
        case .keyboard: "Teclado"
        case .mouse: "Mouse"
        case .trackpad: "Trackpad"
        }
    }

    var systemImage: String {
        switch self {
        case .keyboard: "keyboard"
        case .mouse: "computermouse"
        case .trackpad: "rectangle.and.hand.point.up.left"
        }
    }

    var defaultStep: TriggerStep {
        switch self {
        case .keyboard:
            .keyboard(keyCode: 49, modifiers: [.command])
        case .mouse:
            .mouseButton(button: 3, modifiers: [])
        case .trackpad:
            .trackpad(spec: TrackpadTriggerSpec(gesture: .tap, fingerCount: 3))
        }
    }
}
