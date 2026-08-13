import SwiftUI
import UniformTypeIdentifiers

struct TrackpadSessionView: View {
    let isRecording: Bool
    let recordedFrameCount: Int
    let lastRecording: TrackpadReplayDocument?
    let isReplaying: Bool
    let replayProgress: Double
    let onStartRecording: (String) -> Void
    let onStopRecording: () -> TrackpadReplayDocument?
    let onCancelRecording: () -> Void
    let onReplay: (TrackpadReplayDocument, Double) -> Void
    let onCancelReplay: () -> Void

    @State private var sessionName = "Sessão do Trackpad"
    @State private var importedDocument: TrackpadReplayDocument?
    @State private var exportDocument: TrackpadReplayFileDocument?
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var playbackSpeed = 1.0
    @State private var presentedError: String?

    var body: some View {
        Form {
            Section("Gravar sessão real") {
                TextField("Nome", text: $sessionName)
                    .disabled(isRecording)
                HStack {
                    if isRecording {
                        Button("Finalizar gravação") {
                            _ = onStopRecording()
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Descartar", role: .destructive, action: onCancelRecording)
                    } else {
                        Button {
                            onStartRecording(sessionName)
                        } label: {
                            Label("Gravar contatos", systemImage: "record.circle")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                    Text("\(recordedFrameCount) frames")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Text("Frames são mantidos apenas durante a gravação. Identificadores de dispositivo são anonimizados antes da exportação.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Exportar") {
                if let lastRecording {
                    LabeledContent("Última sessão", value: lastRecording.name)
                    LabeledContent("Frames", value: "\(lastRecording.frames.count)")
                    Button("Exportar JSON…") {
                        exportDocument = TrackpadReplayFileDocument(replay: lastRecording)
                        showingExporter = true
                    }
                } else {
                    Text("Finalize uma gravação para habilitar a exportação.")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Importar e reproduzir") {
                HStack {
                    Button("Importar fixture…") {
                        showingImporter = true
                    }
                    if let importedDocument {
                        Text(importedDocument.name)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Picker("Velocidade", selection: $playbackSpeed) {
                            Text("0,5×").tag(0.5)
                            Text("1×").tag(1.0)
                            Text("2×").tag(2.0)
                        }
                        .frame(width: 130)
                        if isReplaying {
                            Button("Cancelar", action: onCancelReplay)
                        } else {
                            Button("Reproduzir") {
                                onReplay(importedDocument, playbackSpeed)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
                if isReplaying {
                    ProgressView(value: replayProgress) {
                        Text("Reproduzindo sessão")
                    }
                }
                Text("O replay usa o mesmo motor e a calibração atual, mas nunca executa regras.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            do {
                let url = try result.get().first
                guard let url else { throw TrackpadFrameProviderError.invalidReplay }
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                importedDocument = try ReplayFrameProvider(contentsOf: url).document
            } catch {
                presentedError = error.localizedDescription
            }
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument,
            contentType: .json,
            defaultFilename: safeFilename
        ) { result in
            if case let .failure(error) = result {
                presentedError = error.localizedDescription
            }
        }
        .alert("Sessão do Trackpad", isPresented: errorBinding) {
            Button("OK", role: .cancel) { presentedError = nil }
        } message: {
            Text(presentedError ?? "Erro desconhecido")
        }
    }

    private var safeFilename: String {
        let value = lastRecording?.name ?? "trackpad-session"
        return value.replacingOccurrences(of: "/", with: "-")
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { presentedError != nil },
            set: { if !$0 { presentedError = nil } }
        )
    }
}
