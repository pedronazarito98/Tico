import SwiftUI

/// Uma frase pode nascer de escolhas, do parser ou do modelo local da Apple. A proposta é sempre
/// efêmera; o callback abre o editor e a persistência continua pertencendo ao shell.
struct DescribeAutomationView: View {
    let intelligenceService: any LocalIntelligenceServicing
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
    @State private var mode = DescriptionInputMode.guided
    @State private var phrase = DescriptionPhraseDraft()
    @State private var editingPart: DescriptionEditingPart? = .trigger
    @State private var sentence = ""
    @State private var recordedTrigger: TriggerDefinition?
    @State private var draft: ShortcutRule?
    @State private var error: String?
    @State private var showsRecorder = false

    private var scopeTitle: String {
        guard let id = phrase.scopeApplicationID else { return "qualquer aplicativo" }
        return applications.first { $0.id == id }?.name ?? "aplicativo indisponível"
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Uma ideia vira um atalho").font(.title2.weight(.semibold))
                Text("Monte a frase e confira a proposta antes de personalizar.")
                    .font(.callout).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    modeButton(.guided, title: "Montar com escolhas")
                    modeButton(.text, title: "Escrever uma frase")
                    modeButton(.intelligence, title: "Linguagem natural")
                    Spacer()
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if mode == .guided { guidedPhrase }
                    else if mode == .text { textPhrase }
                    else {
                        NaturalAutomationView(service: intelligenceService, applications: applications,
                            recordedTrigger: recordedTrigger, onRecord: startRecording,
                            onCreate: { onCreate($0); dismiss() })
                    }
                    if let error {
                        Label(error, systemImage: "info.circle").font(.callout).foregroundStyle(.orange)
                    }
                    if mode != .intelligence, let draft {
                        AutomationProposalView(draft: draft, applications: applications,
                            onReview: mode == .text ? { self.draft = nil } : nil)
                    }
                }.padding(20)
            }
            Divider()
            HStack {
                Button("Cancelar") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                if mode != .intelligence {
                    Button(draft == nil ? "Conferir proposta" : "Personalizar no editor", action: continueEditing)
                        .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                        .accessibilityIdentifier(draft == nil ? "tico.describe.parse" : "tico.describe.review")
                }
            }.padding(20)
        }
        .adaptiveSheetFrame(idealWidth: 660, idealHeight: 700)
        .onChange(of: phrase) { refreshGuidedProposal() }
        .onChange(of: sentence) { draft = nil; error = nil }
        .onChange(of: mode) {
            draft = nil
            error = nil
            if mode == .guided { refreshGuidedProposal() }
        }
        .onChange(of: applications) { if mode == .guided { refreshGuidedProposal() } else { draft = nil } }
        .onDisappear { if showsRecorder { onStopRecording() } }
        .sheet(isPresented: $showsRecorder, onDismiss: onStopRecording) {
            TriggerRecorderView(mode: .standard, suggestedName: "Meu acionamento",
                isRecording: recordingIsActive, latestEvent: latestEvent,
                captureMode: captureMode, startupError: startupError, snapshot: snapshot,
                onCancel: { showsRecorder = false }, onUseTrigger: { trigger in
                    recordedTrigger = trigger
                    showsRecorder = false
                    if mode == .guided { refreshGuidedProposal() } else { draft = nil }
                })
        }
    }

    private var guidedPhrase: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                sentencePart("Quando eu", value: phrase.gestureTitle(recordedTrigger: recordedTrigger), part: .trigger)
                sentencePart("em", value: scopeTitle, part: .scope)
                sentencePart("quero", value: phrase.actionTitle(applications: applications), part: .action)
            }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                .background(TicoBrand.Palette.primary.opacity(0.06), in: .rect(cornerRadius: 12))
            if let editingPart {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(editingPart.title).font(.headline)
                        Spacer()
                        Button { self.editingPart = nil } label: { Image(systemName: "xmark") }
                            .buttonStyle(.plain).accessibilityLabel("Fechar opções de \(editingPart.title)")
                    }
                    switch editingPart {
                    case .trigger: triggerChoices
                    case .scope: scopeChoices
                    case .action: actionChoices
                    }
                }
            }
        }
    }

    private func sentencePart(_ prefix: String, value: String, part: DescriptionEditingPart) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(prefix).foregroundStyle(.secondary)
            Button { editingPart = editingPart == part ? nil : part } label: {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(value).fontWeight(.medium).multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "chevron.down").font(.caption)
                }
            }.buttonStyle(.plain).foregroundStyle(TicoBrand.Palette.primary)
                .accessibilityLabel("\(prefix) \(value). Alterar \(part.title)")
        }
    }

    private var triggerChoices: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), alignment: .leading)], spacing: 8) {
                ForEach(DescriptionGestureChoice.allCases) { choice in
                    choiceButton(choice.title, symbol: choice.symbol, selected: phrase.gesture == choice) {
                        phrase.gesture = choice
                        if choice == .recorded, recordedTrigger == nil { startRecording() }
                    }
                }
            }
            if phrase.gesture == .recorded {
                HStack {
                    Text(recordedTrigger?.displayName ?? "Grave um acionamento para usar nesta frase.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(recordedTrigger == nil ? "Gravar" : "Gravar novamente", action: startRecording)
                }
            } else {
                HStack(spacing: 8) {
                    Text("Dedos").font(.callout).foregroundStyle(.secondary)
                    ForEach(2...5, id: \.self) { count in
                        Button("\(count)") { phrase.fingerCount = count }
                            .buttonStyle(.bordered)
                            .tint(phrase.fingerCount == count ? TicoBrand.Palette.primary : .secondary)
                            .accessibilityLabel("\(count) dedos")
                            .accessibilityAddTraits(phrase.fingerCount == count ? .isSelected : [])
                    }
                }
            }
        }
    }

    private var scopeChoices: some View {
        VStack(alignment: .leading, spacing: 12) {
            choiceButton("Qualquer aplicativo", symbol: "globe", selected: phrase.scopeApplicationID == nil) {
                phrase.scopeApplicationID = nil
                editingPart = nil
            }
            ApplicationBrowserView(applications: applications,
                selectedIDs: Set(phrase.scopeApplicationID.map { [$0] } ?? [])) { id in
                    phrase.scopeApplicationID = id
                    editingPart = nil
                }
        }
    }

    private var actionChoices: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), alignment: .leading)], spacing: 8) {
                ForEach(DescriptionActionChoice.allCases) { choice in
                    choiceButton(choice.title, symbol: choice.symbol, selected: phrase.action == choice) {
                        phrase.action = choice
                        if choice != .openApplication && choice != .openURL { editingPart = nil }
                    }
                }
            }
            if phrase.action == .openApplication {
                ApplicationBrowserView(applications: applications, selectedIDs: [phrase.targetApplicationID]) { id in
                    phrase.targetApplicationID = id
                    editingPart = nil
                }
            } else if phrase.action == .openURL {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Endereço do site").font(.callout.weight(.medium))
                    TextField("https://", text: $phrase.targetURL).textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Endereço completo do site")
                    Text("Informe o destino que você quer abrir. A proposta mostra o endereço antes de continuar.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var textPhrase: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Frases reconhecidas no Mac, sem envio para IA", systemImage: "desktopcomputer")
                .font(.callout).foregroundStyle(.secondary)
            Text("Este modo entende as estruturas abaixo. Para outras combinações, use as escolhas ou personalize no editor.")
                .font(.callout).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Button("Janela à esquerda") { useExample("Quando eu fizer um swipe para a esquerda com 3 dedos em qualquer aplicativo, coloque a janela na metade esquerda") }
                Button("Ampliar janela") { useExample("Quando eu fizer um toque com 4 dedos em qualquer aplicativo, maximize a janela") }
            }
            TextField("Quando eu fizer…", text: $sentence, axis: .vertical)
                .lineLimit(3...6).textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("tico.describe.sentence")
            HStack {
                Button(recordedTrigger == nil ? "Gravar ‘este gesto’" : "Gravar novamente", action: startRecording)
                if let recordedTrigger { Text(recordedTrigger.displayName).font(.caption).foregroundStyle(.secondary) }
            }
            DisclosureGroup("O que a frase pode descrever") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Quando eu fizer [um toque com 3 dedos / um swipe para a esquerda com 3 dedos / este gesto] no [nome do app] ou em qualquer aplicativo, [ação].")
                    Text("Ações: coloque a janela na metade esquerda/direita; maximize a janela; centralize a janela; reabra a última aba; atualize a página ou janela; abra o [nome do app]; abra [link HTTP ou HTTPS].")
                    Text("Deslizamentos e toques aceitam de 2 a 5 dedos. Para outro acionamento, grave e escreva ‘este gesto’. Nomes de aplicativos precisam corresponder a um único app instalado.")
                }.font(.caption).foregroundStyle(.secondary).padding(.top, 8)
            }
        }
    }

    private func modeButton(_ value: DescriptionInputMode, title: String) -> some View {
        Button(title) { mode = value }.buttonStyle(.bordered)
            .tint(mode == value ? TicoBrand.Palette.primary : .secondary)
            .accessibilityAddTraits(mode == value ? .isSelected : [])
    }
    private func choiceButton(_ title: String, symbol: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading).padding(8).contentShape(Rectangle())
        }.buttonStyle(.plain)
            .background(selected ? TicoBrand.Palette.primary.opacity(0.1) : Color.primary.opacity(0.025),
                        in: .rect(cornerRadius: 8))
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
    private func refreshGuidedProposal() {
        guard mode == .guided else { return }
        draft = try? phrase.makeRule(applications: applications, recordedTrigger: recordedTrigger)
        error = nil
    }
    private func useExample(_ text: String) {
        sentence = text
        draft = nil
        error = nil
    }
    private func continueEditing() {
        if let draft {
            onCreate(draft)
            dismiss()
            return
        }
        do {
            draft = try mode == .guided
                ? phrase.makeRule(applications: applications, recordedTrigger: recordedTrigger)
                : AutomationDraftParser().parse(sentence, applications: applications, recordedTrigger: recordedTrigger)
            error = nil
        } catch { self.error = error.localizedDescription; draft = nil }
    }
    private func startRecording() {
        if onStartRecording() { showsRecorder = true; error = nil }
        else { error = startupError ?? "O reconhecimento está indisponível. Você pode escolher um movimento sem gravar." }
    }
}

private enum DescriptionInputMode { case guided, text, intelligence }
private enum DescriptionEditingPart {
    case trigger, scope, action
    var title: String {
        switch self {
        case .trigger: "Acionamento"
        case .scope: "Onde funciona"
        case .action: "Resultado"
        }
    }
}
