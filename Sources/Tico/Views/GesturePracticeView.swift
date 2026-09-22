import SwiftUI

struct GesturePracticeView: View {
    @ObservedObject var session: GesturePracticeSession
    let isRecording: Bool
    let startupError: String?
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Text("Vamos praticar?").font(.largeTitle.bold())
            if let rule = session.rule {
                Text(rule.name).font(.title2)
                GestureIllustrationView(trigger: rule.trigger)
                Text(rule.trigger.displayName).font(.headline).multilineTextAlignment(.center)
            }
            ProgressView(value: Double(session.completedCount), total: 3)
                .accessibilityLabel("Repetições reconhecidas")
                .accessibilityValue("\(session.completedCount) de 3")
            Text("\(session.completedCount) de 3 reconhecimentos").monospacedDigit()
            Text(isRecording ? session.feedback : (startupError ?? "A captura não está disponível. Confira as permissões e tente novamente."))
                .multilineTextAlignment(.center)
            Label("Durante a prática, suas automações ficam suspensas.", systemImage: "shield")
                .font(.callout).foregroundStyle(.secondary)
            Text("Os gestos próprios do macOS continuam funcionando.").font(.caption).foregroundStyle(.secondary)
            Button(session.isComplete ? "Concluir" : "Encerrar prática", action: onFinish)
                .buttonStyle(.borderedProminent).keyboardShortcut(.cancelAction)
                .accessibilityIdentifier("tico.practice.finish")
        }.padding(32).frame(width: 520, height: 480)
    }
}
