import SwiftUI

/// Informações técnicas pertencem à execução individual, não a um score global.
/// A duração é do workflow inteiro; confiança existe apenas para certos gestos.
struct ActivityEventRow: View {
    let event: GestureMetricEvent
    let destinationTitle: String?
    let onOpen: () -> Void

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                Text(event.occurredAt, format: .dateTime.day().month().year().hour().minute().second())
                if let gesture = event.gesture { Text("Acionamento: \(gesture.displayName)") }
                if event.outcome != .rejected {
                    Text("Duração da execução: \((event.latency * 1_000).formatted(.number.precision(.fractionLength(1)))) ms")
                }
                if let confidence = event.confidence {
                    Text("Confiança do reconhecimento: \((confidence * 100).formatted(.number.precision(.fractionLength(0))))%")
                }
                if let destinationTitle { Button(destinationTitle, action: onOpen) }
            }.font(.callout).foregroundStyle(.secondary).padding(.vertical, 10)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: event.outcome.activityIcon).foregroundStyle(event.outcome.activityColor)
                    .frame(width: 20).padding(.top, 2).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.ruleName ?? "Reconhecimento sem automação").fontWeight(.medium)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(event.outcome.activityTitle) · \(event.occurredAt.formatted(.dateTime.hour().minute()))")
                        .font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.padding(.vertical, 8)
        }
        .accessibilityIdentifier("tico.activity.event.\(event.id)")
    }
}

extension MetricOutcome {
    var activityTitle: String {
        switch self {
        case .success: "Concluído"
        case .failure: "Falhou"
        case .rejected: "Reconhecimento rejeitado"
        case .cancelled: "Cancelado"
        }
    }
    var activityIcon: String {
        switch self {
        case .success: "checkmark.circle"
        case .failure: "exclamationmark.circle"
        case .rejected: "hand.raised"
        case .cancelled: "stop.circle"
        }
    }
    var activityColor: Color {
        switch self {
        case .success: .green
        case .failure: .orange
        case .rejected, .cancelled: .secondary
        }
    }
}
