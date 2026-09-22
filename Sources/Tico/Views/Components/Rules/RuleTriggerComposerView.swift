import SwiftUI

/// Edição por reconhecimento e escolhas comuns; o editor técnico continua disponível.
/// Paralelo com React: o Binding edita o mesmo draft do pai; não há cópia da regra.
struct RuleTriggerComposerView: View {
    @Binding var trigger: TriggerDefinition
    @Binding var advancedTrackpadOptionsAreExpanded: Bool
    let captureMode: TrackpadCaptureMode
    let detectedTrackpads: [TrackpadHardwareInfo]
    let deviceCapabilities: [String: TrackpadDeviceCapability]
    let onRecord: (TriggerRecordingMode) -> Void
    let onPractice: () -> Void
    @State private var showsAdvanced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                EditorChoiceButton(title: "Trackpad", symbol: "hand.draw", isSelected: isTrackpad) {
                    if !isTrackpad { trigger = .trackpad(gesture: .swipeLeft) }
                }
                EditorChoiceButton(title: "Teclado", symbol: "keyboard", isSelected: isKeyboard) {
                    if !isKeyboard { trigger = .keyboard(keyCode: 49, modifiers: [.command]) }
                }
                EditorChoiceButton(title: "Mouse", symbol: "computermouse", isSelected: isMouse) {
                    if !isMouse { trigger = .mouseButton(button: 3, modifiers: []) }
                }
            }

            if case let .trackpad(spec) = trigger {
                RuleGestureChoices(spec: spec, onChange: { trigger = .trackpad(spec: $0) })
            }

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(RuleEditorSummary.trigger(trigger)).font(.title3.weight(.semibold))
                    Text("Grave o movimento ou a combinação que você quer usar.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button("Gravar", systemImage: "record.circle") { onRecord(.standard) }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .accessibilityLabel("Gravar gatilho")
            }.padding(14).background(TicoBrand.Palette.primary.opacity(0.07), in: .rect(cornerRadius: 12))

            HStack {
                Button("Praticar", systemImage: "hand.draw", action: onPractice)
                if isTrackpad || isCustom {
                    Button("Desenhar meu gesto", systemImage: "scribble.variable") { onRecord(.customTrackpad) }
                }
                Spacer()
            }.buttonStyle(.borderless)

            DisclosureGroup("Escolher manualmente ou ajustar gesto", isExpanded: $showsAdvanced) {
                VStack(alignment: .leading, spacing: 12) {
                    RuleTriggerEditorView(trigger: $trigger,
                        advancedTrackpadOptionsAreExpanded: $advancedTrackpadOptionsAreExpanded,
                        captureMode: captureMode, detectedTrackpads: detectedTrackpads,
                        deviceCapabilities: deviceCapabilities)
                }.padding(.top, 12)
            }.font(.callout)
        }
    }

    private var isKeyboard: Bool { if case .keyboard = trigger { return true }; return false }
    private var isMouse: Bool { if case .mouseButton = trigger { return true }; return false }
    private var isTrackpad: Bool { if case .trackpad = trigger { return true }; return false }
    private var isCustom: Bool { if case .customTrackpad = trigger { return true }; return false }
}

/// As escolhas rápidas alteram somente gesto/dedos; limites avançados são preservados.
private struct RuleGestureChoices: View {
    let spec: TrackpadTriggerSpec
    let onChange: (TrackpadTriggerSpec) -> Void
    private let gestures: [TrackpadGesture] = [.swipeLeft, .swipeRight, .swipeUp, .swipeDown, .tap, .hold]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(gestures, id: \.self) { gesture in
                    EditorChoiceButton(title: title(gesture), symbol: symbol(gesture), isSelected: spec.gesture == gesture) {
                        var changed = spec
                        changed.gesture = gesture
                        onChange(changed)
                    }
                }
            }
            HStack {
                Text("Dedos").foregroundStyle(.secondary)
                ForEach(2...5, id: \.self) { count in
                    Button("\(count)") {
                        var changed = spec
                        changed.fingerCount = count...count
                        onChange(changed)
                    }
                    .buttonStyle(.bordered)
                    .tint(spec.fingerCount == count...count ? TicoBrand.Palette.primary : .secondary)
                    .accessibilityLabel("\(count) dedos")
                    .accessibilityAddTraits(spec.fingerCount == count...count ? [.isSelected] : [])
                }
                if spec.fingerCount.lowerBound != spec.fingerCount.upperBound {
                    Text("Faixa: \(spec.fingerCount.lowerBound)–\(spec.fingerCount.upperBound)").font(.caption)
                }
            }
        }
    }

    private func title(_ gesture: TrackpadGesture) -> String {
        switch gesture {
        case .swipeLeft: "Esquerda"
        case .swipeRight: "Direita"
        case .swipeUp: "Para cima"
        case .swipeDown: "Para baixo"
        case .tap: "Tocar"
        case .hold: "Segurar"
        default: gesture.displayName
        }
    }

    private func symbol(_ gesture: TrackpadGesture) -> String {
        switch gesture {
        case .swipeLeft: "arrow.left"
        case .swipeRight: "arrow.right"
        case .swipeUp: "arrow.up"
        case .swipeDown: "arrow.down"
        case .tap: "hand.tap"
        default: "hand.point.up"
        }
    }
}
