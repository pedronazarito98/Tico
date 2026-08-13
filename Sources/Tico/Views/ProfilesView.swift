import SwiftUI

struct ProfilesView: View {
    @ObservedObject var store: ShortcutStore
    let applications: [ApplicationChoice]

    @State private var selectedProfileID: UUID?
    @State private var presentedError: String?

    var body: some View {
        HSplitView {
            List(selection: $selectedProfileID) {
                ForEach(store.profiles) { profile in
                    HStack {
                        Image(systemName: profile.isEnabled ? "person.crop.circle.fill.badge.checkmark" : "person.crop.circle.badge.xmark")
                            .foregroundStyle(profile.isEnabled ? .blue : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                                .lineLimit(1)
                            Text(profile.applicationBundleIdentifiers.isEmpty
                                ? "Qualquer aplicativo"
                                : "\(profile.applicationBundleIdentifiers.count) app(s)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(profile.id)
                }
            }
            .overlay {
                if store.profiles.isEmpty {
                    ContentUnavailableView(
                        "Nenhum perfil",
                        systemImage: "person.crop.circle.badge.plus",
                        description: Text("Crie contextos reutilizáveis para várias regras.")
                    )
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Button {
                        createProfile()
                    } label: {
                        Label("Perfil", systemImage: "plus")
                    }
                    Spacer()
                }
                .padding(10)
                .background(.bar)
            }
            .frame(minWidth: 240, idealWidth: 280, maxWidth: 330)

            if let profile = selectedProfile {
                ProfileEditorView(
                    profile: profile,
                    applications: applications,
                    onSave: store.updateProfile,
                    onDelete: { delete(profile) }
                )
                .id(profile.id)
                .frame(minWidth: 480)
            } else {
                ContentUnavailableView(
                    "Selecione um perfil",
                    systemImage: "person.crop.circle"
                )
                .frame(minWidth: 480)
            }
        }
        .navigationTitle("Perfis")
        .alert("Perfis", isPresented: errorPresented) {
            Button("OK", role: .cancel) { presentedError = nil }
        } message: {
            Text(presentedError ?? "Erro desconhecido")
        }
    }

    private var selectedProfile: ShortcutProfile? {
        guard let selectedProfileID else { return nil }
        return store.profiles.first { $0.id == selectedProfileID }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { presentedError != nil },
            set: { if !$0 { presentedError = nil } }
        )
    }

    private func createProfile() {
        do {
            let profile = try store.addProfile(ShortcutProfile(
                name: "Novo perfil"
            ))
            selectedProfileID = profile.id
        } catch {
            presentedError = error.localizedDescription
        }
    }

    private func delete(_ profile: ShortcutProfile) {
        do {
            try store.deleteProfile(id: profile.id)
            selectedProfileID = store.profiles.first?.id
        } catch {
            presentedError = error.localizedDescription
        }
    }
}

private struct ProfileEditorView: View {
    let profile: ShortcutProfile
    let applications: [ApplicationChoice]
    let onSave: (ShortcutProfile) throws -> Void
    let onDelete: () -> Void

    @State private var draft: ShortcutProfile
    @State private var presentedError: String?

    init(
        profile: ShortcutProfile,
        applications: [ApplicationChoice],
        onSave: @escaping (ShortcutProfile) throws -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.profile = profile
        self.applications = applications
        self.onSave = onSave
        self.onDelete = onDelete
        _draft = State(initialValue: profile)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Nome do perfil", text: $draft.name)
                    .textFieldStyle(.plain)
                    .font(.title2.weight(.semibold))
                Spacer()
                Toggle("Ativo", isOn: $draft.isEnabled)
                    .toggleStyle(.switch)
            }
            .padding(22)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Aplicativos", systemImage: "app.badge.checkmark")
                                .font(.headline)
                            Text("Sem seleção, o perfil vale para qualquer app. Você pode combinar vários apps no mesmo perfil.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Divider()
                            ForEach(applications) { application in
                                Toggle(
                                    isOn: applicationBinding(application.bundleIdentifier)
                                ) {
                                    HStack {
                                        Text(application.name)
                                        Spacer()
                                        if application.isRunning {
                                            Text("Em execução")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(4)
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Política", systemImage: "slider.horizontal.3")
                                .font(.headline)
                            Stepper(
                                "Prioridade do perfil: \(draft.priority)",
                                value: $draft.priority,
                                in: -10...10
                            )
                            Text("Condições específicas de janela, monitor, modificadores e horário também podem ser combinadas em cada regra.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(4)
                    }

                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Condições compartilhadas", systemImage: "line.3.horizontal.decrease.circle")
                                .font(.headline)
                            RuleConditionsEditor(
                                conditions: $draft.conditions,
                                applications: applications,
                                emptyMessage: "Todas as regras deste perfil herdam as condições adicionadas aqui."
                            )
                        }
                        .padding(4)
                    }
                }
                .padding(22)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }

            Divider()
            HStack {
                Button("Excluir perfil", role: .destructive, action: onDelete)
                Spacer()
                Button("Reverter") { draft = profile }
                    .disabled(draft == profile)
                Button("Salvar") {
                    do {
                        try onSave(draft)
                    } catch {
                        presentedError = error.localizedDescription
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft == profile || draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(16)
        }
        .alert("Perfis", isPresented: errorPresentedBinding) {
            Button("OK", role: .cancel) { presentedError = nil }
        } message: {
            Text(presentedError ?? "Erro desconhecido")
        }
    }

    private func applicationBinding(_ identifier: String) -> Binding<Bool> {
        Binding(
            get: { draft.applicationBundleIdentifiers.contains(identifier) },
            set: { enabled in
                if enabled {
                    draft.applicationBundleIdentifiers.insert(identifier)
                } else {
                    draft.applicationBundleIdentifiers.remove(identifier)
                }
            }
        )
    }

    private var errorPresentedBinding: Binding<Bool> {
        Binding(
            get: { presentedError != nil },
            set: { if !$0 { presentedError = nil } }
        )
    }
}
