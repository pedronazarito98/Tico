import SwiftUI

struct RuleEditorHeaderView: View {
    @Binding var name: String
    @Binding var isEnabled: Bool
    let hasUnsavedChanges: Bool

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Nome da regra", text: $name)
                    .textFieldStyle(.plain)
                    .font(.title2.weight(.semibold))
                Text(hasUnsavedChanges ? "Alterações não salvas" : "Regra atualizada")
                    .font(.caption)
                    .foregroundStyle(hasUnsavedChanges ? .orange : .secondary)
            }
            Spacer()
            Toggle("Ativa", isOn: $isEnabled)
                .toggleStyle(.switch)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }
}
