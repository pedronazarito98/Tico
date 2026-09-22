import SwiftUI

struct DescribeAutomationView: View {
    let applications: [ApplicationChoice]
    let latestEvent: InputEventDescriptor?
    let recordingIsActive: Bool
    let captureMode: TrackpadCaptureMode
    let startupError: String?
    let snapshot: TrackpadLaboratorySnapshot?
    let onStartRecording: () -> Bool
    let onStopRecording: () -> Void
    let onCreate: (ShortcutRule) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var sentence = "Quando eu fizer um swipe para a esquerda com 3 dedos no Safari, coloque a janela na metade esquerda"
    @State private var recordedTrigger: TriggerDefinition?
    @State private var draft: ShortcutRule?
    @State private var error: String?
    @State private var showsRecorder = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Descreva sua automação").font(.title.bold())
            Text("Use uma frase suportada para montar um rascunho local. Depois, revise no editor.")
                .foregroundStyle(.secondary)
            TextField("Quando eu fizer…", text: $sentence, axis: .vertical)
                .lineLimit(3...6).textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("tico.describe.sentence")
            DisclosureGroup("Frases e ações suportadas") {
                Text("Quando eu fizer [um toque com 3 dedos / um swipe para a esquerda com 3 dedos / este gesto] no [nome do app] ou em qualquer aplicativo, [ação].")
                Text("Ações: coloque a janela na metade esquerda/direita; maximize a janela; centralize a janela; reabra a última aba; abra o [nome do app]; abra [link https].")
            }.font(.callout)
            HStack {
                Button(recordedTrigger == nil ? "Gravar ‘este gesto’" : "Gravar novamente") {
                    showsRecorder = onStartRecording()
                }
                if let recordedTrigger { Text(recordedTrigger.displayName).font(.caption) }
                Spacer()
                Button("Montar rascunho", action: parse).buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("tico.describe.parse")
            }
            if let error { Label(error, systemImage: "info.circle").foregroundStyle(.orange) }
            if let draft {
                GroupBox("Prévia") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quando: \(draft.trigger.displayName)")
                        Text("Onde: \(draft.scope.displayName(applications: applications))")
                        Text("Fazer: \(draft.action.displayName)")
                        Text("Será salvo desativado, para você revisar.").foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(8)
                }
            }
            Spacer(minLength: 0)
            HStack {
                Button("Cancelar") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Revisar no editor") {
                    guard let draft else { return }
                    onCreate(draft)
                    dismiss()
                }.disabled(draft == nil).keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("tico.describe.review")
            }
        }.padding(28).frame(width: 650, height: 540)
            .onChange(of: sentence) { draft = nil; error = nil }
            .sheet(isPresented: $showsRecorder, onDismiss: onStopRecording) {
                TriggerRecorderView(mode: .standard, suggestedName: "Meu gesto",
                    isRecording: recordingIsActive, latestEvent: latestEvent,
                    captureMode: captureMode, startupError: startupError, snapshot: snapshot,
                    onCancel: { showsRecorder = false }, onUseTrigger: { trigger in
                        recordedTrigger = trigger
                        draft = nil
                        showsRecorder = false
                    })
            }
    }

    private func parse() {
        do {
            draft = try AutomationDraftParser().parse(sentence, applications: applications, recordedTrigger: recordedTrigger)
            error = nil
        } catch {
            draft = nil
            self.error = error.localizedDescription
        }
    }
}
