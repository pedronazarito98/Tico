import ApplicationServices
import Foundation

/// Owner exclusivo dos handles AX e da recuperação em memória. O actor serializa
/// acesso; a trava cobre também reentrância durante awaits. Nada deste estado é
/// Codable. Reiniciar o Tico encerra a possibilidade de restaurar estes handles.
actor SceneLayoutService: SceneLayoutServicing {
    private static let ambiguousSingleWindowMessage =
        "Este aplicativo tem várias janelas. Feche as extras e atualize, ou altere a cena para Escolher na prévia."

    private struct WindowReference {
        let id: UUID
        let element: AXUIElement
        let application: SceneLayoutEnvironment.Application
        let frame: SceneLayoutRect
    }
    private struct Prepared {
        let plan: SceneLayoutPlan
        let screens: [SceneLayoutEnvironment.Screen]
        let candidates: [WindowReference]
        var preview: SceneLayoutPreview
    }
    private struct RecoveryEntry {
        let slotID: UUID
        let reference: WindowReference
        let screens: [SceneLayoutEnvironment.Screen]
        var expectedFrame: SceneLayoutRect?
    }
    private var prepared: [UUID: Prepared] = [:]
    private var captured: [UUID: WindowReference] = [:]
    private var capturedAt = Date.distantPast
    private var recovery: [UUID: [RecoveryEntry]] = [:]
    private var mutationInProgress = false

    func capture() async throws -> SceneLayoutCapture {
        try Task.checkCancellation()
        try requireAvailable()
        let screens = await SceneLayoutEnvironment.screens()
        let inventory = try await inventory()
        try Task.checkCancellation()
        var windows: [SceneLayoutWindow] = []
        captured.removeAll()
        var skipped = 0
        for candidate in inventory {
            guard windows.count < 20 else { skipped += 1; continue }
            guard let screen = screen(for: candidate.frame, in: screens) else { skipped += 1; continue }
            let normalized = candidate.frame.normalized(in: screen.frame)
            guard normalized.isNormalized else { skipped += 1; continue }
            let count = inventory.filter { $0.application.bundleIdentifier == candidate.application.bundleIdentifier }.count
            let slot = SceneLayoutWindow(bundleIdentifier: candidate.application.bundleIdentifier,
                applicationName: String(candidate.application.name.prefix(120)),
                selection: count == 1 ? .singleWindow : .chooseInPreview,
                display: screen.role, frame: normalized)
            windows.append(slot)
            captured[slot.id] = candidate
        }
        capturedAt = Date()
        guard !windows.isEmpty else {
            throw SceneLayoutError.invalid("Nenhuma janela padrão, visível e redimensionável foi encontrada. Abra os aplicativos e tente novamente.")
        }
        var notices = ["Captura limitada a janelas padrão, abertas e redimensionáveis. Janelas minimizadas, em tela cheia e sem suporte AX ficam de fora."]
        if skipped > 0 { notices.append("\(skipped) janela(s) fora da área útil ou do limite de 20 não foram incluídas.") }
        return .init(plan: .init(windows: windows), notices: notices)
    }

    func prepare(plan: SceneLayoutPlan, workflowID: UUID) async throws -> SceneLayoutPreview {
        try Task.checkCancellation()
        try requireAvailable()
        if let issue = plan.validationIssue { throw SceneLayoutError.invalid(issue) }
        let screens = await SceneLayoutEnvironment.screens()
        let candidates = try await inventory(bundleIdentifiers: Set(plan.windows.map(\.bundleIdentifier)))
        try Task.checkCancellation()
        try requireAvailable()
        let preview = makePreview(plan: plan, workflowID: workflowID, screens: screens, candidates: candidates)
        // Uma única prévia interativa basta; execuções nunca reutilizam outra cena.
        prepared = [workflowID: Prepared(plan: plan, screens: screens, candidates: candidates, preview: preview)]
        return preview
    }

    func select(workflowID: UUID, slotID: UUID, windowID: UUID?) throws -> SceneLayoutPreview {
        try Task.checkCancellation()
        guard !mutationInProgress, var current = prepared[workflowID],
              let index = current.preview.windows.firstIndex(where: { $0.id == slotID }),
              let slot = current.plan.windows.first(where: { $0.id == slotID }) else { throw SceneLayoutError.stalePreview }
        let matches = current.candidates.filter { $0.application.bundleIdentifier == slot.bundleIdentifier }
        // A escolha manual não muda o contrato salvo de janela única. Para
        // selecionar entre várias, a cena precisa usar chooseInPreview.
        guard slot.selection != .singleWindow || matches.count <= 1 else {
            throw SceneLayoutError.invalid(Self.ambiguousSingleWindowMessage)
        }
        let candidate = matches.first { $0.id == windowID }
        current.preview.windows[index].selectedWindowID = candidate?.id
        current.preview.windows[index].sourceFrame = candidate?.frame
        current.preview.windows[index].sourceDisplay = candidate.flatMap { screen(for: $0.frame, in: current.screens)?.role }
        current.preview.windows[index].issue = candidate == nil ? "Escolha a janela desta execução." : nil
        validateSelections(&current.preview)
        current.preview.id = UUID()
        prepared[workflowID] = current
        return current.preview
    }

    /// Efeito opcional e explícito do botão Mostrar no aplicativo. Não faz parte
    /// da preparação; permite distinguir janelas iguais sem ler seus títulos.
    func identify(workflowID: UUID, slotID: UUID) async throws {
        try requireAvailable()
        guard let current = prepared[workflowID],
              let row = current.preview.windows.first(where: { $0.id == slotID }),
              let reference = current.candidates.first(where: { $0.id == row.selectedWindowID }) else {
            throw SceneLayoutError.stalePreview
        }
        mutationInProgress = true
        defer { mutationInProgress = false }
        try await validateIdentity(reference)
        try Task.checkCancellation()
        try SceneLayoutAccessibility.raise(reference.element)
        try Task.checkCancellation()
        guard await SceneLayoutEnvironment.activate(reference.application) else { throw SceneLayoutError.changedWindow }
    }

    func invalidate(workflowID: UUID) { prepared.removeValue(forKey: workflowID) }

    func apply(plan: SceneLayoutPlan, workflowID: UUID, deadline: Date) async throws -> [WorkflowStepExecution] {
        try Task.checkCancellation()
        try requireAvailable()
        guard recovery.values.allSatisfy(\.isEmpty) else { throw SceneLayoutError.pendingRecovery }
        // Execuções por regra também passam pela mesma preparação. Se houver várias
        // janelas sem escolha explícita, o layout falha antes de produzir efeitos.
        if prepared[workflowID] == nil { _ = try await prepare(plan: plan, workflowID: workflowID) }
        try requireAvailable()
        guard recovery.values.allSatisfy(\.isEmpty) else { throw SceneLayoutError.pendingRecovery }
        guard let current = prepared[workflowID], current.plan == plan,
              Date().timeIntervalSince(current.preview.createdAt) <= SceneLayoutPreview.validityDuration else {
            throw SceneLayoutError.stalePreview
        }
        guard current.preview.canApply else {
            throw SceneLayoutError.invalid(current.preview.windows.compactMap(\.issue).first ?? "Revise a prévia antes de aplicar.")
        }
        mutationInProgress = true
        defer { mutationInProgress = false; prepared.removeValue(forKey: workflowID) }
        try Task.checkCancellation()
        guard Date() < deadline else { throw SceneLayoutError.invalid("O tempo limite da cena terminou antes do layout.") }
        guard await SceneLayoutEnvironment.screens() == current.screens else { throw SceneLayoutError.changedDisplays }
        // Preflight de todas as janelas evita começar com um plano já inconsistente.
        for row in current.preview.windows {
            guard Date() < deadline else { throw SceneLayoutError.invalid("O tempo limite terminou durante a verificação das janelas.") }
            guard let reference = current.candidates.first(where: { $0.id == row.selectedWindowID }),
                  let slot = plan.windows.first(where: { $0.id == row.id }) else { throw SceneLayoutError.stalePreview }
            try await validate(reference, expected: reference.frame, selection: slot.selection)
        }
        var results: [WorkflowStepExecution] = []
        for (index, row) in current.preview.windows.enumerated() {
            let startedAt = Date()
            do {
                try Task.checkCancellation()
                guard Date() < deadline else { throw SceneLayoutError.invalid("O tempo limite da cena terminou; restaure as janelas já alteradas se necessário.") }
                guard await SceneLayoutEnvironment.screens() == current.screens else { throw SceneLayoutError.changedDisplays }
                guard let reference = current.candidates.first(where: { $0.id == row.selectedWindowID }),
                      let slot = plan.windows.first(where: { $0.id == row.id }),
                      let target = row.targetFrame else { throw SceneLayoutError.stalePreview }
                try await validate(reference, expected: reference.frame, selection: slot.selection)
                try Task.checkCancellation()
                guard Date() < deadline else { throw SceneLayoutError.invalid("O tempo limite terminou durante a verificação das janelas.") }
                if !reference.frame.isNear(target) {
                    recovery[workflowID, default: []].append(.init(slotID: row.id, reference: reference,
                        screens: current.screens, expectedFrame: nil))
                    do {
                        try SceneLayoutAccessibility.setFrame(target, on: reference.element, deadline: deadline)
                        try await Task.sleep(for: .milliseconds(100))
                        let actual = try SceneLayoutAccessibility.frame(reference.element)
                        updateRecovery(workflowID: workflowID, slotID: row.id, frame: actual)
                        guard await SceneLayoutEnvironment.screens() == current.screens else { throw SceneLayoutError.changedDisplays }
                        guard actual.isNear(target) else {
                            throw SceneLayoutError.invalid("O aplicativo limitou o tamanho ou a posição. A disposição anterior continua disponível.")
                        }
                    } catch {
                        if let actual = try? SceneLayoutAccessibility.frame(reference.element) {
                            updateRecovery(workflowID: workflowID, slotID: row.id, frame: actual)
                        }
                        throw error
                    }
                }
                results.append(result(row: row, index: index, startedAt: startedAt,
                    outcome: .succeeded("Posição e tamanho confirmados.")))
            } catch {
                let message = error is CancellationError ? "Layout cancelado; a recuperação foi mantida." : error.localizedDescription
                results.append(result(row: row, index: index, startedAt: startedAt, outcome: .failed(message)))
                break
            }
        }
        return results
    }

    func restore(workflowID: UUID) async throws -> SceneLayoutRecovery {
        try requireAvailable()
        mutationInProgress = true
        defer { mutationInProgress = false }
        let entries = recovery[workflowID] ?? []
        var results: [WorkflowStepExecution] = []
        for (index, entry) in entries.enumerated() {
            let startedAt = Date()
            let outcome: ActionExecutionResult
            var attemptedMutation = false
            do {
                try Task.checkCancellation()
                // Uma tela removida não impede recuperar janelas de outra tela
                // que continua com a mesma geometria e identidade nesta sessão.
                try await validateOriginalScreen(entry)
                try await validateIdentity(entry.reference)
                let actual = try SceneLayoutAccessibility.frame(entry.reference.element)
                if !actual.isNear(entry.reference.frame) {
                    guard let expected = entry.expectedFrame, actual.isNear(expected) else {
                        throw SceneLayoutError.invalid("A janela foi movida depois da cena. A restauração preservou sua alteração mais recente.")
                    }
                    attemptedMutation = true
                    try SceneLayoutAccessibility.setFrame(entry.reference.frame, on: entry.reference.element)
                    try await Task.sleep(for: .milliseconds(100))
                    let restored = try SceneLayoutAccessibility.frame(entry.reference.element)
                    updateRecovery(workflowID: workflowID, slotID: entry.slotID, frame: restored)
                    guard restored.isNear(entry.reference.frame) else {
                        throw SceneLayoutError.invalid("O aplicativo não aceitou toda a disposição anterior. Você pode tentar novamente.")
                    }
                }
                // Readback não basta se a tela ou o app mudar durante o write.
                // Só liberamos recovery após revalidar também esse destino exato.
                try await validateOriginalScreen(entry)
                try await validateIdentity(entry.reference)
                recovery[workflowID]?.removeAll { $0.slotID == entry.slotID }
                outcome = .succeeded("Disposição anterior confirmada.")
            } catch {
                if attemptedMutation, let actual = try? SceneLayoutAccessibility.frame(entry.reference.element) {
                    updateRecovery(workflowID: workflowID, slotID: entry.slotID, frame: actual)
                }
                outcome = .failed(error is CancellationError ? "Restauração cancelada; pendências preservadas." : error.localizedDescription)
            }
            results.append(.init(stepID: entry.slotID, stepName: entry.reference.application.name,
                index: index, result: outcome, duration: Date().timeIntervalSince(startedAt)))
            if Task.isCancelled { break }
        }
        return .init(workflowID: workflowID, pendingWindowCount: recovery[workflowID]?.count ?? 0, results: results)
    }

    func pendingRecovery(workflowID: UUID) -> SceneLayoutRecovery {
        .init(workflowID: workflowID, pendingWindowCount: recovery[workflowID]?.count ?? 0, results: [])
    }

    func discardRecovery(workflowID: UUID) throws {
        guard !mutationInProgress else { throw SceneLayoutError.busy }
        recovery.removeValue(forKey: workflowID)
    }

    private func requireAvailable() throws {
        guard !mutationInProgress else { throw SceneLayoutError.busy }
        guard AXIsProcessTrusted() else { throw SceneLayoutError.permissionRequired }
    }

    private func inventory(bundleIdentifiers: Set<String>? = nil) async throws -> [WindowReference] {
        let applications = await SceneLayoutEnvironment.applications().filter {
            bundleIdentifiers?.contains($0.bundleIdentifier) ?? true
        }
        let deadline = Date().addingTimeInterval(8)
        var result: [WindowReference] = []
        for app in applications.prefix(60) {
            try Task.checkCancellation()
            guard Date() < deadline, result.count < 60 else {
                throw SceneLayoutError.invalid("A consulta atingiu o limite de tempo ou de janelas. Tente novamente com menos aplicativos abertos.")
            }
            let windows: [AXUIElement]
            do { windows = try SceneLayoutAccessibility.windows(for: app.pid) }
            catch {
                if bundleIdentifiers != nil { throw error }
                continue
            }
            for window in windows {
                try Task.checkCancellation()
                guard Date() < deadline, result.count < 60 else {
                    throw SceneLayoutError.invalid("A consulta atingiu o limite de tempo ou de janelas. Tente novamente com menos aplicativos abertos.")
                }
                do {
                    guard try SceneLayoutAccessibility.isControllable(window) else { continue }
                    let frame = try SceneLayoutAccessibility.frame(window)
                    result.append(.init(id: UUID(), element: window, application: app, frame: frame))
                } catch {
                    if bundleIdentifiers != nil { throw error }
                }
            }
        }
        return result
    }

    private func validate(_ reference: WindowReference, expected: SceneLayoutRect,
                          selection: SceneLayoutWindowSelection) async throws {
        try Task.checkCancellation()
        try await validateIdentity(reference)
        if selection == .singleWindow {
            // Reconsulta elegíveis antes de cada escrita, com os mesmos limites
            // e cancelamento do inventário. Não é uma transação do macOS: outra
            // janela ainda pode surgir entre a última leitura AX e a escrita.
            let matches = try await inventory(bundleIdentifiers: [reference.application.bundleIdentifier])
            guard matches.count <= 1 else {
                throw SceneLayoutError.invalid(Self.ambiguousSingleWindowMessage)
            }
            guard let current = matches.first,
                  current.application.pid == reference.application.pid,
                  current.application.launchedAt == reference.application.launchedAt,
                  CFEqual(current.element, reference.element) else { throw SceneLayoutError.stalePreview }
        }
        try Task.checkCancellation()
        guard try SceneLayoutAccessibility.frame(reference.element).isNear(expected) else { throw SceneLayoutError.changedWindow }
    }

    private func validateIdentity(_ reference: WindowReference) async throws {
        try Task.checkCancellation()
        guard await SceneLayoutEnvironment.isRunning(reference.application),
              try SceneLayoutAccessibility.windows(for: reference.application.pid).contains(where: { CFEqual($0, reference.element) }),
              try SceneLayoutAccessibility.isControllable(reference.element) else {
            throw SceneLayoutError.changedWindow
        }
    }

    private func validateOriginalScreen(_ entry: RecoveryEntry) async throws {
        try Task.checkCancellation()
        let available = await SceneLayoutEnvironment.screens()
        guard let original = screen(for: entry.reference.frame, in: entry.screens),
              available.contains(where: { $0.number == original.number && $0.frame == original.frame }) else {
            throw SceneLayoutError.changedDisplays
        }
    }

    private func updateRecovery(workflowID: UUID, slotID: UUID, frame: SceneLayoutRect) {
        guard let index = recovery[workflowID]?.firstIndex(where: { $0.slotID == slotID }) else { return }
        recovery[workflowID]?[index].expectedFrame = frame
    }

    private func screen(for frame: SceneLayoutRect, in screens: [SceneLayoutEnvironment.Screen]) -> SceneLayoutEnvironment.Screen? {
        screens.max { left, right in
            let a = left.frame.cgRect.intersection(frame.cgRect)
            let b = right.frame.cgRect.intersection(frame.cgRect)
            return (a.isNull ? 0 : a.width * a.height) < (b.isNull ? 0 : b.width * b.height)
        }
    }

    private func result(row: SceneLayoutPreviewWindow, index: Int, startedAt: Date,
                        outcome: ActionExecutionResult) -> WorkflowStepExecution {
        .init(stepID: row.id, stepName: "Layout · \(row.applicationName)", index: index,
              result: outcome, duration: Date().timeIntervalSince(startedAt))
    }

    private func makePreview(plan: SceneLayoutPlan, workflowID: UUID,
                             screens: [SceneLayoutEnvironment.Screen], candidates: [WindowReference]) -> SceneLayoutPreview {
        var notices = ["A prévia vale por 5 minutos. Mudanças nas janelas ou monitores exigem uma nova revisão.",
                       "A restauração cobre somente posição e tamanho destas janelas enquanto o Tico estiver aberto. Não reabre documentos, abas ou aplicativos."]
        let rows = plan.windows.map { slot -> SceneLayoutPreviewWindow in
            let matches = candidates.filter { $0.application.bundleIdentifier == slot.bundleIdentifier }
            let preferred = slot.display == .primary ? screens.first(where: \.isPrimary) : screens.first { $0.role == slot.display }
            let targetScreen = preferred ?? (plan.missingDisplayPolicy == .usePrimary ? screens.first(where: \.isPrimary) : nil)
            if preferred == nil, targetScreen != nil {
                notices.append("\(slot.applicationName): \(slot.display.label) ausente; será usado o monitor principal, conforme sua configuração.")
            }
            let selected: WindowReference?
            if slot.selection == .singleWindow, matches.count == 1 {
                selected = matches.first
            } else if slot.selection == .chooseInPreview,
                      Date().timeIntervalSince(capturedAt) <= 120, let capturedReference = captured[slot.id] {
                selected = matches.first { CFEqual($0.element, capturedReference.element)
                    && $0.application.launchedAt == capturedReference.application.launchedAt }
            } else {
                selected = nil
            }
            let issue: String?
            if targetScreen == nil { issue = "\(slot.display.label) indisponível. Revise o monitor ou o fallback." }
            else if matches.isEmpty { issue = "Abra uma janela padrão e redimensionável deste aplicativo e atualize a prévia." }
            else if slot.selection == .singleWindow, matches.count > 1 { issue = Self.ambiguousSingleWindowMessage }
            else if selected == nil { issue = "Escolha a janela desta execução; nenhuma seleção por título ou documento é feita." }
            else { issue = nil }
            return .init(id: slot.id, applicationName: slot.applicationName,
                sourceFrame: selected?.frame,
                sourceDisplay: selected.flatMap { screen(for: $0.frame, in: screens)?.role },
                targetFrame: targetScreen.map { slot.frame.resolved(in: $0.frame) }, targetDisplay: targetScreen?.role,
                choices: matches.enumerated().map { index, candidate in
                    let role = screen(for: candidate.frame, in: screens)?.role.label ?? "Fora da tela"
                    return .init(id: candidate.id, label: "Janela \(index + 1) · \(role) · \(Int(candidate.frame.width)) × \(Int(candidate.frame.height))")
                }, selectedWindowID: selected?.id, issue: issue)
        }
        var preview = SceneLayoutPreview(id: UUID(), workflowID: workflowID, displays: screens.map(\.display),
            windows: rows, notices: Array(Set(notices)).sorted(), createdAt: Date())
        validateSelections(&preview)
        return preview
    }

    private func validateSelections(_ preview: inout SceneLayoutPreview) {
        let selected = preview.windows.compactMap(\.selectedWindowID)
        for index in preview.windows.indices {
            if preview.windows[index].issue == "Escolha janelas diferentes para cada posição." {
                preview.windows[index].issue = nil
            }
            if let id = preview.windows[index].selectedWindowID, selected.filter({ $0 == id }).count > 1 {
                preview.windows[index].issue = "Escolha janelas diferentes para cada posição."
            }
            if preview.windows[index].targetFrame == nil {
                preview.windows[index].issue = "O monitor desta posição está indisponível."
            }
        }
    }
}
