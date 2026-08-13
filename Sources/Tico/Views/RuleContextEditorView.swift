import SwiftUI

struct RuleContextEditorView: View {
    @Binding var scope: RuleScope
    @Binding var profileID: UUID?
    @Binding var conditions: [RuleCondition]
    let profiles: [ShortcutProfile]
    let applications: [ApplicationChoice]
    let currentContext: ContextSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Perfil", selection: $profileID) {
                Text("Sem perfil · regra independente").tag(UUID?.none)
                ForEach(profiles.filter(\.isEnabled)) { profile in
                    Text(profile.name).tag(Optional(profile.id))
                }
            }

            RuleScopePicker(scope: $scope, applications: applications)

            Divider()

            RuleConditionsEditor(
                conditions: $conditions,
                applications: applications,
                emptyMessage: "Sem condições extras. O escopo e o perfil acima definem quando a regra participa."
            )

            if let currentContext {
                let matches = contextMatches(currentContext)
                Label(
                    matches
                        ? "Esta regra participaria no contexto atual"
                        : "Esta regra não participaria no contexto atual",
                    systemImage: matches ? "checkmark.circle.fill" : "xmark.circle"
                )
                .font(.caption)
                .foregroundStyle(matches ? .green : .secondary)
                .help(contextDescription(currentContext))
            }
        }
    }

    private func contextMatches(_ context: ContextSnapshot) -> Bool {
        guard scope.matches(context),
              conditions.allSatisfy({ $0.matches(context) }) else {
            return false
        }
        guard let profileID else { return true }
        return profiles.first { $0.id == profileID }?.matches(context) == true
    }

    private func contextDescription(_ context: ContextSnapshot) -> String {
        [
            context.frontmostApplicationName,
            context.frontmostWindowTitle,
            context.displayIdentifier
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
    }
}

struct RuleConditionsEditor: View {
    @Binding var conditions: [RuleCondition]
    let applications: [ApplicationChoice]
    var emptyMessage = "Sem condições extras."

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Condições adicionais")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Menu {
                    ForEach(RuleConditionKind.allCases) { kind in
                        Button(kind.title) {
                            conditions.append(kind.defaultCondition(applications: applications))
                        }
                    }
                } label: {
                    Label("Condição", systemImage: "plus")
                }
            }

            if conditions.isEmpty {
                Text(emptyMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(conditions.indices, id: \.self) { index in
                    RuleConditionRow(
                        condition: $conditions[index],
                        applications: applications,
                        onDelete: { conditions.remove(at: index) }
                    )
                }
            }
        }
    }
}

private enum RuleConditionKind: String, CaseIterable, Identifiable {
    case application
    case windowTitle
    case display
    case modifiers
    case timeRange

    var id: Self { self }

    var title: String {
        switch self {
        case .application: "Aplicativo"
        case .windowTitle: "Título da janela"
        case .display: "Monitor"
        case .modifiers: "Modificadores"
        case .timeRange: "Horário"
        }
    }

    func defaultCondition(applications: [ApplicationChoice]) -> RuleCondition {
        switch self {
        case .application:
            return .application(
                bundleIdentifiers: [applications.first?.bundleIdentifier ?? ""]
            )
        case .windowTitle:
            return .windowTitle(RuleTextMatcher(value: ""))
        case .display:
            return .display(identifier: "")
        case .modifiers:
            return .modifiers([])
        case .timeRange:
            return .timeRange(startMinute: 9 * 60, endMinute: 18 * 60, weekdays: [])
        }
    }
}

private struct RuleConditionRow: View {
    @Binding var condition: RuleCondition
    let applications: [ApplicationChoice]
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 18)
                .padding(.top, 6)
            fields
            Spacer(minLength: 4)
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .padding(10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var fields: some View {
        switch condition {
        case let .application(bundleIdentifiers):
            Picker("App", selection: Binding(
                get: { bundleIdentifiers.first ?? applications.first?.bundleIdentifier ?? "" },
                set: { condition = .application(bundleIdentifiers: [$0]) }
            )) {
                ForEach(applications) { app in
                    Text(app.name).tag(app.bundleIdentifier)
                }
            }

        case let .windowTitle(matcher):
            VStack(alignment: .leading, spacing: 7) {
                TextField("Texto no título da janela", text: Binding(
                    get: { matcher.value },
                    set: {
                        var value = matcher
                        value.value = $0
                        condition = .windowTitle(value)
                    }
                ))
                HStack {
                    Picker("Comparação", selection: Binding(
                        get: { matcher.mode },
                        set: {
                            var value = matcher
                            value.mode = $0
                            condition = .windowTitle(value)
                        }
                    )) {
                        Text("Contém").tag(RuleTextMatcher.Mode.contains)
                        Text("Começa com").tag(RuleTextMatcher.Mode.beginsWith)
                        Text("Exato").tag(RuleTextMatcher.Mode.exact)
                    }
                    Toggle("Diferenciar maiúsculas", isOn: Binding(
                        get: { matcher.isCaseSensitive },
                        set: {
                            var value = matcher
                            value.isCaseSensitive = $0
                            condition = .windowTitle(value)
                        }
                    ))
                }
                .font(.caption)
            }

        case let .display(identifier):
            TextField("Identificador do monitor", text: Binding(
                get: { identifier },
                set: { condition = .display(identifier: $0) }
            ))

        case let .modifiers(modifiers):
            VStack(alignment: .leading, spacing: 6) {
                Text("Modificadores mantidos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    ForEach(InputModifier.allCases, id: \.self) { modifier in
                        Toggle(modifier.symbol, isOn: Binding(
                            get: { modifiers.contains(modifier) },
                            set: { enabled in
                                var value = modifiers
                                if enabled { value.insert(modifier) } else { value.remove(modifier) }
                                condition = .modifiers(value)
                            }
                        ))
                        .toggleStyle(.button)
                    }
                }
            }

        case let .timeRange(startMinute, endMinute, weekdays):
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Stepper(
                        "De \(time(startMinute))",
                        value: Binding(
                            get: { startMinute },
                            set: {
                                condition = .timeRange(
                                    startMinute: $0,
                                    endMinute: endMinute,
                                    weekdays: weekdays
                                )
                            }
                        ),
                        in: 0...1_439,
                        step: 15
                    )
                    Stepper(
                        "até \(time(endMinute))",
                        value: Binding(
                            get: { endMinute },
                            set: {
                                condition = .timeRange(
                                    startMinute: startMinute,
                                    endMinute: $0,
                                    weekdays: weekdays
                                )
                            }
                        ),
                        in: 0...1_439,
                        step: 15
                    )
                }
                HStack {
                    ForEach(1...7, id: \.self) { weekday in
                        Toggle(weekdaySymbol(weekday), isOn: Binding(
                            get: { weekdays.contains(weekday) },
                            set: { enabled in
                                var value = weekdays
                                if enabled { value.insert(weekday) } else { value.remove(weekday) }
                                condition = .timeRange(
                                    startMinute: startMinute,
                                    endMinute: endMinute,
                                    weekdays: value
                                )
                            }
                        ))
                        .toggleStyle(.button)
                    }
                }
                .font(.caption)
            }
        }
    }

    private var icon: String {
        switch condition {
        case .application: "app"
        case .windowTitle: "macwindow"
        case .display: "display"
        case .modifiers: "command"
        case .timeRange: "clock"
        }
    }

    private func time(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    private func weekdaySymbol(_ weekday: Int) -> String {
        ["", "D", "S", "T", "Q", "Q", "S", "S"][weekday]
    }
}
