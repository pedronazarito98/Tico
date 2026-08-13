import SwiftUI

struct RuleEditorFooterView: View {
    let hasUnsavedChanges: Bool
    let canSave: Bool
    let presets: [GesturePreset]
    let onDelete: () -> Void
    let onRevert: () -> Void
    let onSaveAsPreset: () -> Void
    let onApplyPreset: (GesturePreset) -> Void
    let onSave: () -> Void

    var body: some View {
        HStack {
            Button("Excluir", role: .destructive, action: onDelete)
            Spacer()
            Button("Reverter", action: onRevert)
                .disabled(!hasUnsavedChanges)
            Menu {
                Button("Salvar regra como preset", action: onSaveAsPreset)
                if !presets.isEmpty {
                    Divider()
                    ForEach(presets) { preset in
                        Button("Aplicar “\(preset.name)”") {
                            onApplyPreset(preset)
                        }
                    }
                }
            } label: {
                Label("Preset", systemImage: "square.stack.3d.up")
            }
            Button("Salvar", action: onSave)
                .buttonStyle(.borderedProminent)
                .disabled(!canSave || !hasUnsavedChanges)
                .keyboardShortcut("s", modifiers: [.command])
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
    }
}
