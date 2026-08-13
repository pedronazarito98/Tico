import SwiftUI

struct TrackpadValidationView: View {
    @ObservedObject var store: TrackpadValidationStore
    let captureMode: TrackpadCaptureMode
    let detectedTrackpads: [TrackpadHardwareInfo]
    let onActivateFallback: () -> Void
    let onRestoreAdvanced: () -> Void
    let onRefreshHardware: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hardwarePanel
                gesturesPanel
                reliabilityPanel
            }
            .padding(8)
        }
    }

    private var hardwarePanel: some View {
        GroupBox("Hardware e ciclo de vida") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Trackpads detectados")
                        .font(.headline)
                    Spacer()
                    Button("Atualizar", action: onRefreshHardware)
                }
                if detectedTrackpads.isEmpty {
                    Text("Nenhum trackpad HID foi enumerado. O provedor privado ainda pode usar o dispositivo padrão.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(detectedTrackpads) { device in
                        Label {
                            VStack(alignment: .leading) {
                                Text(device.name)
                                Text("\(device.isBuiltIn ? "Interno" : "Externo") · \(device.transport)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: device.isBuiltIn ? "laptopcomputer" : "rectangle.connected.to.line.below")
                        }
                    }
                }

                Divider()

                ForEach(HardwareValidationCheck.allCases) { check in
                    if check != .normalUse && check != .publicFallback {
                        Toggle(
                            check.title,
                            isOn: Binding(
                                get: { store.report.completedChecks.contains(check) },
                                set: { store.setCheck(check, completed: $0) }
                            )
                        )
                    }
                }

                HStack {
                    Button(
                        captureMode == .systemGestureFallback
                            ? "Voltar à captura avançada"
                            : "Ativar fallback público"
                    ) {
                        if captureMode == .systemGestureFallback {
                            onRestoreAdvanced()
                        } else {
                            onActivateFallback()
                        }
                    }
                    if store.report.completedChecks.contains(.publicFallback) {
                        Label("Gesto público observado", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Text("Faça um swipe, pinça ou rotação após ativar.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var gesturesPanel: some View {
        GroupBox("Roteiro de gestos físicos") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220))], spacing: 8) {
                ForEach(TrackpadGesture.allCases, id: \.self) { gesture in
                    HStack {
                        Image(
                            systemName: store.report.recognizedByGesture[gesture, default: 0] > 0
                                ? "checkmark.circle.fill"
                                : "circle"
                        )
                        .foregroundStyle(
                            store.report.recognizedByGesture[gesture, default: 0] > 0
                                ? .green
                                : .secondary
                        )
                        Text(gesture.displayName)
                        Spacer()
                        Text("\(store.report.recognizedByGesture[gesture, default: 0])")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private var reliabilityPanel: some View {
        GroupBox("Uso normal e falsos positivos") {
            VStack(alignment: .leading, spacing: 10) {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 7) {
                    valueRow("Reconhecidos", "\(store.report.recognizedCount)")
                    valueRow("Rejeitados", "\(store.report.rejectedSessionCount)")
                    valueRow("Ignorados", "\(store.report.ignoredSessionCount)")
                    valueRow("Falsos positivos", "\(store.report.falsePositiveCount)")
                    valueRow(
                        "Taxa",
                        store.report.falsePositiveRate.formatted(
                            .percent.precision(.fractionLength(1))
                        )
                    )
                    valueRow("Tempo observado", durationText)
                }

                HStack {
                    if store.report.normalUseStartedAt == nil {
                        Button("Iniciar observação de uso normal") {
                            store.startNormalUseMonitoring()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Finalizar observação") {
                            store.stopNormalUseMonitoring()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Button("Marcar último como falso positivo") {
                        store.markLastRecognitionAsFalsePositive()
                    }
                    .disabled(store.lastAcceptedGesture == nil)
                    Spacer()
                    Button("Zerar relatório", role: .destructive) {
                        store.reset()
                    }
                }
            }
        }
    }

    private var durationText: String {
        Duration.seconds(store.report.normalUseDuration)
            .formatted(.time(pattern: .hourMinuteSecond))
    }

    private func valueRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value).monospacedDigit()
        }
    }
}

private extension HardwareValidationCheck {
    var title: String {
        switch self {
        case .internalTrackpad: "Validado no trackpad interno"
        case .magicTrackpad: "Validado no Magic Trackpad, se disponível"
        case .sleepWake: "Sleep e wake preservaram a captura"
        case .disconnectReconnect: "Desconexão e reconexão foram seguras"
        case .publicFallback: "Fallback público reconheceu um gesto"
        case .normalUse: "Observação de uso normal concluída"
        }
    }
}
