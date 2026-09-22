import SwiftUI

enum SidebarDestination: Hashable {
    case section(TicoSection)
    case rule(ShortcutRule.ID)
    case application(String)
}

/// Navegação estável da janela. A busca atua na biblioteca, sem substituir linhas
/// da source list nativa por resultados com outra hierarquia.
struct SidebarView: View {
    @Binding var selection: TicoSection?
    @Binding var selectedRuleID: ShortcutRule.ID?
    @Binding var applicationFilter: String?
    let scopedApplications: [ApplicationChoice]
    let enabledRuleCount: Int
    let totalRuleCount: Int
    let captureIsRunning: Bool
    @SceneStorage("sidebar.advancedToolsExpanded") private var advancedToolsExpanded = false

    private let primarySections: [TicoSection] = [
        .rules,
        .explore,
        .scenes,
        .gestureMap
    ]
    private let toolSections: [TicoSection] = [
        .overview,
        .permissions,
        .profiles,
        .library,
        .laboratory,
        .metrics,
        .log
    ]

    var body: some View {
        List(selection: destinationBinding) {
            Section {
                ForEach(primarySections) { section in navigationRow(for: section) }
            }
            if !scopedApplications.isEmpty {
                Section("Aplicativos") {
                    ForEach(scopedApplications) { app in
                        HStack(spacing: 8) {
                            ApplicationIconView(application: app, size: 20)
                            Text(app.name)
                        }
                            .tag(SidebarDestination.application(app.bundleIdentifier))
                    }
                }
            }
            Section {
                DisclosureGroup("Ferramentas", isExpanded: $advancedToolsExpanded) {
                    ForEach(toolSections) { section in navigationRow(for: section) }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                SettingsLink { Label("Ajustes…", systemImage: "gearshape") }
                    .buttonStyle(.plain)
                SidebarStatusRow(
                    captureIsRunning: captureIsRunning,
                    enabledRuleCount: enabledRuleCount,
                    totalRuleCount: totalRuleCount
                )
            }
            .padding(14)
        }
        .navigationTitle(TicoBrand.displayName)
        .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
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
                if selection == .rules, let applicationFilter {
                    return .application(applicationFilter)
                }
                return .section(selection)
            },
            set: { destination in
                switch destination {
                case let .section(section):
                    applicationFilter = nil
                    selection = section
                case let .rule(id):
                    selectedRuleID = id
                    applicationFilter = nil
                    selection = .rules
                case let .application(id):
                    selection = .rules
                    applicationFilter = id
                case nil:
                    break
                }
            }
        )
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
