import SwiftUI

struct OverviewView: View {
    let enabledRuleCount: Int
    let totalRuleCount: Int
    let captureIsRunning: Bool
    let trackpadCaptureMode: TrackpadCaptureMode
    let trackpadStartupError: String?
    let permissionsAreReady: Bool
    let lastEventDescription: String?
    let lastEventDate: Date?
    let recentLogMessages: [String]
    let onToggleCapture: () -> Void
    let onCreateRule: () -> Void
    let onOpenPermissions: () -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                hero

                VStack(alignment: .leading, spacing: 28) {
                    metrics

                    Divider()

                    lastEvent

                    Divider()

                    recentActivity
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 26)
            }
        }
        .navigationTitle("Visão geral")
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: 28) {
            heroIdentity
                .layoutPriority(1)

            Spacer(minLength: 0)

            captureControl
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 28)
        .padding(.top, 26)
        .padding(.bottom, 34)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            LinearGradient(
                colors: [
                    TicoBrand.Palette.primary.opacity(0.16),
                    TicoBrand.Palette.accent.opacity(0.08),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .backgroundExtensionEffect()
        }
    }

    private var heroIdentity: some View {
        VStack(alignment: .leading, spacing: 10) {
            TicoMarkView(.wordmark)
                .frame(width: 142, height: 44, alignment: .leading)

            Text("Automatize sem interromper seu fluxo")
                .font(.title2.weight(.semibold))
                .foregroundStyle(TicoBrand.Palette.text)

            Text("Regras locais, gestos naturais e contexto do seu Mac em um único fluxo.")
                .foregroundStyle(TicoBrand.Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onCreateRule) {
                Label("Nova regra", systemImage: "plus")
            }
            .buttonStyle(.glass)
            .tint(nil)
            .controlSize(.large)
        }
        .frame(maxWidth: 430, alignment: .leading)
    }

    private var captureControl: some View {
        CaptureGlassControl(
            captureIsRunning: captureIsRunning,
            permissionsAreReady: permissionsAreReady,
            captureMode: trackpadCaptureMode,
            onToggleCapture: onToggleCapture,
            onOpenPermissions: onOpenPermissions
        )
    }

    private var metrics: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 24) {
                OverviewMetric(
                    title: "Regras ativas",
                    value: "\(enabledRuleCount)",
                    detail: "de \(totalRuleCount) configuradas",
                    systemImage: "bolt.fill"
                )

                Divider()
                    .frame(height: 64)

                OverviewMetric(
                    title: "Captura global",
                    value: captureIsRunning ? "Ativa" : "Pausada",
                    detail: permissionsAreReady ? "Permissões prontas" : "Permissões pendentes",
                    systemImage: captureIsRunning ? "waveform.path.ecg" : "pause.circle"
                )

                Divider()
                    .frame(height: 64)

                OverviewMetric(
                    title: "Trackpad",
                    value: trackpadCaptureMode.displayName,
                    detail: trackpadStartupError ?? "Gestos configuráveis de 2–5 dedos",
                    systemImage: trackpadCaptureMode == .advancedGlobal
                        ? "hand.draw.fill"
                        : "hand.draw"
                )
            }

            VStack(alignment: .leading, spacing: 20) {
                OverviewMetric(
                    title: "Regras ativas",
                    value: "\(enabledRuleCount)",
                    detail: "de \(totalRuleCount) configuradas",
                    systemImage: "bolt.fill"
                )
                OverviewMetric(
                    title: "Captura global",
                    value: captureIsRunning ? "Ativa" : "Pausada",
                    detail: permissionsAreReady ? "Permissões prontas" : "Permissões pendentes",
                    systemImage: captureIsRunning ? "waveform.path.ecg" : "pause.circle"
                )
                OverviewMetric(
                    title: "Trackpad",
                    value: trackpadCaptureMode.displayName,
                    detail: trackpadStartupError ?? "Gestos configuráveis de 2–5 dedos",
                    systemImage: trackpadCaptureMode == .advancedGlobal
                        ? "hand.draw.fill"
                        : "hand.draw"
                )
            }
        }
    }

    private var lastEvent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Último evento")
                .font(.headline)

            HStack(spacing: 14) {
                Image(
                    systemName: lastEventDescription == nil
                        ? "dot.radiowaves.left.and.right"
                        : "cursorarrow.motionlines"
                )
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text(lastEventDescription ?? "Nenhum evento capturado nesta sessão")
                        .font(.title3.weight(.medium))

                    if let lastEventDate {
                        Text(lastEventDate, format: .relative(presentation: .named))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Inicie a captura e use um atalho")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Atividade recente")
                .font(.headline)

            if recentLogMessages.isEmpty {
                ContentUnavailableView(
                    "Sem atividade",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Execuções e erros recentes aparecerão aqui.")
                )
                .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(recentLogMessages.prefix(5).enumerated()), id: \.offset) { index, message in
                        Label(message, systemImage: "smallcircle.filled.circle")
                            .lineLimit(2)
                            .padding(.vertical, 10)

                        if index < min(recentLogMessages.count, 5) - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

private struct OverviewMetric: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
