import Combine
import Foundation

/// Estado temporário de captura. Confirmar copia um valor para RuleEditingSession;
/// navegar entre dispositivos preserva as escolhas feitas nesta sessão.
/// Paralelo com React: um formulário local com commit explícito no formulário pai.
@MainActor
final class TriggerCaptureSession: ObservableObject {
    enum Device: String, CaseIterable, Identifiable {
        case keyboard = "Teclado", trackpad = "Trackpad", mouse = "Mouse"
        var id: Self { self }
        var symbol: String {
            switch self { case .keyboard: "keyboard"; case .trackpad: "hand.draw"; case .mouse: "computermouse" }
        }
    }
    enum Mode: String, CaseIterable, Identifiable {
        case single = "Um acionamento", combination = "Combinação", sequence = "Sequência", custom = "Meu gesto"
        var id: Self { self }
    }
    @Published var device: Device = .keyboard
    @Published var mode: Mode = .single
    @Published var keyCode: UInt16?
    @Published var keyboardModifiers: Set<InputModifier> = []
    @Published var mouseButton = 3
    @Published var mouseModifiers: Set<InputModifier> = []
    @Published var trackpad = TrackpadTriggerSpec(gesture: .swipeUp, fingerCount: 3)
    @Published var sequence = TriggerSequence(steps: [])
    @Published var customName = "Meu gesto"
    @Published var samples: [InputEventDescriptor] = []
    @Published var existingTemplate: CustomGestureTemplate?
    @Published var usesCustomGesture = false
    private var samplesWereEdited = false
    @Published var replacingStep: Int?
    @Published var replacingSample: Int?
    @Published var issue: String?
    @Published private(set) var hasRecordedInput = false
    @Published private var chosenDevices: Set<Device> = []
    private var lastGestureID: UUID?
    private var lastTimestamp: Date?

    init(trigger: TriggerDefinition?) {
        guard let trigger else { return }
        load(trigger)
    }

    func load(_ trigger: TriggerDefinition) {
        mode = .single
        usesCustomGesture = false
        issue = nil
        hasRecordedInput = false
        switch trigger {
        case let .keyboard(code, modifiers): device = .keyboard; keyCode = code; keyboardModifiers = modifiers
        case let .mouseButton(button, modifiers): device = .mouse; mouseButton = button; mouseModifiers = modifiers
        case let .trackpad(spec):
            device = .trackpad; trackpad = spec
            mode = (spec.requiredModifiers ?? []).isEmpty ? .single : .combination
        case let .customTrackpad(template):
            device = .trackpad; mode = .custom; customName = template.name; existingTemplate = template
            usesCustomGesture = true; samplesWereEdited = false
            samples = template.samplePaths.map {
                InputEventDescriptor(kind: .trackpadGesture, fingerCount: template.fingerCount.lowerBound, trackpadPath: $0)
            }
        case let .sequence(value): mode = .sequence; sequence = value
        }
        chosenDevices.insert(device)
    }

    var isCustomInput: Bool { mode == .custom || (mode == .sequence && usesCustomGesture) }

    var input: TriggerDefinition? {
        if isCustomInput {
            if var template = existingTemplate, !samplesWereEdited {
                template.name = customName
                return .customTrackpad(template: template)
            }
            if samples.count >= 3, let template = try? CustomGesturePath.train(name: customName, from: samples) {
                var result = template
                if let original = existingTemplate {
                    result.id = original.id; result.tolerance = original.tolerance; result.createdAt = original.createdAt
                }
                return .customTrackpad(template: result)
            }
            if var template = existingTemplate, samples.isEmpty {
                template.name = customName
                return .customTrackpad(template: template)
            }
            return nil
        }
        switch device {
        case .keyboard: return keyCode.map { .keyboard(keyCode: $0, modifiers: keyboardModifiers) }
        case .mouse: return .mouseButton(button: mouseButton, modifiers: mouseModifiers)
        case .trackpad: return .trackpad(spec: trackpad)
        }
    }
    var result: TriggerDefinition? {
        if mode == .sequence { return sequence.isValid && replacingStep == nil ? .sequence(sequence) : nil }
        guard hasChosenInput else { return nil }
        if mode == .combination {
            if device == .trackpad, (trackpad.requiredModifiers ?? []).isEmpty { return nil }
            if device == .mouse, mouseModifiers.isEmpty { return nil }
        }
        return input
    }
    var requiresTrackpad: Bool { isCustomInput || device == .trackpad }

    /// O valor inicial de uma ilustração não é uma escolha. Apenas captura,
    /// edição explícita ou carregamento de uma regra existente confirma a entrada.
    var hasChosenInput: Bool { isCustomInput ? input != nil : chosenDevices.contains(device) }

    func confirmChoice() {
        chosenDevices.insert(device)
        hasRecordedInput = false
        issue = nil
    }

    func selectMouseButton(_ button: Int) {
        mouseButton = button
        confirmChoice()
    }

    func selectGesture(_ gesture: TrackpadGesture) {
        trackpad.gesture = gesture
        confirmChoice()
    }

    func selectKey(_ code: UInt16) {
        if let modifier = InputPresentation.modifierKeys[code] {
            if keyboardModifiers.contains(modifier) { keyboardModifiers.remove(modifier) }
            else { keyboardModifiers.insert(modifier) }
        } else { keyCode = code }
        confirmChoice()
    }

    func beginCapture() {
        issue = nil
        hasRecordedInput = false
        lastGestureID = nil
        lastTimestamp = nil
    }

    func receive(_ event: InputEventDescriptor) {
        guard event.timestamp != lastTimestamp else { return }
        if let gesture = event.gestureEvent {
            guard gesture.phase == .ended || (!isCustomInput && gesture.kind == .hold && gesture.phase == .began),
                  gesture.sessionID != lastGestureID else { return }
            lastGestureID = gesture.sessionID
        }
        lastTimestamp = event.timestamp
        if isCustomInput { collectSample(event); return }
        issue = nil
        switch (device, event.kind) {
        case (.keyboard, .keyboard): keyCode = event.keyCode; keyboardModifiers = event.modifiers
        case (.mouse, .mouseButton): mouseButton = event.mouseButton ?? 3; mouseModifiers = event.modifiers
        case (.trackpad, .trackpadGesture):
            if case let .trackpad(spec) = event.triggerDefinition {
                trackpad = spec
                if mode == .combination, event.modifiers.isEmpty {
                    issue = "Segure ⌘, ⌥, ⌃ ou ⇧ enquanto faz o gesto."
                }
            }
        default: return
        }
        chosenDevices.insert(device)
        hasRecordedInput = true
    }

    func commitSequenceStep() {
        guard hasChosenInput, let input, let step = TriggerStep(input) else { return }
        if let index = replacingStep, sequence.steps.indices.contains(index) { sequence.steps[index] = step }
        else if sequence.steps.count < 5 { sequence.steps.append(step) }
        replacingStep = nil
    }
    func editStep(_ index: Int) {
        guard sequence.steps.indices.contains(index) else { return }
        load(sequence.steps[index].triggerDefinition)
        mode = .sequence
        replacingStep = index
    }
    func moveStep(_ index: Int, by offset: Int) {
        guard sequence.steps.indices.contains(index), sequence.steps.indices.contains(index + offset) else { return }
        sequence.steps.swapAt(index, index + offset)
        replacingStep = nil
    }
    func removeStep(_ index: Int) {
        guard sequence.steps.indices.contains(index) else { return }
        sequence.steps.remove(at: index)
        replacingStep = nil
    }
    func repeatSample(_ index: Int) {
        replacingSample = index
        issue = nil
    }
    private func collectSample(_ event: InputEventDescriptor) {
        guard event.kind == .trackpadGesture else { return }
        guard event.modifiers.isEmpty else {
            issue = "Grave o gesto livre sem teclas modificadoras. Para combinar teclas, use um gesto da lista."
            return
        }
        guard CustomGesturePath.normalized(event.trackpadPath, pointCount: CustomGestureTemplate.defaultPointCount) != nil else {
            issue = CustomGestureTrainingError.invalidPath.localizedDescription
            return
        }
        guard samples.first?.fingerCount == nil || samples.first?.fingerCount == event.fingerCount else {
            issue = CustomGestureTrainingError.inconsistentFingerCount.localizedDescription
            return
        }
        if let index = replacingSample, samples.indices.contains(index) { samples[index] = event }
        else if samples.count < 3 { samples.append(event) }
        replacingSample = nil
        samplesWereEdited = true
        hasRecordedInput = true
        issue = nil
    }
}
