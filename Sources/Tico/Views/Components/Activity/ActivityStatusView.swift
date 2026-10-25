import SwiftUI

/// Um estado, uma explicação e um próximo passo; diagnósticos ficam sob demanda.
struct ActivityStatusView: View {
    let state: ActivityCaptureState
    let enabledRuleCount: Int
    let totalRuleCount: Int
    let startupError: String?
    let onToggleCapture: () -> Void
    let onOpenPermissions: () -> Void
    let onOpenLaboratory: () -> Void
    let onOpenRules: () -> Void
    let onCreateRule: () -> Void
    @State private var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            layout {
                VStack(alignment: .leading, spacing: 7) {
                    Label(title, systemImage: icon).font(.title2.weight(.semibold))
                    Text(detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Button(actionTitle, action: performPrimaryAction)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("tico.activity.primary-action")
            }
            if totalRuleCount > 0 {
                Button("\(enabledRuleCount) de \(totalRuleCount) atalhos ativados", action: onOpenRules)
                    .buttonStyle(.borderless).font(.callout)
            }
            if let startupError, !startupError.isEmpty {
                DisclosureGroup("Detalhes do trackpad") {
                    Text(startupError).font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if state == .limited || state == .trackpadUnavailable {
                Button("Pausar captura", action: onToggleCapture).buttonStyle(.borderless)
            }
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(TicoBrand.Palette.surface, in: .rect(cornerRadius: 16))
        .onGeometryChange(for: Bool.self) { $0.size.width < 640 } action: { compact = $0 }
    }

    private var layout: AnyLayout {
        compact ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 24))
    }
    private var title: String {
        switch state {
        case .permissionRequired: "Falta uma permissão"
        case .paused: "Captura pausada"
        case .active: enabledRuleCount == 0 ? "Captura ativa, sem atalhos ativados" : "Pronto para seus atalhos"
        case .limited: "Captura ativa com gestos limitados"
        case .trackpadUnavailable: "Captura ativa, trackpad indisponível"
        }
    }
    private var detail: String {
        switch state {
        case .permissionRequired: "Autorize o Monitoramento de Entrada para reconhecer atalhos fora do Tico."
        case .paused: enabledRuleCount > 0
            ? "Seus atalhos estão salvos. Retome a captura para usá-los."
            : "Crie ou ative um atalho para começar a automatizar."
        case .active: enabledRuleCount > 0
            ? "O Tico está ouvindo os acionamentos dos seus atalhos ativados."
            : "Escolha quais atalhos devem responder aos seus acionamentos."
        case .limited: "Teclado e mouse estão ativos. O trackpad usa os gestos públicos do macOS."
        case .trackpadUnavailable: "Teclado e mouse estão ativos. Confira o trackpad no Laboratório."
        }
    }
    private var icon: String {
        switch state {
        case .permissionRequired: "lock.shield"
        case .paused: "pause.circle"
        case .active: "checkmark.circle"
        case .limited, .trackpadUnavailable: "exclamationmark.circle"
        }
    }
    private var actionTitle: String {
        switch state {
        case .permissionRequired: "Revisar permissões"
        case .paused: totalRuleCount == 0 ? "Criar atalho" : (enabledRuleCount == 0 ? "Escolher atalhos" : "Retomar captura")
        case .active: enabledRuleCount == 0 ? "Escolher atalhos" : "Pausar captura"
        case .limited, .trackpadUnavailable: "Conferir trackpad"
        }
    }
    private func performPrimaryAction() {
        switch state {
        case .permissionRequired: onOpenPermissions()
        case .paused where totalRuleCount == 0: onCreateRule()
        case .paused where enabledRuleCount == 0, .active where enabledRuleCount == 0: onOpenRules()
        case .active, .paused: onToggleCapture()
        case .limited, .trackpadUnavailable: onOpenLaboratory()
        }
    }
}
