import SwiftUI

struct RuleEditorHeaderView: View {
    @Binding var name: String
    @Binding var isEnabled: Bool
    let hasUnsavedChanges: Bool

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Nome da regra", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .semibold))
                    .accessibilityIdentifier("tico.rule.name")
                Text(hasUnsavedChanges ? "Alterações não salvas" : "Atalho salvo")
                    .font(.caption)
                    .foregroundStyle(hasUnsavedChanges ? .orange : .secondary)
            }
            Spacer()
            Toggle("Ativa", isOn: $isEnabled)
                .toggleStyle(.switch)
                .accessibilityIdentifier("tico.rule.enabled")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}
