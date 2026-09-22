import SwiftUI

/// Verbos concretos e visíveis substituem o menu de operações do aplicativo.
struct ApplicationOperationChoices: View {
    let operation: ApplicationOperation
    let onSelect: (ApplicationOperation) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
            ForEach(ApplicationOperation.allCases, id: \.self) { value in
                EditorChoiceButton(title: value.displayName, symbol: Self.symbol(value),
                                   isSelected: value == operation) { onSelect(value) }
            }
        }
    }

    static func symbol(_ value: ApplicationOperation) -> String {
        switch value {
        case .open: "arrow.up.forward.app"
        case .activate: "macwindow.on.rectangle"
        case .hide: "eye.slash"
        case .quit: "power"
        }
    }
}
