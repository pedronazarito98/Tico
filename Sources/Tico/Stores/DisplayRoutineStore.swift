import Combine
import Foundation

/// Publica somente após persistir; o coordenador invalida sugestões ao observar mudanças.
@MainActor
final class DisplayRoutineStore: ObservableObject {
    @Published private(set) var document = DisplayRoutineDocument()
    @Published private(set) var errorMessage: String?
    private let repository: any DisplayRoutineRepository
    private var loadedSuccessfully = false

    var routines: [DisplayRoutine] { document.routines }
    var isEnabled: Bool { document.isEnabled }

    convenience init(dataURL: URL) {
        self.init(repository: FileDisplayRoutineRepository(dataURL: dataURL))
    }

    init(repository: any DisplayRoutineRepository) {
        self.repository = repository
        do {
            document = try repository.read() ?? DisplayRoutineDocument()
            loadedSuccessfully = true
        } catch { errorMessage = DisplayRoutineError.unavailable.localizedDescription }
    }

    func setEnabled(_ enabled: Bool) throws {
        var candidate = document
        candidate.isEnabled = enabled
        try persist(candidate)
    }

    func save(_ routine: DisplayRoutine) throws {
        try save(routine, activateMonitoring: false)
    }

    /// A confirmação de ativar salva rotina e preferência global numa única
    /// escrita. Uma falha não deixa metade da intenção aplicada.
    /// Paralelo com React: uma única transição publica o novo estado completo.
    func save(_ routine: DisplayRoutine, activateMonitoring: Bool) throws {
        var candidate = document
        if activateMonitoring { candidate.isEnabled = true }
        var normalized = routine
        normalized.name = routine.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let index = candidate.routines.firstIndex(where: { $0.id == routine.id }) {
            candidate.routines[index] = normalized
        } else { candidate.routines.append(normalized) }
        try persist(candidate)
    }

    func remove(_ id: UUID) throws {
        var candidate = document
        candidate.routines.removeAll { $0.id == id }
        try persist(candidate)
    }

    private func persist(_ candidate: DisplayRoutineDocument) throws {
        guard loadedSuccessfully else { throw DisplayRoutineError.unavailable }
        try FileDisplayRoutineRepository.validate(candidate)
        do { try repository.write(candidate) } catch {
            errorMessage = DisplayRoutineError.persistence.localizedDescription
            throw DisplayRoutineError.persistence
        }
        document = candidate
        errorMessage = nil
    }
}
