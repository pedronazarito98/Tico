import SwiftUI

/// Escolher e gravar são caminhos visuais distintos para o mesmo candidato.
/// O controller continua dono dos monitores; a view conserva só apresentação.
/// Paralelo com React: alternar uma aba não cria outro formulário nem executa efeitos.
struct TriggerCaptureEditor: View {
    @ObservedObject var capture: TriggerCaptureSession
    @ObservedObject var localInput: LocalInputCaptureService
    let snapshot: TrackpadLaboratorySnapshot?
    let captureMode: TrackpadCaptureMode
    let isRecording: Bool
    let canCaptureGlobalInput: Bool
    let onRecord: () -> Void
    let onStop: () -> Void
    let onOpenPermissions: () -> Void
    let onAdvanced: () -> Void
    var availableWidth: CGFloat = 900
    @State private var method = Method.record
    @State private var showsAdvanced = false

    private enum Method: String, CaseIterable, Identifiable {
        case record = "Gravar", choose = "Escolher"
        var id: Self { self }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            (availableWidth < 760 ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                                  : AnyLayout(HStackLayout(alignment: .top, spacing: 16))) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(capture.mode == .sequence ? "Monte a sequência de acionamento" : "Como você quer ativar?")
                        .font(.title2.weight(.semibold))
                    Text(capture.mode == .sequence ? "Adicione de 2 a 5 entradas, na ordem em que vai usá-las." : "Grave uma entrada ou escolha uma opção visual.")
                        .font(.callout).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
                if !capture.isCustomInput {
                    Picker("Dispositivo", selection: device) {
                        ForEach(capture.mode == .combination ? [.trackpad, .mouse] : TriggerCaptureSession.Device.allCases) {
                            Label($0.rawValue, systemImage: $0.symbol).tag($0)
                        }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 290, alignment: .leading)
                    .disabled(isRecording)
                }
            }
            if capture.mode == .sequence {
                TriggerSequenceTimeline(capture: capture, isRecording: isRecording)
            }
            if capture.isCustomInput {
                CustomGestureCaptureView(capture: capture, snapshot: snapshot, isRecording: isRecording,
                    canCaptureGlobalInput: canCaptureGlobalInput, onRecord: onRecord, onStop: onStop,
                    onOpenPermissions: onOpenPermissions)
            } else {
                (availableWidth < 600 ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                                     : AnyLayout(HStackLayout(spacing: 12))) {
                    Picker("Como configurar o acionamento", selection: $method) {
                        ForEach(Method.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 220, alignment: .leading)
                    .disabled(isRecording).accessibilityIdentifier("tico.composer.trigger-method")
                    if method == .choose, capture.hasChosenInput, let input = capture.input {
                        TriggerKeycaps(trigger: input)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if method == .record {
                    TriggerRecordingSurface(capture: capture, snapshot: snapshot, isRecording: isRecording,
                        canCaptureGlobalInput: canCaptureGlobalInput, onRecord: onRecord,
                        onStop: onStop, onOpenPermissions: onOpenPermissions)
                } else {
                    TriggerChoiceSurface(capture: capture, localInput: localInput, captureMode: captureMode,
                                         availableWidth: availableWidth)
                        .disabled(isRecording)
                        .frame(maxWidth: 710, alignment: .leading)
                        .frame(maxWidth: .infinity)
                }
            }
            if let issue = isRecording ? localInput.issue ?? capture.issue : capture.issue {
                Label(issue, systemImage: "exclamationmark.circle")
                    .font(.callout).foregroundStyle(.orange)
            }
            if capture.mode == .sequence {
                Button(capture.replacingStep == nil ? "Adicionar esta entrada" : "Atualizar etapa", systemImage: "plus") {
                    onStop()
                    capture.commitSequenceStep()
                }
                .disabled(!capture.hasChosenInput || capture.input == nil || capture.issue != nil
                          || (capture.sequence.steps.count >= 5 && capture.replacingStep == nil))
            }
            Divider()
            DisclosureGroup("Combinações e ajustes", isExpanded: $showsAdvanced) {
                advancedChoices.padding(.top, 12)
            }.font(.callout).disabled(isRecording)
        }
        .onAppear {
            method = capture.hasChosenInput ? .choose : .record
            showsAdvanced = capture.mode != .single
        }
        .onChange(of: capture.mode) {
            capture.issue = nil
            if capture.mode == .custom || (capture.mode == .combination && capture.device == .keyboard) {
                capture.device = .trackpad
            }
            if capture.mode == .custom { capture.usesCustomGesture = true }
            if capture.mode == .single { capture.usesCustomGesture = false }
            if capture.mode == .combination, !capture.keyboardModifiers.isEmpty {
                capture.trackpad.requiredModifiers = capture.keyboardModifiers
            }
        }
    }

    private var device: Binding<TriggerCaptureSession.Device> {
        Binding(get: { capture.device }, set: {
            capture.device = $0
            capture.usesCustomGesture = false
            // Trocar dispositivo preserva o caminho escolhido pela pessoa.
            // Escolher nunca deve mudar sozinho para Gravar e pedir permissões.
        })
    }

    private var advancedChoices: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), alignment: .leading)], alignment: .leading, spacing: 12) {
                ForEach(TriggerCaptureSession.Mode.allCases) { value in
                    Button { capture.mode = value } label: {
                        Label(modeTitle(value), systemImage: capture.mode == value ? "checkmark.circle.fill" : "circle")
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.borderless)
                        .accessibilityAddTraits(capture.mode == value ? [.isSelected] : [])
                }
            }
            if capture.mode == .sequence && capture.device == .trackpad {
                Button(capture.usesCustomGesture ? "Escolher um movimento da lista" : "Desenhar esta etapa", systemImage: "scribble.variable") {
                    capture.usesCustomGesture.toggle()
                }.buttonStyle(.borderless)
            }
            Button("Região, duração e outros detalhes", systemImage: "slider.horizontal.3", action: onAdvanced)
                .buttonStyle(.borderless)
        }
    }

    private func modeTitle(_ value: TriggerCaptureSession.Mode) -> String {
        switch value {
        case .single: "Uma entrada"
        case .combination: "Teclas + gesto"
        case .sequence: "Sequência"
        case .custom: "Desenhar gesto"
        }
    }
}

struct ModifierKeyPicker: View {
    @Binding var modifiers: Set<InputModifier>
    var body: some View {
        HStack(spacing: 6) {
            ForEach([InputModifier.control, .option, .shift, .command], id: \.self) { modifier in
                Toggle(modifier.symbol, isOn: Binding(get: { modifiers.contains(modifier) }, set: {
                    if $0 { modifiers.insert(modifier) } else { modifiers.remove(modifier) }
                }))
                .toggleStyle(.button).help("Segure \(modifier.displayName) junto com a entrada.")
                .accessibilityLabel(modifier.displayName)
            }
        }
    }
}
