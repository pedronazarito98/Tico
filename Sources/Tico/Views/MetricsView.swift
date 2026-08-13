import SwiftUI

struct MetricsView: View {
    @ObservedObject var store: MetricsStore

    @State private var outcomeFilter: MetricOutcome?
    @State private var searchText = ""
    @State private var presentedError: String?

    var body: some View {
        VStack(spacing: 0) {
            summary
                .padding(20)
            Divider()
            HStack {
                Picker("Resultado", selection: $outcomeFilter) {
                    Text("Todos").tag(MetricOutcome?.none)
                    ForEach(MetricOutcome.allCases, id: \.self) {
                        Text($0.displayName).tag(Optional($0))
                    }
                }
                .frame(width: 220)
                Spacer()
                Button {
                    export()
                } label: {
                    Label("Exportar CSV", systemImage: "square.and.arrow.up")
                }
                .disabled(store.events.isEmpty)
                Button("Limpar", role: .destructive) {
                    store.clear()
                }
                .disabled(store.events.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            List(filteredEvents) { event in
                HStack(spacing: 12) {
                    Image(systemName: event.outcome.systemImage)
                        .foregroundStyle(event.outcome.color)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.ruleName ?? "Reconhecimento sem regra")
                            .fontWeight(.medium)
                        HStack(spacing: 5) {
                            if let gesture = event.gesture {
                                Text(gesture.displayName)
                                Text("·")
                            }
                            Text("\(event.latency * 1_000, format: .number.precision(.fractionLength(1))) ms")
                            if let confidence = event.confidence {
                                Text("·")
                                Text("\(confidence * 100, format: .number.precision(.fractionLength(0)))% confiança")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(event.occurredAt, format: .dateTime.day().month().hour().minute().second())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .overlay {
                if filteredEvents.isEmpty {
                    ContentUnavailableView(
                        store.events.isEmpty ? "Sem métricas ainda" : "Nenhum resultado",
                        systemImage: "chart.xyaxis.line",
                        description: Text("As execuções ficam somente neste Mac e o histórico é limitado.")
                    )
                }
            }
            .searchable(text: $searchText, prompt: "Buscar regra ou gesto")
        }
        .navigationTitle("Métricas")
        .alert("Métricas", isPresented: errorPresented) {
            Button("OK", role: .cancel) { presentedError = nil }
        } message: {
            Text(presentedError ?? "Erro desconhecido")
        }
    }

    private var summary: some View {
        let value = store.summary
        return HStack(spacing: 12) {
            MetricCard(
                title: "Execuções",
                value: "\(value.total)",
                detail: "histórico local",
                systemImage: "bolt.fill"
            )
            MetricCard(
                title: "Sucesso",
                value: (value.successRate * 100).formatted(
                    .number.precision(.fractionLength(0))
                ) + "%",
                detail: "\(value.successes) concluídas",
                systemImage: "checkmark.circle.fill"
            )
            MetricCard(
                title: "Latência média",
                value: (value.averageLatency * 1_000).formatted(
                    .number.precision(.fractionLength(1))
                ) + " ms",
                detail: "workflow completo",
                systemImage: "timer"
            )
            MetricCard(
                title: "Confiança",
                value: value.averageConfidence.map {
                    ($0 * 100).formatted(.number.precision(.fractionLength(0))) + "%"
                } ?? "—",
                detail: "\(value.rejections) rejeições",
                systemImage: "waveform.path.ecg"
            )
        }
    }

    private var filteredEvents: [GestureMetricEvent] {
        store.events.filter { event in
            let matchesOutcome = outcomeFilter == nil || event.outcome == outcomeFilter
            let matchesSearch = searchText.isEmpty
                || (event.ruleName ?? "").localizedCaseInsensitiveContains(searchText)
                || (event.gesture?.displayName ?? "").localizedCaseInsensitiveContains(searchText)
            return matchesOutcome && matchesSearch
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { presentedError != nil },
            set: { if !$0 { presentedError = nil } }
        )
    }

    private func export() {
        guard let url = MetricsFilePanel.chooseExportURL() else { return }
        do {
            try store.exportCSV(to: url)
        } catch {
            presentedError = error.localizedDescription
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.42), in: RoundedRectangle(cornerRadius: 10))
    }
}

private extension MetricOutcome {
    var displayName: String {
        switch self {
        case .success: "Sucesso"
        case .failure: "Falha"
        case .rejected: "Rejeitado"
        case .cancelled: "Cancelado"
        }
    }

    var systemImage: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .failure: "xmark.circle.fill"
        case .rejected: "hand.raised.fill"
        case .cancelled: "stop.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: .green
        case .failure: .red
        case .rejected: .orange
        case .cancelled: .secondary
        }
    }
}

