import SwiftUI

struct ActivityUsageView: View {
    let summary: ActivitySummary
    let onFilter: (ActivityUsage) -> Void
    let onShowFailures: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text(summary.executionCount == 1 ? "1 execução neste período" : "\(summary.executionCount) execuções neste período")
                    .font(.title2.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { outcomes }
                    VStack(alignment: .leading, spacing: 8) { outcomes }
                }
            }
            if !summary.usage.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mais usados").font(.headline).padding(.bottom, 6)
                    ForEach(summary.usage.prefix(3)) { usage in
                        Button { onFilter(usage) } label: {
                            HStack(spacing: 12) {
                                Text(usage.name).lineLimit(2).multilineTextAlignment(.leading)
                                Spacer(minLength: 8)
                                Text(usage.count.formatted()).monospacedDigit()
                                Image(systemName: "chevron.right").font(.caption).accessibilityHidden(true)
                            }.padding(.vertical, 8).contentShape(Rectangle())
                        }.buttonStyle(.plain).help("Ver resultados de \(usage.name)")
                    }
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var outcomes: some View {
        Label("\(summary.successes) concluídas", systemImage: "checkmark.circle").foregroundStyle(.secondary)
        if summary.failures > 0 {
            Button(action: onShowFailures) {
                Label("\(summary.failures) com falha", systemImage: "exclamationmark.circle")
            }.buttonStyle(.borderless)
        }
        if summary.cancellations > 0 {
            Text("\(summary.cancellations) canceladas").foregroundStyle(.secondary)
        }
        if summary.rejections > 0 {
            Text("\(summary.rejections) reconhecimentos rejeitados").foregroundStyle(.secondary)
        }
    }
}
