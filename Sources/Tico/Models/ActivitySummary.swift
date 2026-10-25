import Foundation

/// Recortes de calendário locais, incluindo o dia atual. O histórico continua
/// limitado pelo store; "Todo o histórico" não promete dados já descartados.
enum ActivityPeriod: String, CaseIterable, Identifiable {
    case today, week, month, all
    var id: Self { self }
    var title: String {
        switch self {
        case .today: "Hoje"
        case .week: "Últimos 7 dias"
        case .month: "Últimos 30 dias"
        case .all: "Todo o histórico"
        }
    }

    func includes(_ date: Date, now: Date, calendar: Calendar) -> Bool {
        guard date <= now else { return false }
        guard self != .all else { return true }
        let days = self == .today ? 0 : (self == .week ? 6 : 29)
        let start = calendar.date(byAdding: .day, value: -days, to: calendar.startOfDay(for: now))
            ?? calendar.startOfDay(for: now)
        return date >= start
    }
}

struct ActivitySubject: Hashable {
    let ruleID: UUID?
    // Nomes são apenas fallback para registros antigos sem ID. Renomear uma regra
    // não divide sua contagem; a identidade do domínio permanece a mesma.
    private let legacyName: String?

    init(event: GestureMetricEvent) {
        ruleID = event.ruleID
        legacyName = event.ruleID == nil ? event.ruleName : nil
    }
}

struct ActivityUsage: Identifiable {
    let id: ActivitySubject
    let name: String
    let count: Int
    let failures: Int
}

/// Projeção pura: todos os resumos usam o mesmo recorte de período e busca.
/// Cancelamentos e rejeições ficam separados de execuções concluídas/falhas.
/// Paralelo com React: um selector derivado dos dados do store, sem copiar estado
/// persistido para a view nem disparar efeitos enquanto calcula os resultados.
struct ActivitySummary {
    let events: [GestureMetricEvent]
    let usage: [ActivityUsage]
    let successes: Int
    let failures: Int
    let cancellations: Int
    let rejections: Int
    var executionCount: Int { successes + failures + cancellations }

    init(events: [GestureMetricEvent], period: ActivityPeriod, search: String = "",
         now: Date = Date(), calendar: Calendar = .current) {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = events.filter { event in
            period.includes(event.occurredAt, now: now, calendar: calendar)
                && (query.isEmpty || (event.ruleName ?? "").localizedStandardContains(query)
                    || (event.gesture?.displayName ?? "").localizedStandardContains(query))
        }.sorted {
            $0.occurredAt == $1.occurredAt ? $0.id.uuidString < $1.id.uuidString : $0.occurredAt > $1.occurredAt
        }
        self.events = filtered
        successes = filtered.filter { $0.outcome == .success }.count
        failures = filtered.filter { $0.outcome == .failure }.count
        cancellations = filtered.filter { $0.outcome == .cancelled }.count
        rejections = filtered.filter { $0.outcome == .rejected }.count
        usage = Dictionary(grouping: filtered.filter { $0.outcome != .rejected }, by: ActivitySubject.init)
            .map { key, values in
                ActivityUsage(id: key, name: values.first?.ruleName ?? "Automação sem nome",
                              count: values.count, failures: values.filter { $0.outcome == .failure }.count)
            }.sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                if $0.name != $1.name { return $0.name.localizedStandardCompare($1.name) == .orderedAscending }
                return ($0.id.ruleID?.uuidString ?? "") < ($1.id.ruleID?.uuidString ?? "")
            }
    }

    func history(outcome: MetricOutcome?, subject: ActivitySubject?) -> [GestureMetricEvent] {
        events.filter { (outcome == nil || $0.outcome == outcome)
            && (subject == nil || ActivitySubject(event: $0) == subject) }
    }
}
