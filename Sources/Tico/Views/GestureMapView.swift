import SwiftUI

/// Consulta com seleção estável e um detalhe por vez. Paralelo com React:
/// selectedRuleID é estado efêmero; progresso e preferências continuam no store.
struct GestureMapView: View {
    @ObservedObject var learning: ShortcutLearningStore
    let rules: [ShortcutRule]

    let applications: [ApplicationChoice]
    let context: ContextSnapshot?
    let onPractice: (ShortcutRule) -> Void
    let onEdit: (UUID) -> Void
    @State private var currentAppOnly = false
    @State private var selectedRuleID: UUID?
    @State private var learningError: String?
    @State private var resettingAll = false

    private var visibleRules: [ShortcutRule] {
        guard currentAppOnly, let context else { return rules }
        return rules.filter { $0.matches(context) }
    }
    private var selectedRule: ShortcutRule? {
        visibleRules.first { $0.id == selectedRuleID }
    }
    private var activeRule: ShortcutRule? {
        rules.first { $0.id == learning.goal?.ruleID }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            AdaptiveSplitView(idealPrimaryWidth: 285, maxPrimaryWidth: 350) {
                List(selection: $selectedRuleID) {
                    ForEach(visibleRules) { rule in
                        LearningShortcutRow(rule: rule, applications: applications,
                            isCurrentGoal: learning.goal?.ruleID == rule.id,
                            isMastered: learning.masteredRuleIDs.contains(rule.id))
                            .tag(rule.id)
                            .contextMenu {
                                Button("Experimentar sem executar") { onPractice(rule) }
                                Button("Editar atalho") { onEdit(rule.id) }
                            }
                    }
                }
                .listStyle(.inset)
                .overlay {
                    if visibleRules.isEmpty {
                        VStack(spacing: 6) {
                            Label("Nenhum atalho", systemImage: "keyboard").font(.headline)
                            Text(currentAppOnly ? "Mostre todos os apps para escolher um atalho."
                                 : "Crie um atalho em Meus atalhos ou escolha uma ideia em Explorar.")
                                .font(.caption).foregroundStyle(.secondary)
                        }.multilineTextAlignment(.center).padding(12).allowsHitTesting(false)
                    }
                }
            } detail: {
                detail
            }
        }
        .navigationTitle("Mapa de gestos")
        .onAppear {
            selectedRuleID = learning.goal?.ruleID ?? visibleRules.first?.id
            reconcileSelection()
        }
        .onChange(of: rules) { reconcileSelection() }
        .onChange(of: currentAppOnly) { reconcileSelection() }
        .onChange(of: context) { reconcileSelection() }
        .confirmationDialog("Apagar todo o aprendizado?", isPresented: $resettingAll, titleVisibility: .visible) {
            Button("Apagar todos os progressos", role: .destructive) {
                performLearningAction { try learning.resetAllLearning() }
            }
        } message: {
            Text("Isso remove o objetivo atual, todos os atalhos marcados como aprendidos e desativa as dicas. Seus atalhos permanecem disponíveis.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Seus atalhos, na memória").font(.title2.weight(.semibold))
                    Text("Consulte, ensaie sem executar e acompanhe o uso real.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                Menu {
                    Button("Apagar todo o aprendizado…", role: .destructive) { resettingAll = true }
                        .disabled(learning.goal == nil && learning.masteredRuleIDs.isEmpty)
                } label: { Image(systemName: "ellipsis") }
                    .menuStyle(.borderlessButton).fixedSize()
                    .accessibilityLabel("Opções de aprendizado")
            }
            HStack(spacing: 16) {
                Menu {
                    Button("Todos os apps") { currentAppOnly = false }
                    if let context {
                        Button("Disponíveis em \(context.frontmostApplicationName ?? "app atual")") { currentAppOnly = true }
                    }
                } label: {
                    Label(currentAppOnly ? (context?.frontmostApplicationName ?? "App atual") : "Todos os apps",
                          systemImage: "line.3.horizontal.decrease")
                }.lineLimit(1).frame(maxWidth: 240, alignment: .leading)
                if let activeRule, let goal = learning.goal {
                    Button {
                        currentAppOnly = false
                        selectedRuleID = activeRule.id
                    } label: {
                        Label("\(activeRule.name) · \(goal.gestureSuccesses)/\(ShortcutLearningGoal.requiredSuccesses)", systemImage: "sparkles")
                            .lineLimit(1)
                    }.buttonStyle(.plain)
                        .accessibilityLabel("Continuar aprendizado de \(activeRule.name), \(goal.gestureSuccesses) de 5 usos reais")
                }
                Spacer(minLength: 0)
            }
            if let message = learningError ?? learning.errorMessage {
                Label(message, systemImage: "exclamationmark.circle").font(.callout).foregroundStyle(.red)
            } else if let notice = learning.notice {
                Label(notice, systemImage: "info.circle").font(.callout).foregroundStyle(.secondary)
            }
        }.padding(20)
    }

    @ViewBuilder private var detail: some View {
        if let rule = selectedRule {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(rule.name).font(.title2.weight(.semibold))
                            Text(rule.scope.displayName(applications: applications))
                                .font(.callout).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Editar", systemImage: "pencil") { onEdit(rule.id) }
                    }
                    ShortcutLearningGoalView(rule: rule, goal: learning.goal,
                        isMastered: learning.masteredRuleIDs.contains(rule.id),
                        unavailableReason: learning.unavailableReason(for: rule),
                        remindersEnabled: learning.remindersEnabled,
                        onBegin: { performLearningAction { try learning.beginLearning(rule: rule) } },
                        onReset: { performLearningAction { try learning.reset(ruleID: rule.id) } },
                        onMastered: { performLearningAction { try learning.markMastered() } },
                        onPractice: { onPractice(rule) },
                        onSetReminders: { value in performLearningAction { try learning.setEnabled(value) } })
                        .id(rule.id)
                }.padding(20).frame(maxWidth: 620, alignment: .leading)
            }.frame(maxWidth: .infinity)
        } else {
            ContentUnavailableView("Escolha um atalho", systemImage: "hand.draw",
                description: Text("O acionamento e as opções de aprendizado aparecem aqui."))
        }
    }

    private func reconcileSelection() {
        if !visibleRules.contains(where: { $0.id == selectedRuleID }) {
            selectedRuleID = visibleRules.first?.id
        }
    }
    private func performLearningAction(_ action: () throws -> Void) {
        do { try action(); learningError = nil }
        catch { learningError = error.localizedDescription }
    }
}

private struct LearningShortcutRow: View {
    let rule: ShortcutRule
    let applications: [ApplicationChoice]
    let isCurrentGoal: Bool
    let isMastered: Bool

    var body: some View {
        HStack(spacing: 10) {
            ShortcutActionIcon(action: rule.action, applications: applications, size: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.name).font(.callout.weight(.medium)).lineLimit(1)
                Text(rule.trigger.displayName).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                if !rule.isEnabled { Text("Atalho pausado").font(.caption).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 4)
            if isCurrentGoal { Image(systemName: "sparkles").accessibilityLabel("Em aprendizado") }
            if isMastered { Image(systemName: "checkmark.seal").accessibilityLabel("Aprendido") }
        }.padding(.vertical, 7).accessibilityElement(children: .combine)
    }
}
