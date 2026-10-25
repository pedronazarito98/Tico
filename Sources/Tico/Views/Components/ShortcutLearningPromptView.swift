import SwiftUI

/// Lembrete sem tomar foco; o host escolhe a superfície e mantém a ação de prática segura.
struct ShortcutLearningPromptView: View {
    let prompt: ShortcutLearningPrompt
    let onPractice: () -> Void
    let onMastered: () -> Void
    let onSnooze: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Label("Na próxima vez, use este atalho", systemImage: "hand.draw")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Button(action: onDismiss) { Image(systemName: "xmark") }
                    .buttonStyle(.plain).accessibilityLabel("Dispensar dica")
            }
            Text(prompt.triggerDescription).font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(prompt.title).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { practiceButton; optionsMenu }
                VStack(alignment: .leading, spacing: 10) { practiceButton; optionsMenu }
            }.controlSize(.small)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tico.learning.prompt")
    }

    private var practiceButton: some View {
        Button("Experimentar sem executar", action: onPractice)
    }

    private var optionsMenu: some View {
        Menu("Mais") {
            Button("Já sei usar — marcar como aprendido", action: onMastered)
            Button("Adiar por um dia", action: onSnooze)
            Button("Dispensar", action: onDismiss)
        }.menuStyle(.borderlessButton).fixedSize()
    }
}
