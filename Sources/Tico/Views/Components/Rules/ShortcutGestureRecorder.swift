import SwiftUI

/// Captura guiada de um gesto. A confirmação aguarda o fim do contato para
/// não aceitar um swipe parcial. Teclado/mouse continuam no gravador completo.
struct ShortcutGestureRecorder: View {
    let latestEvent: InputEventDescriptor?
    let snapshot: TrackpadLaboratorySnapshot?
    let isRecording: Bool
    let startupError: String?
    let onCancel: () -> Void
    let onUseTrigger: (TriggerDefinition) -> Void
    @State private var startedAt = Date()
    @State private var candidate: InputEventDescriptor?
    @State private var didFinish = false

    private var liveSnapshot: TrackpadLaboratorySnapshot? {
        guard let snapshot, snapshot.features.occurredAt >= startedAt else { return nil }
        return snapshot
    }
    private var fingers: Int { liveSnapshot?.features.maximumFingerCount ?? candidate?.fingerCount ?? 0 }

    private var movementDescription: String {
        if let trigger = candidate?.triggerDefinition { return RuleEditorSummary.trigger(trigger) }
        guard let displacement = liveSnapshot?.features.displacement,
              max(abs(displacement.x), abs(displacement.y)) > 0.04 else {
            return "Deslize, toque ou faça uma pinça."
        }
        if abs(displacement.x) >= abs(displacement.y) {
            return displacement.x < 0 ? "Deslizando para a esquerda…" : "Deslizando para a direita…"
        }
        return displacement.y < 0 ? "Deslizando para baixo…" : "Deslizando para cima…"
    }

    var body: some View {
        VStack(spacing: 0) {
          VStack(spacing: 8) {
              Text("Gravar gesto").font(.title.bold())
              Text("Faça o movimento no trackpad.").foregroundStyle(.secondary)
          }.padding(20)
          Divider()
          ScrollView {
            VStack(spacing: 18) {
            Label(isRecording ? "Gravando" : "Captura indisponível", systemImage: "record.circle.fill")
                .foregroundStyle(isRecording ? .red : .secondary)
            ZStack {
                ShortcutGesturePreview(trigger: candidate?.triggerDefinition, height: 190)
                if let path = liveSnapshot?.features.centroidPath, path.count > 1 {
                    GesturePathPreview(path: path).padding(12)
                }
            }.frame(width: 310)
            Text(fingers > 0 ? "\(fingers) dedos detectados" : "Aguardando seu gesto…").font(.headline)
            Text(movementDescription).foregroundStyle(.secondary)
            Text(startupError ?? "Solte os dedos para concluir.")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity).padding(20)
          }
            Divider()
            Button("Cancelar gravação", action: onCancel)
                .buttonStyle(.glass).keyboardShortcut(.cancelAction)
                .padding(16)
        }
        .adaptiveSheetFrame(idealWidth: 450, idealHeight: 580)
        .onChange(of: latestEvent) { _, event in receive(event) }
        .onChange(of: snapshot?.phase) { finishIfReleased() }
    }

    private func receive(_ event: InputEventDescriptor?) {
        guard isRecording, let event, event.timestamp >= startedAt,
              event.kind == .trackpadGesture, event.triggerDefinition != nil else { return }
        if event.gestureEvent?.phase == .cancelled { candidate = nil; return }
        candidate = event
        finishIfReleased()
    }

    private func finishIfReleased() {
        guard !didFinish, let event = candidate, let trigger = event.triggerDefinition else { return }
        if let snapshot = liveSnapshot, snapshot.sessionID == event.gestureEvent?.sessionID {
            guard snapshot.phase != .cancelled else { candidate = nil; return }
            guard snapshot.phase == .ended || snapshot.features.activeFingerCount == 0 else { return }
        } else if let gesture = event.gestureEvent {
            guard gesture.phase == .ended else { return }
        }
        didFinish = true
        onUseTrigger(trigger)
    }
}
