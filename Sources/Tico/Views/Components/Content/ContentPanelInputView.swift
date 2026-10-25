import SwiftUI

struct ContentPanelInputView: View {
    @ObservedObject var session: ContentPanelSession
    let onChooseFiles: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch session.kind {
            case .text:
                TextField("Cole ou escreva o texto aqui", text: $session.text, axis: .vertical)
                    .textFieldStyle(.plain).lineLimit(3...6)
                    .accessibilityIdentifier("tico.content.text")
            case .webURL:
                Text("Link").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                TextField("https://…", text: $session.text)
                    .textFieldStyle(.plain).accessibilityIdentifier("tico.content.url")
            case .files:
                if session.files.isEmpty {
                    Button(action: onChooseFiles) {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.badge.plus").font(.title2)
                            Text("Arraste arquivos ou escolha no Mac")
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }.frame(maxWidth: .infinity, minHeight: 70).contentShape(.rect)
                    }.buttonStyle(.plain)
                } else {
                    ForEach(session.files, id: \.self) { url in
                        HStack {
                            Label(url.lastPathComponent, systemImage: "doc").lineLimit(1)
                            Spacer()
                            Button("Remover arquivo", systemImage: "xmark.circle") { session.removeFile(url) }
                                .labelStyle(.iconOnly).buttonStyle(.plain)
                        }
                    }
                    Button("Adicionar arquivos…", action: onChooseFiles).buttonStyle(.borderless)
                }
                Text("Até 20 arquivos de 100 MB cada.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
