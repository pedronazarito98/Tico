import SwiftUI

/// Miniatura derivada dos valores da prévia, sem capturas de tela nem conteúdo de
/// janelas. A mesma geometria normalizada usada na execução desenha o resultado.
struct SceneLayoutCanvas: View {
    let preview: SceneLayoutPreview
    let showsTarget: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(showsTarget ? "Depois" : "Agora").font(.headline)
            // Cada tela mantém proporção e espaço legível. Novas linhas evitam
            // reduzir todas as miniaturas quando há várias telas conectadas.
            LazyVGrid(columns: displayColumns, alignment: .leading, spacing: 12) {
                ForEach(preview.displays) { display in
                    VStack(alignment: .leading, spacing: 6) {
                        GeometryReader { geometry in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.quaternary.opacity(0.5))
                            ForEach(Array(preview.windows.enumerated()), id: \.element.id) { index, window in
                                if let frame = frame(for: window, on: display) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(TicoBrand.Palette.primary.opacity(0.16))
                                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(TicoBrand.Palette.primary, lineWidth: 1))
                                        .overlay(alignment: .topLeading) {
                                            Text("\(index + 1)").font(.caption2.bold()).padding(4)
                                        }
                                        .frame(width: max(1, frame.width * geometry.size.width),
                                               height: max(1, frame.height * geometry.size.height))
                                        .offset(x: frame.x * geometry.size.width, y: frame.y * geometry.size.height)
                                }
                            }
                        }.aspectRatio(display.frame.width / display.frame.height, contentMode: .fit)
                            .frame(maxHeight: 160).clipped()
                        Text(display.role.label + (display.isPrimary ? " · Principal" : ""))
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary)
    }

    private var displayColumns: [GridItem] {
        [GridItem(preview.displays.count == 1 ? .flexible() : .adaptive(minimum: 160), alignment: .top)]
    }

    private var accessibilitySummary: String {
        let details = preview.windows.compactMap { window -> String? in
            let role = showsTarget ? window.targetDisplay : window.sourceDisplay
            guard let display = preview.displays.first(where: { $0.role == role }),
                  let normalized = frame(for: window, on: display) else { return nil }
            return "\(window.applicationName), \(display.role.label): esquerda \(Int(normalized.x * 100))%, topo \(Int(normalized.y * 100))%, largura \(Int(normalized.width * 100))%, altura \(Int(normalized.height * 100))%."
        }.joined(separator: " ")
        return (showsTarget ? "Disposição planejada. " : "Disposição atual. ") + details
    }

    private func frame(for window: SceneLayoutPreviewWindow, on display: SceneLayoutDisplay) -> SceneLayoutRect? {
        let role = showsTarget ? window.targetDisplay : window.sourceDisplay
        guard role == display.role, let frame = showsTarget ? window.targetFrame : window.sourceFrame else { return nil }
        return frame.normalized(in: display.frame)
    }
}
