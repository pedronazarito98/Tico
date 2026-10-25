import SwiftUI

/// Edita intenção espacial sem consultar janelas nem guardar imagens. A seleção
/// pertence à interface; o plano continua sendo a única fonte de posições.
/// Paralelo com React: inspector controlado pela identidade do item selecionado.
struct SceneLayoutPlanEditor: View {
    @Binding var plan: SceneLayoutPlan
    let applications: [ApplicationChoice]
    @State private var selectedID: UUID?

    private var roles: [SceneLayoutDisplayRole] {
        SceneLayoutDisplayRole.allCases.filter { role in plan.windows.contains { $0.display == role } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Escolha uma janela para ajustar sua posição.")
                .font(.callout).foregroundStyle(.secondary)
            LazyVGrid(columns: displayColumns, alignment: .leading, spacing: 14) {
                ForEach(roles) { role in
                    VStack(alignment: .leading, spacing: 8) {
                        GeometryReader { geometry in
                            ZStack(alignment: .topLeading) {
                                RoundedRectangle(cornerRadius: 10).fill(.quaternary.opacity(0.5))
                                ForEach(plan.windows.filter { $0.display == role }) { window in
                                    Button { selectedID = window.id } label: {
                                        VStack(spacing: 4) {
                                            ApplicationIconView(application: applications.first { $0.id == window.bundleIdentifier }, size: 24)
                                            Text(window.applicationName).font(.caption).lineLimit(1)
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(TicoBrand.Palette.surface, in: .rect(cornerRadius: 6))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 6).strokeBorder(
                                                selectedID == window.id ? TicoBrand.Palette.primary : Color.secondary.opacity(0.3),
                                                lineWidth: selectedID == window.id ? 2 : 1)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .frame(width: max(12, window.frame.width * geometry.size.width),
                                           height: max(12, window.frame.height * geometry.size.height))
                                    .offset(x: window.frame.x * geometry.size.width, y: window.frame.y * geometry.size.height)
                                    .accessibilityLabel("Ajustar \(window.applicationName), \(role.label)")
                                    .accessibilityAddTraits(selectedID == window.id ? [.isSelected] : [])
                                }
                            }
                        }.aspectRatio(1.6, contentMode: .fit).frame(maxHeight: 180).clipped()
                        Text(role.label).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            // Alternativa para sobreposição e teclado: selecionar não depende
            // de acertar a área de uma janela no desenho.
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), alignment: .leading)], alignment: .leading, spacing: 8) {
                ForEach(plan.windows) { window in
                    Button { selectedID = window.id } label: {
                        Label(window.applicationName, systemImage: selectedID == window.id ? "checkmark.circle.fill" : "macwindow")
                            .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .tint(selectedID == window.id ? TicoBrand.Palette.primary : .secondary)
                    .accessibilityAddTraits(selectedID == window.id ? [.isSelected] : [])
                }
            }
            if let window = plan.windows.first(where: { $0.id == selectedID }) {
                SceneLayoutWindowEditor(window: binding(for: window)) {
                    plan.windows.removeAll { $0.id == window.id }
                    selectedID = plan.windows.first?.id
                }
            }
        }
        .onChange(of: plan.windows.map(\.id), initial: true) {
            if !plan.windows.contains(where: { $0.id == selectedID }) {
                selectedID = plan.windows.first?.id
            }
        }
    }

    private var displayColumns: [GridItem] {
        [GridItem(roles.count == 1 ? .flexible() : .adaptive(minimum: 190), alignment: .top)]
    }

    private func binding(for window: SceneLayoutWindow) -> Binding<SceneLayoutWindow> {
        Binding(get: { plan.windows.first { $0.id == window.id } ?? window }, set: { value in
            guard let index = plan.windows.firstIndex(where: { $0.id == window.id }) else { return }
            plan.windows[index] = value
        })
    }
}
