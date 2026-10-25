import SwiftUI

/// Detalhe de um único objetivo. A demonstração fica nesta seleção; a lista
/// permanece estática. O pai mantém persistência e resolve prática e edição.
/// Textos podem crescer verticalmente no detalhe rolável, sem reduzir a fonte.
struct ShortcutLearningGoalView: View {
    let rule: ShortcutRule
    let goal: ShortcutLearningGoal?
    let isMastered: Bool
    let unavailableReason: String?
    let remindersEnabled: Bool
    let onBegin: () -> Void
    let onReset: () -> Void
    let onMastered: () -> Void
    let onPractice: () -> Void
    let onSetReminders: (Bool) -> Void
    @State private var replacingGoal = false
    @State private var resetting = false

    private var currentGoal: ShortcutLearningGoal? {
        goal.flatMap { $0.ruleID == rule.id ? $0 : nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(spacing: 14) {
                if case .keyboard = rule.trigger {
                    Image(systemName: "keyboard").font(.title2).foregroundStyle(.secondary)
                } else {
                    ShortcutGesturePreview(trigger: rule.trigger, height: 118)
                        .frame(maxWidth: 210)
                }
                ViewThatFits(in: .horizontal) {
                    TriggerKeycaps(trigger: rule.trigger)
                    Text(rule.trigger.displayName).font(.headline).multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .accessibilityElement(children: .combine)

            if let currentGoal {
                activeGoal(currentGoal)
            } else if isMastered {
                Label("Você já aprendeu este atalho", systemImage: "checkmark.seal.fill")
                    .font(.headline).foregroundStyle(TicoBrand.Palette.primary)
                Text("Use o acionamento acima para executar a ação. Você pode ensaiar novamente quando quiser.")
                    .foregroundStyle(.secondary)
                practiceButton
                Menu("Mais opções") {
                    Button("Aprender novamente", action: begin)
                        .disabled(unavailableReason != nil)
                    Button("Apagar progresso deste atalho…", role: .destructive) { resetting = true }
                }.fixedSize()
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Aprenda no seu ritmo").font(.headline)
                    Text("O ensaio reconhece seu acionamento sem executar ações. O acompanhamento conta cinco usos reais e oferece dicas depois de usar o painel.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { beginButton; practiceButton }
                    VStack(alignment: .leading, spacing: 12) { beginButton; practiceButton }
                }
            }
            if let unavailableReason {
                Label(unavailableReason, systemImage: "info.circle")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .confirmationDialog("Trocar o atalho em aprendizado?", isPresented: $replacingGoal, titleVisibility: .visible) {
            Button("Acompanhar este atalho", action: onBegin)
        } message: {
            Text("O objetivo atual será substituído. Os outros atalhos já aprendidos serão preservados.")
        }
        .confirmationDialog("Apagar o progresso deste atalho?", isPresented: $resetting, titleVisibility: .visible) {
            Button("Apagar somente este progresso", role: .destructive, action: onReset)
        } message: {
            Text("Os outros atalhos aprendidos e sua preferência de dicas serão preservados.")
        }
    }

    private func activeGoal(_ goal: ShortcutLearningGoal) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Use este acionamento no seu dia a dia").font(.headline)
                Text("\(goal.gestureSuccesses) de \(ShortcutLearningGoal.requiredSuccesses) usos reais concluídos")
                    .font(.callout).foregroundStyle(.secondary)
                ProgressView(value: goal.progress)
                    .accessibilityLabel("Aprendizado de \(rule.name)")
                    .accessibilityValue("\(goal.gestureSuccesses) de \(ShortcutLearningGoal.requiredSuccesses) usos reais")
            }
            practiceButton
            Divider()
            Toggle("Receber dicas discretas", isOn: Binding(get: { remindersEnabled }, set: onSetReminders))
                .toggleStyle(.switch)
            Text("Silenciar dicas mantém seu progresso. Ensaios não contam como uso real.")
                .font(.caption).foregroundStyle(.secondary)
            if remindersEnabled, let until = goal.snoozedUntil, until > Date() {
                Text("Dicas adiadas até \(until.formatted(date: .abbreviated, time: .shortened)).")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Menu("Mais opções") {
                Button("Já sei usar — marcar como aprendido", action: onMastered)
                Button("Apagar progresso deste atalho…", role: .destructive) { resetting = true }
            }.fixedSize()
        }
    }

    private var beginButton: some View {
        Button(action: begin) {
            Label("Acompanhar no dia a dia", systemImage: "sparkles")
                .fixedSize(horizontal: false, vertical: true)
        }.buttonStyle(.borderedProminent)
            .disabled(unavailableReason != nil).accessibilityIdentifier("tico.learning.begin")
    }

    private var practiceButton: some View {
        Button(action: onPractice) {
            Label("Experimentar sem executar", systemImage: "hand.draw")
                .fixedSize(horizontal: false, vertical: true)
        }.accessibilityHint("Reconhece o acionamento três vezes sem executar a ação do atalho")
            .accessibilityIdentifier("tico.learning.practice")
    }

    private func begin() {
        if let goal, goal.ruleID != rule.id { replacingGoal = true } else { onBegin() }
    }
}
