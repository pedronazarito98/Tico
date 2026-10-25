import SwiftUI

/// Inspector da janela selecionada; precisão e papéis de tela ficam disponíveis
/// sem exigir que a pessoa os configure para escolher uma posição comum.
struct SceneLayoutWindowEditor: View {
    @Binding var window: SceneLayoutWindow
    let onRemove: () -> Void
    @State private var showsPrecision = false
    @State private var usesCompactFields = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(window.applicationName).font(.headline).fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button("Remover", systemImage: "minus.circle", role: .destructive, action: onRemove)
                    .buttonStyle(.borderless)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0)), count: 3), spacing: 8) {
                position("Esquerda", operation: .leftHalf, frame: .left)
                position("Inteira", operation: .maximize, frame: .full)
                position("Direita", operation: .rightHalf, frame: .right)
            }.controlSize(.small)
            Menu("Mais posições") {
                Button("Metade superior") { window.frame = .init(x: 0, y: 0, width: 1, height: 0.5) }
                Button("Metade inferior") { window.frame = .init(x: 0, y: 0.5, width: 1, height: 0.5) }
                Button("Terço esquerdo") { window.frame = .init(x: 0, y: 0, width: 1.0 / 3, height: 1) }
                Button("Terço central") { window.frame = .init(x: 1.0 / 3, y: 0, width: 1.0 / 3, height: 1) }
                Button("Terço direito") { window.frame = .init(x: 2.0 / 3, y: 0, width: 1.0 / 3, height: 1) }
            }.fixedSize().controlSize(.small)
            DisclosureGroup("Tela e escolha da janela") {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("Tela de destino", selection: $window.display) {
                        ForEach(SceneLayoutDisplayRole.allCases) { Text($0.label).tag($0) }
                    }
                    Text("Você também pode planejar para uma tela desconectada. A disponibilidade será conferida antes de aplicar.")
                        .font(.caption).foregroundStyle(.secondary)
                    Picker("Qual janela usar", selection: $window.selection) {
                        ForEach(SceneLayoutWindowSelection.allCases, id: \.self) { Text($0.label).tag($0) }
                    }.pickerStyle(.radioGroup)
                }.padding(.top, 8)
            }.font(.callout)
            DisclosureGroup("Posição e tamanho em porcentagem", isExpanded: $showsPrecision) {
                LazyVGrid(columns: precisionColumns, alignment: .leading, spacing: 10) {
                    field("Esquerda", \.x)
                    field("Largura", \.width)
                    field("Topo", \.y)
                    field("Altura", \.height)
                }.padding(.top, 8)
            }.font(.caption)
        }.padding(12).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
            .onGeometryChange(for: Bool.self) { $0.size.width < 380 } action: { usesCompactFields = $0 }
    }

    /// Mantém os pares posição/tamanho em duas colunas quando couberem. Os
    /// campos mantêm a mesma identidade, mesmo quando passam a uma coluna.
    private var precisionColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 0), alignment: .leading), count: usesCompactFields ? 1 : 2)
    }

    private func position(_ title: String, operation: WindowOperation, frame: SceneLayoutRect) -> some View {
        Button { window.frame = frame } label: {
            VStack(spacing: 6) {
                WindowPlacementPreview(operation: operation).frame(maxWidth: 80).frame(height: 46)
                Text(title).font(.caption)
            }
            .padding(8).frame(maxWidth: .infinity)
            .background(window.frame == frame ? TicoBrand.Palette.primary.opacity(0.12) : .clear, in: .rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(window.applicationName): \(title)")
        .accessibilityAddTraits(window.frame == frame ? [.isSelected] : [])
    }

    private func field(_ title: String, _ keyPath: WritableKeyPath<SceneLayoutRect, Double>) -> some View {
        HStack {
            Text(title)
            TextField(title, value: percentage(keyPath), format: .number.precision(.fractionLength(0...1)))
                .textFieldStyle(.roundedBorder).frame(width: 65)
            Text("%")
        }
    }

    private func percentage(_ keyPath: WritableKeyPath<SceneLayoutRect, Double>) -> Binding<Double> {
        Binding(get: { window.frame[keyPath: keyPath] * 100 }, set: { value in
            guard value.isFinite else { return }
            var frame = window.frame
            frame[keyPath: keyPath] = min(max(value / 100, 0), 1)
            if keyPath == \.x { frame.x = min(frame.x, 1 - frame.width) }
            if keyPath == \.y { frame.y = min(frame.y, 1 - frame.height) }
            if keyPath == \.width { frame.width = min(max(frame.width, 0.05), 1 - frame.x) }
            if keyPath == \.height { frame.height = min(max(frame.height, 0.05), 1 - frame.y) }
            window.frame = frame
        })
    }
}
