import SwiftUI

/// Formulário efêmero: só emite uma condição completa em Adicionar/Salvar.
/// Paralelo com React: o popover guarda estado local e confirma por callback.
struct ShortcutConditionPicker: View {
    let displays: [DisplayCatalogService.Choice]
    var initialCondition: RuleCondition?
    let onSave: (RuleCondition) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var kind: Kind?
    @State private var weekdays = Set(2...6)
    @State private var startMinute = 540
    @State private var endMinute = 1080
    @State private var displayID = ""
    @State private var windowTitle = ""
    @State private var matchMode = RuleTextMatcher.Mode.contains
    @State private var caseSensitive = false
    @State private var modifiers: Set<InputModifier> = []

    private enum Kind: String, CaseIterable, Identifiable {
        case time, display, title, keys
        var id: Self { self }
        var title: String {
            switch self {
            case .time: "Em certos horários"
            case .display: "Em um monitor"
            case .title: "Pelo nome da janela"
            case .keys: "Com uma tecla pressionada"
            }
        }
        var subtitle: String {
            switch self {
            case .time: "Escolher dias e horários"
            case .display: "Usar em uma tela específica"
            case .title: "Reconhecer parte do título"
            case .keys: "Combinar o gesto com ⌘ ou ⌥"
            }
        }
        var symbol: String {
            switch self {
            case .time: "clock"
            case .display: "display"
            case .title: "macwindow"
            case .keys: "command"
            }
        }
    }

    private var condition: RuleCondition? {
        switch kind {
        case .time:
            weekdays.isEmpty ? nil : .timeRange(startMinute: startMinute, endMinute: endMinute, weekdays: weekdays)
        case .display:
            displayID.isEmpty ? nil : .display(identifier: displayID)
        case .title:
            windowTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil
                : .windowTitle(RuleTextMatcher(value: windowTitle, mode: matchMode, isCaseSensitive: caseSensitive))
        case .keys:
            modifiers.isEmpty ? nil : .modifiers(modifiers)
        case nil: nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                if kind != nil {
                    Button("Voltar", systemImage: "chevron.left") { kind = nil }
                        .labelStyle(.iconOnly).buttonStyle(.plain)
                }
                Text(kind?.title ?? "Adicionar condição").font(.headline)
            }
            if let kind {
                fields(kind)
                Divider()
                if let condition {
                    Label(ShortcutConditionSummary.text(condition), systemImage: kind.symbol)
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    Button("Cancelar") { dismiss() }.keyboardShortcut(.cancelAction)
                    Spacer()
                    Button(initialCondition == nil ? "Adicionar" : "Salvar") {
                        if let condition { onSave(condition); dismiss() }
                    }
                    .buttonStyle(.borderedProminent).disabled(condition == nil)
                    .keyboardShortcut(.defaultAction).accessibilityIdentifier("tico.composer.save-condition")
                }
            } else {
                ForEach(Kind.allCases) { item in
                    Button { kind = item } label: {
                        HStack(spacing: 12) {
                            Image(systemName: item.symbol).font(.title3).frame(width: 24)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                Text(item.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption)
                        }.padding(8).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }
        }.padding(18).frame(width: 345)
        .onAppear(perform: loadInitial)
    }

    @ViewBuilder private func fields(_ kind: Kind) -> some View {
        switch kind {
        case .time:
            Text("Dias").font(.subheadline)
            HStack(spacing: 4) {
                ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in
                    Toggle(ShortcutConditionSummary.dayName(day), isOn: Binding(
                        get: { weekdays.contains(day) },
                        set: { if $0 { weekdays.insert(day) } else { weekdays.remove(day) } }
                    )).toggleStyle(.button).controlSize(.small)
                }
            }
            HStack {
                DatePicker("Das", selection: timeBinding($startMinute), displayedComponents: .hourAndMinute)
                DatePicker("às", selection: timeBinding($endMinute), displayedComponents: .hourAndMinute)
            }
            if weekdays.isEmpty { Text("Selecione pelo menos um dia.").font(.caption).foregroundStyle(.orange) }
        case .display:
            Picker("Monitor", selection: $displayID) {
                Text("Escolher monitor").tag("")
                ForEach(displays) { Text($0.name).tag($0.id) }
                if !displayID.isEmpty && !displays.contains(where: { $0.id == displayID }) {
                    Text("Monitor desconectado").tag(displayID)
                }
            }
            Text("O atalho considera o monitor da janela em primeiro plano.").font(.caption).foregroundStyle(.secondary)
        case .title:
            TextField("Texto no título da janela", text: $windowTitle).textFieldStyle(.roundedBorder)
            Picker("Comparação", selection: $matchMode) {
                Text("Contém").tag(RuleTextMatcher.Mode.contains)
                Text("Começa com").tag(RuleTextMatcher.Mode.beginsWith)
                Text("Exato").tag(RuleTextMatcher.Mode.exact)
            }
            Toggle("Diferenciar maiúsculas", isOn: $caseSensitive)
        case .keys:
            HStack {
                ForEach(InputModifier.allCases, id: \.self) { modifier in
                    Toggle(modifier.symbol, isOn: Binding(
                        get: { modifiers.contains(modifier) },
                        set: { if $0 { modifiers.insert(modifier) } else { modifiers.remove(modifier) } }
                    )).toggleStyle(.button)
                }
            }
            Text("Mantenha exatamente esta combinação ao fazer o gesto.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func timeBinding(_ minute: Binding<Int>) -> Binding<Date> {
        Binding(get: {
            Calendar.current.date(from: DateComponents(year: 2001, month: 1, day: 1,
                hour: minute.wrappedValue / 60, minute: minute.wrappedValue % 60)) ?? .distantPast
        }, set: { date in
            minute.wrappedValue = Calendar.current.component(.hour, from: date) * 60
                + Calendar.current.component(.minute, from: date)
        })
    }

    private func loadInitial() {
        switch initialCondition {
        case let .timeRange(start, end, days):
            kind = .time; startMinute = start; endMinute = end
            weekdays = days.isEmpty ? Set(1...7) : days
        case let .display(id): kind = .display; displayID = id
        case let .windowTitle(matcher):
            kind = .title; windowTitle = matcher.value; matchMode = matcher.mode; caseSensitive = matcher.isCaseSensitive
        case let .modifiers(values): kind = .keys; modifiers = values
        default: break
        }
    }
}
