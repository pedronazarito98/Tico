import Foundation

/// Topologia por papéis. IDs CoreGraphics existem apenas durante a leitura do adaptador.
/// Geometria e papel principal distinguem a disposição atual sem serial persistido.
struct DisplayEnvironmentSnapshot: Equatable, Hashable, Sendable {
    enum MainDisplayRole: String, Codable, CaseIterable, Sendable { case builtIn, external, unavailable }
    let builtInCount: Int
    let externalCount: Int
    let mainDisplayRole: MainDisplayRole
    let arrangement: [DisplayEnvironmentGeometry]
    init(builtInCount: Int, externalCount: Int, mainDisplayRole: MainDisplayRole,
         arrangement: [DisplayEnvironmentGeometry] = []) {
        self.builtInCount = builtInCount
        self.externalCount = externalCount
        self.mainDisplayRole = mainDisplayRole
        self.arrangement = arrangement
    }
    var totalCount: Int { builtInCount + externalCount }
    var summary: String {
        "\(builtInCount) tela(s) integrada(s) · \(externalCount) externa(s)"
    }
}

/// Geometria normalizada em pontos, transitória e sem identificador de monitor.
struct DisplayEnvironmentGeometry: Equatable, Hashable, Sendable {
    let role: DisplayEnvironmentSnapshot.MainDisplayRole
    /// Integra a igualdade para detectar troca da tela principal entre externos.
    /// A posição permanece normalizada, e nenhum identificador físico é guardado.
    let isPrimary: Bool
    let x: Int
    let y: Int
    let width: Int
    let height: Int
}

enum DisplayEnvironmentInterruption: Hashable { case sleep, inactiveSession, displaySleep, locked }

enum DisplayEnvironmentEvent {
    case changed(DisplayEnvironmentSnapshot)
    case suspended(DisplayEnvironmentInterruption)
    case resumed(DisplayEnvironmentInterruption, DisplayEnvironmentSnapshot)
}
