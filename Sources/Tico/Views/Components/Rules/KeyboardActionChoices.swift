import SwiftUI

/// Atalhos usuais são escolhidos pelo objetivo. A edição técnica permanece
/// disponível para combinações fora dessa seleção, sem alterar seus valores.
struct KeyboardActionChoices: View {
    let keyCode: UInt16
    let modifiers: Set<InputModifier>
    let onSelect: (UInt16, Set<InputModifier>) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(RuleEditorSummary.trigger(.keyboard(keyCode: keyCode, modifiers: modifiers)), systemImage: "keyboard")
                .font(.title3.monospaced())
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(KeyboardActionPreset.allCases) { value in
                    EditorChoiceButton(title: value.title, symbol: value.symbol,
                        isSelected: keyCode == value.keyCode && modifiers == [.command]) {
                        onSelect(value.keyCode, [.command])
                    }
                }
            }
            DisclosureGroup("Personalizar combinação") {
                VStack(alignment: .leading, spacing: 10) {
                    Stepper("Código da tecla: \(keyCode)", value: Binding(
                        get: { keyCode }, set: { onSelect($0, modifiers) }), in: 0...255)
                    HStack {
                        ForEach(InputModifier.allCases, id: \.self) { modifier in
                            Toggle(modifier.symbol, isOn: Binding(
                                get: { modifiers.contains(modifier) },
                                set: { enabled in
                                    var value = modifiers
                                    if enabled { value.insert(modifier) } else { value.remove(modifier) }
                                    onSelect(keyCode, value)
                                }
                            )).toggleStyle(.button).help(modifier.displayName)
                        }
                    }
                }.padding(.top, 8)
            }.font(.callout)
        }
    }
}
