import SwiftUI

struct DiagnosticStatusIcon: View {
    let outcome: GestureDiagnosticOutcome

    var body: some View {
        Image(systemName: systemImage)
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }

    private var systemImage: String {
        switch outcome {
        case .accepted: "checkmark.seal.fill"
        case .rejected: "xmark.octagon.fill"
        case .ignored: "minus.circle.fill"
        case .cancelled: "stop.circle.fill"
        case .inProgress: "ellipsis.circle.fill"
        }
    }

    private var color: Color {
        switch outcome {
        case .accepted: .green
        case .rejected: .orange
        case .ignored, .inProgress: .secondary
        case .cancelled: .red
        }
    }
}
