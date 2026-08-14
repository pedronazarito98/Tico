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
        ZStack(alignment: .top) {
            laboratoryBackground

            laboratoryLayer(for: .live) {
                TrackpadLiveView(
                    snapshot: snapshot,
                    startupError: startupError,
                    highlightedRegion: $highlightedRegion
                )
            }

            laboratoryLayer(for: .calibration) {
                TrackpadCalibrationView(
                    store: calibrationStore,
                    highlightedRegion: $highlightedRegion
                )
                .padding(.top, 92)
            }

            laboratoryLayer(for: .sessions) {
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
                .padding(.top, 92)
            }

            laboratoryLayer(for: .validation) {
                TrackpadValidationView(
                    store: validationStore,
                    captureMode: captureMode,
                    detectedTrackpads: detectedTrackpads,
                    onActivateFallback: onActivateFallback,
                    onRestoreAdvanced: onRestoreAdvanced,
                    onRefreshHardware: onRefreshHardware
                )
                .padding(.top, 92)
            }

            TrackpadLaboratoryHUD(
                selectedTab: $selectedTab,
                captureMode: captureMode,
                isRecording: isRecording,
                recordedFrameCount: recordedFrameCount,
                isReplaying: isReplaying,
                replayProgress: replayProgress,
                onStartRecording: onStartRecording,
                onStopRecording: onStopRecording,
                onCancelRecording: onCancelRecording,
                onCancelReplay: onCancelReplay
            )
            .padding(.horizontal, 20)
            .padding(.top, 14)
        }
        .navigationTitle("Laboratório do Trackpad")
        .onAppear(perform: onStartObservation)
        .onDisappear(perform: onStopObservation)
    }

    private func laboratoryLayer<Content: View>(
        for tab: LaboratoryTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .opacity(selectedTab == tab ? 1 : 0)
            .allowsHitTesting(selectedTab == tab)
            .accessibilityHidden(selectedTab != tab)
            .zIndex(selectedTab == tab ? 1 : 0)
    }

    private var laboratoryBackground: some View {
        LinearGradient(
            colors: [
                TicoBrand.Palette.primary.opacity(0.10),
                TicoBrand.Palette.accent.opacity(0.04),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .backgroundExtensionEffect()
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

enum LaboratoryTab: Hashable, CaseIterable, Identifiable {
    case live
    case calibration
    case sessions
    case validation

    var id: Self { self }

    var title: String {
        switch self {
        case .live: "Ao vivo"
        case .calibration: "Calibração"
        case .sessions: "Sessões"
        case .validation: "Validação"
        }
    }

    var systemImage: String {
        switch self {
        case .live: "waveform.path.ecg"
        case .calibration: "slider.horizontal.3"
        case .sessions: "record.circle"
        case .validation: "checklist"
        }
    }
}
