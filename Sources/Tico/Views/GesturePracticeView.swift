import SwiftUI

struct GesturePracticeView: View {
    @ObservedObject var session: GesturePracticeSession
    let isRecording: Bool
    let startupError: String?
    let onFinish: () -> Void
    var rule: ShortcutRule? = nil
    var onRetry: (() -> Void)? = nil
    var onOpenPermissions: (() -> Void)? = nil

    /// A sessão observada sobrevive à rolagem e ao redimensionamento. O rodapé
    /// fica fora do conteúdo para encerrar a captura mesmo em uma sheet baixa.
    /// Paralelo com React: o container muda de tamanho sem remontar a sessão.
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    Text("Vamos praticar?").font(.largeTitle.bold())
                    if let rule = rule ?? session.rule {
                        Text(rule.name).font(.title2).multilineTextAlignment(.center)
                        GestureIllustrationView(trigger: rule.trigger)
                        Text(rule.trigger.displayName).font(.headline).multilineTextAlignment(.center)
                    }
                    ProgressView(value: Double(isRecording ? session.completedCount : 0), total: 3)
                        .accessibilityLabel("Repetições reconhecidas")
                        .accessibilityValue("\(isRecording ? session.completedCount : 0) de 3")
                    Text("\(isRecording ? session.completedCount : 0) de 3 reconhecimentos").monospacedDigit()
                    Text(isRecording ? session.feedback : (startupError ?? "A captura não está disponível. Confira as permissões e tente novamente."))
                        .multilineTextAlignment(.center)
                    if !isRecording {
                        VStack(spacing: 10) {
                            if let onOpenPermissions {
                                Button("Conferir permissões", action: onOpenPermissions)
                            }
                            if let onRetry { Button("Tentar novamente", action: onRetry) }
                        }
                    }
                    Label(isRecording ? "Durante a prática, suas automações ficam suspensas."
                          : "A prática ainda não começou.", systemImage: "shield")
                        .font(.callout).foregroundStyle(.secondary)
                    Text("Os gestos próprios do macOS continuam funcionando.").font(.caption).foregroundStyle(.secondary)
                }.padding(24).frame(maxWidth: .infinity)
            }
            Divider()
            HStack {
                Spacer(minLength: 0)
                Button(isRecording && session.isComplete ? "Concluir" : "Encerrar prática", action: onFinish)
                    .buttonStyle(.borderedProminent).keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("tico.practice.finish")
                Spacer(minLength: 0)
            }.padding(16)
        }
        .adaptiveSheetFrame(idealWidth: 560, idealHeight: 560)
    }
}
