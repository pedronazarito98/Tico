import SwiftUI

struct GestureMapView: View {
    let rules: [ShortcutRule]
    let profiles: [ShortcutProfile]
    let applications: [ApplicationChoice]
    let context: ContextSnapshot?
    let onPractice: (ShortcutRule) -> Void
    let onEdit: (UUID) -> Void
    @State private var currentAppOnly = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Seus gestos, à vista").font(.largeTitle.bold())
                Text("Consulte os atalhos e pratique sem executar suas ações.").foregroundStyle(.secondary)
                Toggle("Somente disponíveis em \(context?.frontmostApplicationName ?? "app atual")", isOn: $currentAppOnly)
                    .disabled(context == nil)
                Text("Com a captura ativa, segure ⌘⌥ para consultar o mapa no aplicativo em uso.")
                    .font(.callout).foregroundStyle(.secondary)
                if visibleRules.isEmpty {
                    ContentUnavailableView("Nenhum atalho neste contexto", systemImage: "hand.draw",
                        description: Text("Crie um atalho em Explorar ou mostre todos os aplicativos."))
                }
                ForEach(visibleRules) { rule in
                    GroupBox {
                        HStack(spacing: 22) {
                            GestureIllustrationView(trigger: rule.trigger)
                            VStack(alignment: .leading, spacing: 7) {
                                Text(rule.name).font(.headline)
                                Text(rule.trigger.displayName)
                                Text(rule.scope.displayName(applications: applications)).foregroundStyle(.secondary)
                                Text(rule.isEnabled ? "Ativo" : "Desativado").font(.caption)
                            }
                            Spacer(minLength: 0)
                            VStack {
                                Button("Praticar") { onPractice(rule) }
                                Button("Editar") { onEdit(rule.id) }
                            }
                        }.padding(8)
                    }
                }
            }.padding(28)
        }.navigationTitle("Mapa de gestos")
    }

    private var visibleRules: [ShortcutRule] {
        guard currentAppOnly, let context else { return rules }
        return rules.filter { $0.matches(context, profiles: profiles) }
    }
}
