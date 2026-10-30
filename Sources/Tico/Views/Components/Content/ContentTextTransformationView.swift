import SwiftUI

/// A entrada original permanece acima da revisão. A saída editável só chega ao
/// painel ou ao clipboard por um botão explícito; nunca substitui seleção externa.
struct ContentTextTransformationView: View {
    @ObservedObject var session: ContentPanelSession
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Transformar texto", systemImage: "sparkles").font(.headline)
            Text(session.intelligenceAvailability.message).font(.caption).foregroundStyle(.secondary)
                .accessibilityIdentifier("tico.content.ai-availability")
            if session.intelligenceAvailability != .available {
                Button("Verificar novamente") { Task { await session.refreshIntelligenceAvailability() } }
                    .disabled(session.isRunning)
            }
            Text("Textos curtos, até 2 KB. Você confere o resultado antes de usar.")
                .font(.caption).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), alignment: .leading)], alignment: .leading, spacing: 8) {
                ForEach(ContentTransformation.allCases) { operation in
                    Button(operation.title) { session.transform(operation) }
                        .buttonStyle(.bordered)
                        .disabled(session.isRunning || session.content == nil || session.intelligenceAvailability != .available)
                        .accessibilityIdentifier("tico.content.ai-\(operation.rawValue)")
                }
            }
            if session.isGenerating {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("Preparando texto para revisão…").font(.callout)
                }
            }
            if session.generatedText != nil {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Revise o texto gerado").font(.headline)
                    Text("O original continua no campo acima. Você pode editar esta proposta.")
                        .font(.caption).foregroundStyle(.secondary)
                    TextEditor(text: Binding(get: { session.generatedText ?? "" }, set: { session.generatedText = $0 }))
                        .font(.body).frame(minHeight: 140, maxHeight: 220)
                        .accessibilityLabel("Texto gerado para revisão")
                        .accessibilityIdentifier("tico.content.ai-result")
                    if !session.generatedTextIsValid {
                        Text("A revisão precisa conter texto e respeitar o limite de 64 KB.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack { reviewActions }
                        VStack(alignment: .leading) { reviewActions }
                    }
                }.padding(14)
                    .background(TicoBrand.Palette.surface, in: .rect(cornerRadius: 10))
            }
        }
        .task { await session.refreshIntelligenceAvailability() }
        .onChange(of: scenePhase) {
            if scenePhase == .active { Task { await session.refreshIntelligenceAvailability() } }
        }
    }

    @ViewBuilder private var reviewActions: some View {
        Button("Usar no painel", action: session.useGeneratedText)
            .buttonStyle(.borderedProminent).disabled(!session.generatedTextIsValid || session.isRunning)
            .accessibilityIdentifier("tico.content.ai-use")
        Button("Copiar", action: session.copyGeneratedText)
            .disabled(!session.generatedTextIsValid || session.isRunning)
            .accessibilityIdentifier("tico.content.ai-copy")
        Button("Descartar", action: session.discardGeneratedText)
            .disabled(session.isRunning).accessibilityIdentifier("tico.content.ai-discard")
    }
}
