import SwiftUI

struct SidebarView: View {
    @Binding var selection: TicoSection?
    @Binding var selectedRuleID: ShortcutRule.ID?
    let ruleItems: [RuleSidebarItem]
    let enabledRuleCount: Int
    let totalRuleCount: Int
    let captureIsRunning: Bool
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
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(primarySections) { section in
                        navigationRow(for: section)
                    }

                    Text("Ferramentas")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TicoBrand.Palette.secondaryText)
                        .padding(.horizontal, 10)
                        .padding(.top, 16)
                        .padding(.bottom, 4)

                    ForEach(toolSections) { section in
                        navigationRow(for: section)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
            }

            Divider()

            SidebarStatusRow(
                captureIsRunning: captureIsRunning,
                enabledRuleCount: enabledRuleCount,
                totalRuleCount: totalRuleCount
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(.regularMaterial)
        .navigationTitle(TicoBrand.displayName)
        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
    }

    @ViewBuilder
    private func navigationRow(for section: TicoSection) -> some View {
        if section == .rules {
            RuleSidebarSection(
                selection: $selection,
                selectedRuleID: $selectedRuleID,
                items: ruleItems,
                onSetRuleEnabled: onSetRuleEnabled,
                onDeleteRule: onDeleteRule
            )
        } else {
            Button {
                selection = section
            } label: {
                HStack(spacing: 8) {
                    Label(section.title, systemImage: section.systemImage)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(
                    selection == section
                        ? TicoBrand.Palette.primary
                        : TicoBrand.Palette.text
                )
                .background {
                    if selection == section {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(TicoBrand.Palette.primary.opacity(0.10))
                    }
                }
                .overlay(alignment: .leading) {
                    if selection == section {
                        Capsule()
                            .fill(TicoBrand.Palette.primary)
                            .frame(width: 2, height: 20)
                            .offset(x: -3)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
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
    }
}
