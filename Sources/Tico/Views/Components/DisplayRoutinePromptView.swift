import SwiftUI

/// A sugestão fica disponível fora da janela principal, sem roubar foco.
struct DisplayRoutinePromptView: View {
    let suggestion: DisplayRoutineSuggestion
    let onAccept: (UUID) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(suggestion.intents.count == 1 ? "Preparar seu espaço?" : "Qual cena usar?",
                      systemImage: "display.2").font(.headline)
                Spacer()
                Button(action: onDismiss) { Image(systemName: "xmark") }
                    .buttonStyle(.plain).accessibilityLabel("Dispensar sugestão")
            }
            Text(suggestion.reason).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(suggestion.intents) { intent in choice(intent) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxHeight: 140)
            if suggestion.intents.contains(where: { $0.workflow.sceneLayout != nil }) {
                Text("Os apps podem abrir antes de você revisar a posição das janelas.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button("Agora não", action: onDismiss).controlSize(.small)
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityIdentifier("tico.routines.suggestion")
    }

    @ViewBuilder private func choice(_ intent: DisplayRoutineExecutionIntent) -> some View {
        let title = "Preparar \(intent.workflow.name.isEmpty ? "cena" : intent.workflow.name)"
        if suggestion.intents.count == 1 {
            Button { onAccept(intent.routineID) } label: {
                Text(title).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.borderedProminent)
        } else {
            Button { onAccept(intent.routineID) } label: {
                Label(title, systemImage: "rectangle.3.group")
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 7).frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.bordered)
        }
    }
}
