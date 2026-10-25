import SwiftUI

/// Seleção manual com nomes, compartilhada pelos editores compactos legados.
struct KeyboardShortcutPicker: View {
    @Binding var keyCode: UInt16
    @Binding var modifiers: Set<InputModifier>
    @State private var showsKeyboard = false
    @State private var availableWidth: CGFloat = 600
    var body: some View {
        (availableWidth < 480 ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                             : AnyLayout(HStackLayout(spacing: 12))) {
            TriggerKeycaps(trigger: .keyboard(keyCode: keyCode, modifiers: modifiers))
            Button("Escolher tecla…") { showsKeyboard = true }
                .fixedSize()
                .popover(isPresented: $showsKeyboard) {
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Escolha as teclas").font(.headline)
                            Text("Clique nos modificadores e em uma tecla.").foregroundStyle(.secondary)
                        }.padding(20)
                        Divider()
                        ScrollView {
                            VisualKeyboardView(keyCode: keyCode, modifiers: modifiers, onSelect: select)
                                .padding(20)
                        }
                        Divider()
                        HStack {
                            Spacer()
                            Button("Concluir") { showsKeyboard = false }.buttonStyle(.borderedProminent)
                        }.padding(16)
                    }.adaptiveSheetFrame(idealWidth: 720, idealHeight: 460)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { availableWidth = $0 }
    }
    private func select(_ code: UInt16) {
        if let modifier = InputPresentation.modifierKeys[code] {
            if modifiers.contains(modifier) { modifiers.remove(modifier) } else { modifiers.insert(modifier) }
        } else { keyCode = code }
    }
}
