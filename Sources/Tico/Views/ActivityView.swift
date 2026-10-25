import SwiftUI

/// Une estado atual e histórico sem misturar seus tempos: "Agora" permanece
/// independente do período escolhido. O store é observado diretamente; resumos
/// são projeções e filtros pertencem somente a esta janela.
struct ActivityView: View {
    @ObservedObject var store: MetricsStore
    let status: ActivityStatusView
    let session: ActivitySessionView
    let ruleIDs: Set<UUID>
    let sceneIDs: Set<UUID>
    let onOpenRule: (UUID) -> Void
    let onOpenScenes: () -> Void
    var searchText = ""
    @SceneStorage("activity.period") private var periodValue = ActivityPeriod.week.rawValue
    @State private var outcome: MetricOutcome?
    @State private var subject: ActivityUsage?
    @State private var visibleCount = 50
    @State private var confirmsClear = false
    @State private var error: String?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let summary = ActivitySummary(events: store.events, period: period, search: searchText, now: timeline.date)
            let history = summary.history(outcome: outcome, subject: subject?.id)
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 28) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Agora").font(.headline)
                                status
                                session
                            }
                            Divider()
                            sectionHeader(width: geometry.size.width, history: history)
                            if let message = store.lastError {
                                Label(message, systemImage: "exclamationmark.triangle")
                                    .font(.callout).foregroundStyle(.orange)
                            }
                            if summary.events.isEmpty {
                                emptyPeriod
                            } else {
                                ActivityUsageView(summary: summary, onFilter: { usage in
                                    subject = usage
                                    outcome = nil
                                    proxy.scrollTo("activity-history", anchor: .top)
                                }, onShowFailures: {
                                    subject = nil
                                    outcome = .failure
                                    proxy.scrollTo("activity-history", anchor: .top)
                                })
                                historySection(history, width: geometry.size.width)
                            }
                            Text("Histórico local de até \(store.maximumEventCount.formatted()) registros. Os filtros não alteram seus atalhos.")
                                .font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: 1_080, alignment: .leading)
                        .padding(geometry.size.width < 600 ? 16 : 32)
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                }
            }
        }
        .navigationTitle("Atividade")
        .onChange(of: periodValue) { resetHistoryFilters() }
        .onChange(of: searchText) { resetHistoryFilters() }
        .onChange(of: outcome) { visibleCount = 50 }
        .onChange(of: subject?.id) { visibleCount = 50 }
        .confirmationDialog("Limpar todo o histórico de atividade?", isPresented: $confirmsClear, titleVisibility: .visible) {
            Button("Limpar histórico", role: .destructive) {
                store.clear()
                if store.lastError == nil { resetHistoryFilters() }
            }
        } message: {
            Text("Remove todos os registros desta tela, inclusive os que estão fora dos filtros. Seus atalhos e o Log serão preservados.")
        }
        .alert("Não foi possível exportar", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }

    private var period: ActivityPeriod { ActivityPeriod(rawValue: periodValue) ?? .week }

    private func sectionHeader(width: CGFloat, history: [GestureMetricEvent]) -> some View {
        let layout = width < 580 ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
        return layout {
            Text("Seu uso").font(.title2.bold()).frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 18) {
                Menu {
                    ForEach(ActivityPeriod.allCases) { value in
                        Button { periodValue = value.rawValue } label: {
                            if value == period { Label(value.title, systemImage: "checkmark") }
                            else { Text(value.title) }
                        }
                    }
                } label: { Label(period.title, systemImage: "calendar") }
                    .fixedSize().accessibilityIdentifier("tico.activity.period")
                Menu {
                    Button("Exportar resultados filtrados…") { export(history) }.disabled(history.isEmpty)
                    Divider()
                    Button("Limpar histórico…", role: .destructive) { confirmsClear = true }
                        .disabled(store.events.isEmpty)
                } label: { Image(systemName: "ellipsis.circle") }
                    .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Opções do histórico")
            }
        }
    }

    @ViewBuilder private var emptyPeriod: some View {
        ContentUnavailableView {
            Label(searchText.isEmpty ? (store.events.isEmpty ? "Sua atividade aparece aqui" : "Sem atividade neste período")
                  : "Nenhum resultado para esta busca", systemImage: "clock.arrow.circlepath")
        } description: {
            Text(store.events.isEmpty ? "Use um atalho ou prepare uma cena para acompanhar o resultado."
                 : "Escolha outro período ou ajuste a busca para encontrar uma execução.")
        } actions: {
            if !store.events.isEmpty && searchText.isEmpty && period != .all {
                Button("Ver todo o histórico") { periodValue = ActivityPeriod.all.rawValue }
            }
        }.frame(maxWidth: .infinity, minHeight: 200)
    }

    private func historySection(_ history: [GestureMetricEvent], width: CGFloat) -> some View {
        let layout = width < 580 ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 16))
        return VStack(alignment: .leading, spacing: 14) {
            layout {
                Text("Resultados").font(.headline).frame(maxWidth: .infinity, alignment: .leading)
                Menu {
                    Button("Todos os resultados") { outcome = nil }
                    ForEach(MetricOutcome.allCases, id: \.self) { value in
                        Button { outcome = value } label: {
                            Label(value.activityTitle, systemImage: outcome == value ? "checkmark" : value.activityIcon)
                        }
                    }
                } label: { Text(outcome?.activityTitle ?? "Todos os resultados") }.fixedSize()
            }
            if let subject {
                HStack(alignment: .top) {
                    Text("Resultados de \(subject.name)").font(.callout).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Button("Mostrar todos") { self.subject = nil }.buttonStyle(.borderless)
                }
            }
            if history.isEmpty {
                Text("Nenhum resultado com estes filtros.").foregroundStyle(.secondary)
                Button("Limpar filtros dos resultados", action: resetHistoryFilters).buttonStyle(.borderless)
            }
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(history.prefix(visibleCount).enumerated()), id: \.element.id) { index, event in
                    if index == 0 || !Calendar.current.isDate(event.occurredAt, inSameDayAs: history[index - 1].occurredAt) {
                        Text(event.occurredAt, format: .dateTime.weekday(.wide).day().month())
                            .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                            .padding(.top, 16).padding(.bottom, 6)
                    }
                    ActivityEventRow(event: event, destinationTitle: destinationTitle(for: event), onOpen: { open(event) })
                    Divider()
                }
            }
            if history.count > visibleCount {
                Button("Mostrar mais · \(history.count - visibleCount) restantes") { visibleCount += 50 }
                    .buttonStyle(.borderless)
            }
        }.id("activity-history")
    }

    private func destinationTitle(for event: GestureMetricEvent) -> String? {
        guard let id = event.ruleID else { return nil }
        if ruleIDs.contains(id) { return "Revisar atalho" }
        if sceneIDs.contains(id) { return "Abrir Cenas" }
        return nil
    }

    private func open(_ event: GestureMetricEvent) {
        guard let id = event.ruleID else { return }
        if ruleIDs.contains(id) { onOpenRule(id) }
        else if sceneIDs.contains(id) { onOpenScenes() }
    }

    private func resetHistoryFilters() { outcome = nil; subject = nil; visibleCount = 50 }

    private func export(_ events: [GestureMetricEvent]) {
        guard let url = MetricsFilePanel.chooseExportURL() else { return }
        do { try store.exportCSV(to: url, events: events) }
        catch { self.error = error.localizedDescription }
    }
}
