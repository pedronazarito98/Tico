import SwiftUI

enum CaptureGlassState: Equatable {
    case permissionRequired
    case paused
    case active
    case limited
}

struct CaptureGlassControl: View {
    let captureIsRunning: Bool
    let permissionsAreReady: Bool
    let captureMode: TrackpadCaptureMode
    let onToggleCapture: () -> Void
    let onOpenPermissions: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var glassNamespace

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            if state.isActive {
                activeControl
                    .glassEffectID("capture-control", in: glassNamespace)
                    .glassEffectTransition(.matchedGeometry)
            } else {
                inactiveControl
                    .glassEffectID("capture-control", in: glassNamespace)
                    .glassEffectTransition(.matchedGeometry)
            }
        }
        .animation(
            reduceMotion ? nil : .snappy(duration: 0.42, extraBounce: 0.06),
            value: state
        )
    }

    private var activeControl: some View {
        Button(action: performPrimaryAction) {
            HStack(spacing: 12) {
                stateIcon

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.title)
                        .font(.headline)
                    Text(state.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: "pause.fill")
                    .font(.body.weight(.semibold))
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(width: 300, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .glassEffect(
            .regular.tint(state.tint).interactive(),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .accessibilityLabel(state.title)
        .accessibilityValue(state.detail)
        .accessibilityHint(state.actionHint)
    }

    private var inactiveControl: some View {
        Button(action: performPrimaryAction) {
            HStack(spacing: 12) {
                stateIcon

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.title)
                        .font(.headline)
                    Text(state.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Image(systemName: state.actionSystemImage)
                    .font(.body.weight(.semibold))
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(width: 300, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .glassEffect(
            .regular.tint(state.tint).interactive(),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .accessibilityLabel(state.title)
        .accessibilityValue(state.detail)
        .accessibilityHint(state.actionHint)
    }

    private var stateIcon: some View {
        Image(systemName: state.systemImage)
            .font(.title3.weight(.semibold))
            .foregroundStyle(state.foregroundStyle)
            .frame(width: 34, height: 34)
            .contentTransition(.symbolEffect(.replace))
            .accessibilityHidden(true)
    }

    private var state: CaptureGlassState {
        CaptureGlassState.resolve(
            captureIsRunning: captureIsRunning,
            permissionsAreReady: permissionsAreReady,
            captureMode: captureMode
        )
    }

    private func performPrimaryAction() {
        if state == .permissionRequired {
            onOpenPermissions()
        } else {
            onToggleCapture()
        }
    }
}

extension CaptureGlassState {
    static func resolve(
        captureIsRunning: Bool,
        permissionsAreReady: Bool,
        captureMode: TrackpadCaptureMode
    ) -> Self {
        if !permissionsAreReady && !captureIsRunning {
            return .permissionRequired
        }
        guard captureIsRunning else { return .paused }
        return captureMode == .systemGestureFallback ? .limited : .active
    }
}

private extension CaptureGlassState {
    var isActive: Bool {
        self == .active || self == .limited
    }

    var title: String {
        switch self {
        case .permissionRequired: "Permissão necessária"
        case .paused: "Captura pausada"
        case .active: "Captura ativa"
        case .limited: "Captura limitada"
        }
    }

    var detail: String {
        switch self {
        case .permissionRequired: "Autorize o monitoramento de entrada"
        case .paused: "Pronta para reconhecer suas regras"
        case .active: "Reconhecendo gestos e atalhos"
        case .limited: "Usando gestos públicos do sistema"
        }
    }

    var systemImage: String {
        switch self {
        case .permissionRequired: "lock.trianglebadge.exclamationmark"
        case .paused: "waveform.path.ecg"
        case .active: "waveform.path.ecg"
        case .limited: "hand.draw"
        }
    }

    var actionSystemImage: String {
        switch self {
        case .permissionRequired: "arrow.up.forward.app"
        case .paused: "play.fill"
        case .active, .limited: "pause.fill"
        }
    }

    var actionHint: String {
        switch self {
        case .permissionRequired: "Abre a tela de permissões"
        case .paused: "Inicia a captura global"
        case .active, .limited: "Pausa a captura global"
        }
    }

    var tint: Color {
        switch self {
        case .permissionRequired, .limited: .orange.opacity(0.16)
        case .paused: TicoBrand.Palette.primary.opacity(0.14)
        case .active: .green.opacity(0.14)
        }
    }

    var foregroundStyle: Color {
        switch self {
        case .permissionRequired, .limited: .orange
        case .paused: TicoBrand.Palette.primary
        case .active: .green
        }
    }
}
