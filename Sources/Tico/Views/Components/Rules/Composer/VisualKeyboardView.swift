import SwiftUI

/// Teclas são controles reais, acessíveis por foco e clique. A captura apenas
/// destaca o estado físico; selecionar no desenho configura a mesma combinação.
struct VisualKeyboardView: View {
    let keyCode: UInt16?
    let modifiers: Set<InputModifier>
    var pressedKeys: Set<UInt16> = []
    var liveModifiers: Set<InputModifier> = []
    var isRecording = false
    var onSelect: ((UInt16) -> Void)?

    var body: some View {
      GeometryReader { geometry in
        // O teclado conserva alvos legíveis. Em uma sheet estreita a pessoa
        // percorre as teclas horizontalmente, sem diminuir fonte nem área de clique.
        ScrollView(.horizontal) {
          VStack(spacing: 6) {
            ForEach(Array(InputPresentation.rows.enumerated()), id: \.offset) { row, keys in
                KeyboardRowView(keys: keys, keyCode: keyCode, modifiers: modifiers,
                    pressedKeys: pressedKeys, liveModifiers: liveModifiers, isRecording: isRecording,
                    onSelect: onSelect, compact: row == 0)
            }
          }
          .padding(12)
          .frame(width: max(660, geometry.size.width))
        .background(TicoBrand.Palette.surface, in: .rect(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(.primary.opacity(0.12)) }
        .shadow(color: .black.opacity(0.07), radius: 12, y: 8)
        .accessibilityElement(children: .contain).accessibilityLabel("Teclado visual")
        }
        .scrollIndicators(.visible)
      }
      .frame(height: CGFloat(InputPresentation.rows.count - 1) * 42 + 48)
    }

}

/// Distribui larguras relativas sem medir a janela pelo AppKit.
private struct KeyboardRowView: View {
    let keys: [UInt16]
    let keyCode: UInt16?
    let modifiers: Set<InputModifier>
    let pressedKeys: Set<UInt16>
    let liveModifiers: Set<InputModifier>
    let isRecording: Bool
    let onSelect: ((UInt16) -> Void)?
    let compact: Bool
    var body: some View {
        GeometryReader { geometry in
            let unit = max(0, (geometry.size.width - CGFloat(keys.count - 1) * 5) / keys.reduce(0) { $0 + InputPresentation.width($1) })
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(keys, id: \.self) { code in
                    if code == 125 {
                        VStack(spacing: 2) {
                            key(126, width: unit, height: 17)
                            key(125, width: unit, height: 17)
                        }
                    } else {
                        key(code, width: unit * InputPresentation.width(code),
                            height: compact ? 24 : (code == 123 || code == 124 ? 17 : 36))
                    }
                }
            }
        }.frame(height: compact ? 24 : 36)
    }
    private func key(_ code: UInt16, width: CGFloat, height: CGFloat) -> some View {
        let modifier = InputPresentation.modifierKeys[code]
        let active = isRecording ? pressedKeys.contains(code)
            : (keyCode == code || modifier.map(modifiers.contains) == true)
        return Button { onSelect?(code) } label: {
            Text(InputPresentation.label(code))
                .font(.system(size: compact ? 10 : 12, weight: active ? .semibold : .regular))
                .foregroundStyle(active ? Color.white : TicoBrand.Palette.text)
                .frame(width: width, height: height)
                .background(active ? TicoBrand.Palette.primary : TicoBrand.Palette.background, in: .rect(cornerRadius: 6))
                .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(.primary.opacity(active ? 0 : 0.1)) }
        }.buttonStyle(.plain).disabled(onSelect == nil || isRecording)
            .help(modifier?.displayName ?? InputPresentation.label(code))
            .accessibilityLabel(modifier?.displayName ?? InputPresentation.label(code))
            .accessibilityValue(active ? "Selecionada" : "")
            .accessibilityIdentifier("tico.keyboard.key.\(code)")
    }

}

struct TriggerKeycaps: View {
    let trigger: TriggerDefinition
    var body: some View {
        HStack(spacing: 6) {
            if case let .keyboard(code, modifiers) = trigger {
                ForEach(InputModifier.allCases.filter(modifiers.contains), id: \.self) { modifier in
                    cap(modifier.symbol).help(modifier.displayName)
                }
                cap(InputPresentation.label(code))
            } else {
                Image(systemName: RuleEditorSummary.symbol(trigger)).foregroundStyle(TicoBrand.Palette.primary)
                Text(RuleEditorSummary.trigger(trigger)).font(.callout.weight(.medium)).lineLimit(2)
            }
        }.accessibilityElement(children: .ignore).accessibilityLabel(RuleEditorSummary.trigger(trigger))
    }
    private func cap(_ text: String) -> some View {
        Text(text).font(.system(size: 17, weight: .medium)).padding(.horizontal, 12).frame(height: 36)
            .background(TicoBrand.Palette.surface, in: .rect(cornerRadius: 8))
            .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(.primary.opacity(0.12)) }
    }
}
