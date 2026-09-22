import SwiftUI

/// Simulação visual local do resultado. Não lê janelas, captura a tela ou executa ações.
/// Paralelo com React: props definem a cena; o contador de reconhecimento dispara animação.
struct ShortcutResultPreview: View {
    let workflow: ActionWorkflow
    let applications: [ApplicationChoice]
    var recognitionCount = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsResult = true

    private var action: ShortcutAction? { workflow.enabledSteps.first?.action }
    private var application: ApplicationChoice? {
        switch action {
        case let .openApplication(id), let .application(.bundleIdentifier(id), _),
             let .window(.bundleIdentifier(id), _):
            applications.first { $0.id == id }
        default:
            applications.first { $0.id == "com.apple.Safari" } ?? applications.first
        }
    }

    private var placement: CGRect {
        guard showsResult else { return CGRect(x: 0.25, y: 0.14, width: 0.58, height: 0.65) }
        guard case let .window(_, operation) = action else {
            return CGRect(x: 0.15, y: 0.12, width: 0.7, height: 0.67)
        }
        switch operation {
        case .leftHalf: return CGRect(x: 0.025, y: 0.06, width: 0.47, height: 0.76)
        case .rightHalf: return CGRect(x: 0.505, y: 0.06, width: 0.47, height: 0.76)
        case .topHalf: return CGRect(x: 0.025, y: 0.04, width: 0.95, height: 0.38)
        case .bottomHalf: return CGRect(x: 0.025, y: 0.45, width: 0.95, height: 0.38)
        case .maximize, .tileAll: return CGRect(x: 0.025, y: 0.04, width: 0.95, height: 0.79)
        case .leftThird: return CGRect(x: 0.025, y: 0.06, width: 0.3, height: 0.76)
        case .centerThird: return CGRect(x: 0.35, y: 0.06, width: 0.3, height: 0.76)
        case .rightThird: return CGRect(x: 0.675, y: 0.06, width: 0.3, height: 0.76)
        case .topLeftQuarter: return CGRect(x: 0.025, y: 0.04, width: 0.47, height: 0.38)
        case .topRightQuarter: return CGRect(x: 0.505, y: 0.04, width: 0.47, height: 0.38)
        case .bottomLeftQuarter: return CGRect(x: 0.025, y: 0.45, width: 0.47, height: 0.38)
        case .bottomRightQuarter: return CGRect(x: 0.505, y: 0.45, width: 0.47, height: 0.38)
        default: return CGRect(x: 0.2, y: 0.13, width: 0.6, height: 0.64)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                LinearGradient(colors: [.blue.opacity(0.45), TicoBrand.Palette.primary, .indigo],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Ellipse().fill(.white.opacity(0.13)).rotationEffect(.degrees(-25))
                    .frame(width: geometry.size.width * 1.4, height: geometry.size.height * 0.55)
                    .offset(x: -60, y: geometry.size.height * 0.32)
                if case .window = action {
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(.white.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                        .frame(width: geometry.size.width * 0.47, height: geometry.size.height * 0.76)
                        .offset(x: geometry.size.width * (placement.minX < 0.1 ? 0.505 : 0.025), y: geometry.size.height * 0.06)
                }
                previewWindow
                    .frame(width: geometry.size.width * placement.width, height: geometry.size.height * placement.height)
                    .background(TicoBrand.Palette.surface, in: .rect(cornerRadius: 9))
                    .clipShape(.rect(cornerRadius: 9))
                    .shadow(color: .black.opacity(0.2), radius: 5, y: 4)
                    .offset(x: geometry.size.width * placement.minX, y: geometry.size.height * placement.minY)
                    .opacity(windowHidden ? 0 : 1)
                HStack(spacing: 8) {
                    ForEach(Array(applications.filter { ["com.apple.finder", "com.apple.Safari", "com.apple.mail", "com.apple.iCal", "com.apple.Notes"].contains($0.id) }.prefix(5))) { app in
                        ApplicationIconView(application: app, size: 26)
                    }
                }
                .padding(7).background(.ultraThinMaterial, in: .rect(cornerRadius: 13))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 6)
            }
        }
        .aspectRatio(1.92, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 11))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Prévia: \(action.map { RuleEditorSummary.action($0, applications: applications) } ?? "Escolha uma ação")")
        .task(id: recognitionCount) {
            guard recognitionCount > 0, !reduceMotion else { return }
            showsResult = false
            do { try await Task.sleep(for: .milliseconds(120)) } catch { return }
            withAnimation(.easeInOut(duration: 0.45)) { showsResult = true }
        }
    }

    private var windowHidden: Bool {
        guard showsResult else { return false }
        return switch action {
        case .window(_, .close), .window(_, .minimize), .application(_, .hide), .application(_, .quit): true
        default: false
        }
    }

    private var previewWindow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Circle().fill(.red).frame(width: 6, height: 6)
                Circle().fill(.yellow).frame(width: 6, height: 6)
                Circle().fill(.green).frame(width: 6, height: 6)
                Spacer()
                Image(systemName: "sidebar.right").foregroundStyle(.secondary)
            }.padding(.horizontal, 10).padding(.top, 9)
            if let action, isWindowOrApplication {
                HStack {
                    ApplicationIconView(application: application, size: 26)
                    Text(application?.name ?? RuleActionKind(action: action).title).font(.caption.bold())
                }.padding(.horizontal, 10)
                HStack(alignment: .top, spacing: 8) {
                    VStack(spacing: 6) {
                        ForEach(0..<3) { _ in RoundedRectangle(cornerRadius: 3).fill(.quaternary).frame(width: 22, height: 18) }
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        RoundedRectangle(cornerRadius: 3).fill(.quaternary).frame(height: 5)
                        RoundedRectangle(cornerRadius: 3).fill(.quaternary).frame(height: 5).padding(.trailing, 18)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.linearGradient(colors: [TicoBrand.Palette.primary.opacity(0.15), .blue.opacity(0.4)],
                                                  startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                }.padding(.horizontal, 10).padding(.bottom, 10)
            } else if let action {
                VStack(spacing: 12) {
                    ShortcutActionIcon(action: action, applications: applications, size: 36)
                    Text(RuleEditorSummary.action(action, applications: applications))
                        .font(.callout).lineLimit(3).multilineTextAlignment(.center)
                    if workflow.enabledSteps.count > 1 {
                        Text("\(workflow.enabledSteps.count) ações em sequência").font(.caption).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(10)
            }
        }
    }

    private var isWindowOrApplication: Bool {
        switch action {
        case .window, .openApplication, .application: true
        default: false
        }
    }
}
