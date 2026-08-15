import SwiftUI

enum SidebarDestination: Hashable {
    case section(TicoSection)
    case rule(ShortcutRule.ID)
}

struct SidebarView: View {
    @Binding var selection: TicoSection?
    @Binding var selectedRuleID: ShortcutRule.ID?
    let ruleItems: [RuleSidebarItem]
    let enabledRuleCount: Int
    let totalRuleCount: Int
    let captureIsRunning: Bool
    let searchText: String
    let onSetRuleEnabled: (ShortcutRule.ID, Bool) throws -> Void
    let onDeleteRule: (ShortcutRule.ID) throws -> Void

    private let primarySections: [TicoSection] = [
        .overview,
        .permissions,
        .rules,
        .profiles
    ]
    private let toolSections: [TicoSection] = [
        .library,
        .laboratory,
        .metrics,
        .log
    ]

    var body: some View {
        List(selection: destinationBinding) {
            if !filteredPrimarySections.isEmpty {
                Section {
                    ForEach(filteredPrimarySections) { section in
                        navigationRow(for: section)
                    }
                }
            }

            if shouldShowRuleResults {
                RuleSidebarSection(
                    items: filteredRuleItems,
                    onSetRuleEnabled: onSetRuleEnabled,
                    onDeleteRule: onDeleteRule,
                    onSelect: { destinationBinding.wrappedValue = .rule($0) }
                )
            }

            if !filteredToolSections.isEmpty {
                Section("Ferramentas") {
                    ForEach(filteredToolSections) { section in
                        navigationRow(for: section)
                    }
                }
            }

            if hasNoSearchResults {
                Section {
                    Label("Nenhum resultado", systemImage: "magnifyingglass")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Divider()
            SidebarStatusRow(
                captureIsRunning: captureIsRunning,
                enabledRuleCount: enabledRuleCount,
                totalRuleCount: totalRuleCount
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .navigationTitle(TicoBrand.displayName)
        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
    }

    private func navigationRow(for section: TicoSection) -> some View {
        Button {
            destinationBinding.wrappedValue = .section(section)
        } label: {
            HStack(spacing: 8) {
                Label(section.title, systemImage: section.systemImage)

                Spacer(minLength: 0)

                if section == .rules {
                    Text("\(totalRuleCount)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(totalRuleCount) regras")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tag(SidebarDestination.section(section))
        .accessibilityIdentifier("tico.section.\(section.rawValue)")
    }

    private var destinationBinding: Binding<SidebarDestination?> {
        Binding(
            get: {
                guard let selection else { return nil }
                if selection == .rules, let selectedRuleID {
                    return .rule(selectedRuleID)
                }
                return .section(selection)
            },
            set: { destination in
                switch destination {
                case let .section(section):
                    selection = section
                case let .rule(id):
                    selectedRuleID = id
                    selection = .rules
                case nil:
                    break
                }
            }
        )
    }

    private var filteredPrimarySections: [TicoSection] {
        primarySections.filter(matchesSearch)
    }

    private var filteredToolSections: [TicoSection] {
        toolSections.filter(matchesSearch)
    }

    private var filteredRuleItems: [RuleSidebarItem] {
        guard !normalizedSearchText.isEmpty else { return ruleItems }
        return ruleItems.filter {
            $0.name.localizedCaseInsensitiveContains(normalizedSearchText)
                || $0.detail.localizedCaseInsensitiveContains(normalizedSearchText)
        }
    }

    private var shouldShowRuleResults: Bool {
        !filteredRuleItems.isEmpty
            && (selection == .rules || !normalizedSearchText.isEmpty)
    }

    private var hasNoSearchResults: Bool {
        !normalizedSearchText.isEmpty
            && filteredPrimarySections.isEmpty
            && filteredToolSections.isEmpty
            && filteredRuleItems.isEmpty
    }

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func matchesSearch(_ section: TicoSection) -> Bool {
        normalizedSearchText.isEmpty
            || section.title.localizedCaseInsensitiveContains(normalizedSearchText)
    }
}

private struct SidebarStatusRow: View {
    let captureIsRunning: Bool
    let enabledRuleCount: Int
    let totalRuleCount: Int

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(captureIsRunning ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: 7, height: 7)

            Text(captureIsRunning ? "Captura ativa" : "Captura pausada")
                .lineLimit(1)

            Spacer(minLength: 4)

            Text("\(enabledRuleCount)/\(totalRuleCount)")
                .monospacedDigit()
                .help("\(enabledRuleCount) de \(totalRuleCount) regras ativas")
        }
        .font(.caption)
        .foregroundStyle(TicoBrand.Palette.secondaryText)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(captureIsRunning ? "Captura ativa" : "Captura pausada"), "
                + "\(enabledRuleCount) de \(totalRuleCount) regras ativas"
        )
        .accessibilityIdentifier("tico.sidebar.status")
    }
}
