import Foundation

/// Texto legível sobre o modelo existente; dias vazios significam todos os dias
/// no matcher legado, enquanto o novo formulário exige seleção explícita.
enum ShortcutConditionSummary {
    static func text(_ condition: RuleCondition) -> String {
        switch condition {
        case let .timeRange(start, end, weekdays):
            let days: String
            if weekdays.isEmpty || weekdays.count == 7 { days = "Todos os dias" }
            else if weekdays == Set(2...6) { days = "Segunda a sexta" }
            else { days = [2, 3, 4, 5, 6, 7, 1].filter { weekdays.contains($0) }.map(dayName).joined(separator: ", ") }
            return "\(days), das \(time(start)) às \(time(end))\(end < start ? " (atravessa a meia-noite)" : "")."
        case .display: return "Em um monitor específico"
        case let .windowTitle(matcher): return "Título da janela: \(matcher.value)"
        case let .modifiers(values): return "Com \(InputModifier.allCases.filter { values.contains($0) }.map(\.symbol).joined()) pressionado"
        case .application: return "Em aplicativos específicos"
        }
    }

    static func dayName(_ day: Int) -> String {
        switch day {
        case 1: "Dom"
        case 2: "Seg"
        case 3: "Ter"
        case 4: "Qua"
        case 5: "Qui"
        case 6: "Sex"
        default: "Sáb"
        }
    }

    static func time(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }
}
