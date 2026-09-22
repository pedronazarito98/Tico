import SwiftUI

struct RuleEditorFooterView: View {
    let hasUnsavedChanges: Bool
    let canSave: Bool
    let presets: [GesturePreset]
    let onDelete: () -> Void
    let onPractice: () -> Void
    let onRevert: () -> Void
    let onSaveAsPreset: () -> Void
    let onApplyPreset: (GesturePreset) -> Void
    let onSave: () -> Void

    var body: some View {
        HStack {
            Menu {
                Button("Reverter alterações", action: onRevert).disabled(!hasUnsavedChanges)
                Button("Salvar como modelo", action: onSaveAsPreset).disabled(!canSave)
                if !presets.isEmpty {
                    Section("Usar modelo") {
                        ForEach(presets) { preset in
                            Button("Aplicar “\(preset.name)”") { onApplyPreset(preset) }
                        }
                    }
                }
                Divider()
                Button("Excluir atalho", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton).fixedSize()
            .accessibilityLabel("Mais opções do atalho")
            Button("Praticar", systemImage: "hand.draw", action: onPractice)
                .help("Teste o reconhecimento sem executar as ações")
            Spacer()
            Button("Salvar", action: onSave)
                .buttonStyle(.glassProminent)
                .disabled(!canSave || !hasUnsavedChanges)
                .keyboardShortcut("s", modifiers: [.command])
                .accessibilityIdentifier("tico.rule.save")
        }
        .controlSize(.small)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
