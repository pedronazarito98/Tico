import SwiftUI

struct TrackpadLaboratoryHUD: View {
    @Binding var selectedTab: LaboratoryTab
    let captureMode: TrackpadCaptureMode
    let isRecording: Bool
    let recordedFrameCount: Int
    let isReplaying: Bool
    let replayProgress: Double
    let onStartRecording: (String) -> Void
    let onStopRecording: () -> TrackpadReplayDocument?
    let onCancelRecording: () -> Void
    let onCancelReplay: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    modeControl
                    captureStatus(showsTitle: true)
                    sessionControl
                }
                .fixedSize(horizontal: true, vertical: false)

                HStack(spacing: 12) {
                    modeControl
                    captureStatus(showsTitle: false)
                    sessionControl
                        .layoutPriority(1)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var modeControl: some View {
        Picker("Modo do laboratório", selection: $selectedTab) {
            ForEach(LaboratoryTab.allCases) { tab in
                Label(tab.title, systemImage: tab.systemImage)
                    .tag(tab)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .frame(minWidth: 260, idealWidth: 390, maxWidth: 390)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .glassEffect(
            .regular.interactive(),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
    }

    private func captureStatus(showsTitle: Bool) -> some View {
        Group {
            if showsTitle {
                Label(captureMode.displayName, systemImage: captureMode.systemImage)
            } else {
                Label(captureMode.displayName, systemImage: captureMode.systemImage)
                    .labelStyle(.iconOnly)
            }
        }
        .font(.callout.weight(.medium))
        .foregroundStyle(captureMode.foregroundStyle)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassEffect(
            .regular.tint(captureMode.tint),
            in: Capsule()
        )
        .accessibilityLabel("Captura do trackpad")
        .accessibilityValue(captureMode.displayName)
        .help(captureMode.displayName)
    }

    @ViewBuilder
    private var sessionControl: some View {
        if isRecording {
            HStack(spacing: 8) {
                Button {
                    _ = onStopRecording()
                } label: {
                    Label("Finalizar", systemImage: "stop.fill")
                }
                .buttonStyle(.glassProminent)
                .tint(.red)

                Button(role: .destructive, action: onCancelRecording) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.glass)
                .help("Descartar gravação")

                Text("\(recordedFrameCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .accessibilityLabel("\(recordedFrameCount) frames")
            }
        } else if isReplaying {
            HStack(spacing: 10) {
                ProgressView(value: replayProgress)
                    .frame(width: 78)
                    .accessibilityLabel("Progresso do replay")

                Button("Cancelar", action: onCancelReplay)
                    .buttonStyle(.glass)
            }
        } else {
            Button {
                onStartRecording("Sessão do Trackpad")
            } label: {
                Label("Gravar", systemImage: "record.circle")
            }
            .buttonStyle(.glassProminent)
            .tint(.red)
            .disabled(captureMode == .stopped)
            .help(
                captureMode == .stopped
                    ? "Inicie a observação do trackpad para gravar"
                    : "Gravar contatos do trackpad"
            )
        }
    }
}

extension TrackpadCaptureMode {
    fileprivate var systemImage: String {
        switch self {
        case .stopped: "stop.circle"
        case .advancedGlobal: "dot.radiowaves.left.and.right"
        case .systemGestureFallback: "arrow.triangle.2.circlepath"
        }
    }

    fileprivate var foregroundStyle: Color {
        switch self {
        case .stopped: .secondary
        case .advancedGlobal: .green
        case .systemGestureFallback: .orange
        }
    }

    fileprivate var tint: Color? {
        switch self {
        case .stopped: nil
        case .advancedGlobal: .green.opacity(0.14)
        case .systemGestureFallback: .orange.opacity(0.16)
        }
    }
}
