import SwiftUI

struct TrackpadLaboratoryView: View {
    let snapshot: TrackpadLaboratorySnapshot?
    let captureMode: TrackpadCaptureMode
    let startupError: String?
    @ObservedObject var calibrationStore: TrackpadCalibrationStore
    @ObservedObject var validationStore: TrackpadValidationStore
    let detectedTrackpads: [TrackpadHardwareInfo]
    let isRecording: Bool
    let recordedFrameCount: Int
    let lastRecording: TrackpadReplayDocument?
    let isReplaying: Bool
    let replayProgress: Double
    let onStartObservation: () -> Void
    let onStopObservation: () -> Void
    let onStartRecording: (String) -> Void
    let onStopRecording: () -> TrackpadReplayDocument?
    let onCancelRecording: () -> Void
    let onReplay: (TrackpadReplayDocument, Double) -> Void
    let onCancelReplay: () -> Void
    let onActivateFallback: () -> Void
    let onRestoreAdvanced: () -> Void
    let onRefreshHardware: () -> Void

    @State private var selectedTab = LaboratoryTab.live
    @State private var highlightedRegion = TrackpadRegion.any

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

            Divider()

            TabView(selection: $selectedTab) {
                Tab("Ao vivo", systemImage: "waveform.path.ecg", value: LaboratoryTab.live) {
                    TrackpadLiveView(
                        snapshot: snapshot,
                        startupError: startupError,
                        highlightedRegion: $highlightedRegion
                    )
                }

                Tab("Calibração", systemImage: "slider.horizontal.3", value: LaboratoryTab.calibration) {
                    TrackpadCalibrationView(
                        store: calibrationStore,
                        highlightedRegion: $highlightedRegion
                    )
                }

                Tab("Sessões", systemImage: "record.circle", value: LaboratoryTab.sessions) {
                    TrackpadSessionView(
                        isRecording: isRecording,
                        recordedFrameCount: recordedFrameCount,
                        lastRecording: lastRecording,
                        isReplaying: isReplaying,
                        replayProgress: replayProgress,
                        onStartRecording: onStartRecording,
                        onStopRecording: onStopRecording,
                        onCancelRecording: onCancelRecording,
                        onReplay: onReplay,
                        onCancelReplay: onCancelReplay
                    )
                }

                Tab("Validação", systemImage: "checklist", value: LaboratoryTab.validation) {
                    TrackpadValidationView(
                        store: validationStore,
                        captureMode: captureMode,
                        detectedTrackpads: detectedTrackpads,
                        onActivateFallback: onActivateFallback,
                        onRestoreAdvanced: onRestoreAdvanced,
                        onRefreshHardware: onRefreshHardware
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .navigationTitle("Laboratório do Trackpad")
        .onAppear(perform: onStartObservation)
        .onDisappear(perform: onStopObservation)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Laboratório do Trackpad")
                    .font(.title2.weight(.semibold))
                Text("Observe, calibre e reproduza gestos sem executar regras.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Label(captureMode.displayName, systemImage: captureModeIcon)
                .foregroundStyle(captureMode == .advancedGlobal ? .green : .secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var captureModeIcon: String {
        switch captureMode {
        case .stopped: "stop.circle"
        case .advancedGlobal: "dot.radiowaves.left.and.right"
        case .systemGestureFallback: "arrow.triangle.2.circlepath"
        }
    }
}

private enum LaboratoryTab: Hashable {
    case live
    case calibration
    case sessions
    case validation
}
