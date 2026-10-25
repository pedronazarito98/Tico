import SwiftUI

/// Alternativa visual à gravação, com controles semânticos acessíveis.
/// Escolher um movimento altera só seu campo; região, tolerância e modificadores
/// existentes são preservados até uma alteração explícita em seus próprios ajustes.
struct TriggerChoiceSurface: View {
    @ObservedObject var capture: TriggerCaptureSession
    let localInput: LocalInputCaptureService
    let captureMode: TrackpadCaptureMode
    var availableWidth: CGFloat = 900
    @State private var showsAllGestures = false
    @State private var showsModifiers = false
    @State private var showsMovement = false

    private let commonGestures: [TrackpadGesture] = [.swipeLeft, .swipeRight, .swipeUp, .swipeDown, .tap, .hold]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch capture.device {
            case .keyboard:
                VisualKeyboardView(keyCode: capture.keyCode, modifiers: capture.keyboardModifiers,
                    pressedKeys: localInput.pressedKeys, liveModifiers: localInput.modifiers,
                    isRecording: false, onSelect: capture.selectKey)
                    .frame(maxWidth: 710)
            case .trackpad:
                gestures(commonGestures)
                DisclosureGroup("Mais movimentos", isExpanded: $showsAllGestures) {
                    gestures(TrackpadGesture.allCases.filter { !commonGestures.contains($0) })
                        .padding(.top, 10)
                }.font(.callout)
                HStack(spacing: 10) {
                    Text("Com").font(.callout).foregroundStyle(.secondary)
                    ForEach(2...5, id: \.self) { count in
                        Button {
                            capture.trackpad.fingerCount = count...count
                        } label: {
                            Text("\(count) dedos").font(.callout)
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(capture.trackpad.fingerCount == count...count
                                            ? TicoBrand.Palette.primary.opacity(0.12) : .clear,
                                            in: .capsule)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Usar \(count) dedos")
                        .accessibilityAddTraits(capture.trackpad.fingerCount == count...count ? [.isSelected] : [])
                    }
                }
                if capture.hasChosenInput {
                    Button("Ver movimento", systemImage: "play", action: { showsMovement = true })
                        .buttonStyle(.borderless)
                        .popover(isPresented: $showsMovement) {
                            TrackpadCaptureVisual(spec: capture.trackpad, snapshot: nil, isRecording: false)
                                .padding(20)
                        }
                }
                if captureMode == .systemGestureFallback {
                    Label("Alguns movimentos exigem a captura avançada do trackpad.", systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }
                modifierChoices
            case .mouse:
                (availableWidth < 480 ? AnyLayout(VStackLayout(alignment: .leading, spacing: 18))
                                     : AnyLayout(HStackLayout(spacing: 28))) {
                    MouseCaptureVisual(selectedButton: capture.mouseButton, onSelect: capture.selectMouseButton)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Escolha um botão extra").font(.headline)
                        ForEach(2...4, id: \.self) { button in
                            Button { capture.selectMouseButton(button) } label: {
                                Label(InputPresentation.mouseLabel(button),
                                      systemImage: capture.hasChosenInput && capture.mouseButton == button
                                      ? "checkmark.circle.fill" : "circle")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityAddTraits(capture.hasChosenInput && capture.mouseButton == button ? [.isSelected] : [])
                        }
                        Text("Outros botões extras podem ser gravados.")
                            .font(.caption).foregroundStyle(.secondary)
                        ModifierKeyPicker(modifiers: mouseModifiers)
                    }
                }
            }
        }
        .onAppear {
            showsModifiers = capture.mode == .combination || !(capture.trackpad.requiredModifiers ?? []).isEmpty
            showsAllGestures = !commonGestures.contains(capture.trackpad.gesture)
        }
        .onChange(of: capture.mode) { if capture.mode == .combination { showsModifiers = true } }
    }

    private var modifierChoices: some View {
        DisclosureGroup("Segurar teclas junto com o gesto", isExpanded: $showsModifiers) {
            ModifierKeyPicker(modifiers: Binding(
                get: { capture.trackpad.requiredModifiers ?? [] },
                set: {
                    capture.trackpad.requiredModifiers = $0.isEmpty ? nil : $0
                }))
                .padding(.top, 10)
        }.font(.callout)
    }

    private var mouseModifiers: Binding<Set<InputModifier>> {
        Binding(get: { capture.mouseModifiers }, set: {
            capture.mouseModifiers = $0
        })
    }

    private func gestures(_ values: [TrackpadGesture]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), alignment: .leading)], spacing: 6) {
            ForEach(values, id: \.self) { gesture in
                let selected = capture.hasChosenInput && capture.trackpad.gesture == gesture
                Button { capture.selectGesture(gesture) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: symbol(gesture))
                            .font(.title3).frame(width: 28).foregroundStyle(TicoBrand.Palette.primary)
                        Text(gesture.displayName).font(.callout)
                            .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        if selected { Image(systemName: "checkmark").font(.caption.weight(.semibold)) }
                    }
                    .padding(11).frame(maxWidth: .infinity, minHeight: 44)
                    .background(selected ? TicoBrand.Palette.primary.opacity(0.1) : TicoBrand.Palette.surface,
                                in: .rect(cornerRadius: 8))
                    .contentShape(.rect(cornerRadius: 8))
                }
                .buttonStyle(.plain).accessibilityLabel(gesture.displayName)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
    }

    private func symbol(_ gesture: TrackpadGesture) -> String {
        switch gesture {
        case .swipeLeft: "arrow.left"
        case .swipeRight: "arrow.right"
        case .swipeUp: "arrow.up"
        case .swipeDown: "arrow.down"
        case .tap: "hand.tap"
        case .hold: "hand.point.up"
        case .pinchIn: "arrow.down.right.and.arrow.up.left"
        case .pinchOut: "arrow.up.left.and.arrow.down.right"
        case .rotateClockwise: "arrow.clockwise"
        case .rotateCounterclockwise: "arrow.counterclockwise"
        default: "hand.draw"
        }
    }
}
