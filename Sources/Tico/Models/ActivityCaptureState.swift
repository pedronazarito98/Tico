import Foundation

/// Estado operacional único para orientar a ação principal da tela Atividade.
/// Captura global e captura de trackpad são capacidades distintas: teclado e
/// mouse podem estar ativos mesmo quando o trackpad está indisponível.
enum ActivityCaptureState: Equatable {
    case permissionRequired, paused, active, limited, trackpadUnavailable

    static func resolve(captureIsRunning: Bool, permissionsAreReady: Bool,
                        captureMode: TrackpadCaptureMode) -> Self {
        if !permissionsAreReady && !captureIsRunning { return .permissionRequired }
        guard captureIsRunning else { return .paused }
        switch captureMode {
        case .advancedGlobal: return .active
        case .systemGestureFallback: return .limited
        case .stopped: return .trackpadUnavailable
        }
    }
}
