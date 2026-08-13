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
            VStack(alignment: .leading, spacing: 20) {
                header

                HStack(spacing: 12) {
                    MetricCard(
                        title: "Regras ativas",
                        value: "\(enabledRuleCount)",
                        detail: "de \(totalRuleCount) configuradas",
                        systemImage: "bolt.fill"
                    )
                    MetricCard(
                        title: "Captura global",
                        value: captureIsRunning ? "Ativa" : "Pausada",
                        detail: permissionsAreReady ? "Permissões prontas" : "Permissões pendentes",
                        systemImage: captureIsRunning ? "waveform.path.ecg" : "pause.circle"
                    )
                    MetricCard(
                        title: "Trackpad",
                        value: trackpadCaptureMode.displayName,
                        detail: trackpadStartupError ?? "Gestos configuráveis de 2–5 dedos",
                        systemImage: trackpadCaptureMode == .advancedGlobal
                            ? "hand.draw.fill"
                            : "hand.draw"
                    )
                }

                GroupBox("Último evento") {
                    HStack(spacing: 12) {
                        Image(systemName: lastEventDescription == nil ? "dot.radiowaves.left.and.right" : "cursorarrow.motionlines")
                            .font(.title2)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(lastEventDescription ?? "Nenhum evento capturado nesta sessão")
                                .font(.headline)
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
                    .padding(.vertical, 6)
                }

                GroupBox("Atividade recente") {
                    if recentLogMessages.isEmpty {
                        ContentUnavailableView(
                            "Sem atividade",
                            systemImage: "clock.arrow.circlepath",
                            description: Text("Execuções e erros recentes aparecerão aqui.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 120)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(recentLogMessages.prefix(5).enumerated()), id: \.offset) { _, message in
                                Label(message, systemImage: "smallcircle.filled.circle")
                                    .lineLimit(2)
                                Divider()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Visão geral")
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                TicoMarkView(.wordmark)
                    .frame(width: 142, height: 44, alignment: .leading)

                Text("Automatize sem interromper seu fluxo")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(TicoBrand.Palette.text)
                Text("Gerencie regras globais e acompanhe o que o \(TicoBrand.displayName) reconhece.")
                    .foregroundStyle(TicoBrand.Palette.secondaryText)
            }
            Spacer()
            if !permissionsAreReady {
                Button("Revisar permissões", action: onOpenPermissions)
            }
            Button(captureIsRunning ? "Pausar captura" : "Iniciar captura", action: onToggleCapture)
                .buttonStyle(.borderedProminent)
                .disabled(!permissionsAreReady && !captureIsRunning)
            Button(action: onCreateRule) {
                Label("Nova regra", systemImage: "plus")
            }
        }
        .padding(16)
        .background(
            TicoBrand.Palette.surface,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(TicoBrand.Palette.primary.opacity(0.16))
        }
        .overlay(alignment: .leading) {
            Capsule()
                .fill(TicoBrand.Palette.accent)
                .frame(width: 4)
                .padding(.vertical, 14)
                .offset(x: -2)
                .accessibilityHidden(true)
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String

    var body: some View {
        GroupBox {
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
                }
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity)
    }
}
