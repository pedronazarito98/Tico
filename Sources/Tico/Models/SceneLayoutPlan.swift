import Foundation

/// Configuração portátil: guarda intenção espacial e aplicativos, nunca títulos,
/// documentos, PIDs, elementos AX ou identificadores físicos dos monitores.
struct SceneLayoutPlan: Codable, Hashable, Sendable {
    var windows: [SceneLayoutWindow]
    var missingDisplayPolicy: SceneLayoutMissingDisplayPolicy = .stop

    var validationIssue: String? {
        guard (1...20).contains(windows.count) else { return "Escolha entre 1 e 20 janelas." }
        guard Set(windows.map(\.id)).count == windows.count else { return "As janelas precisam de identidades únicas." }
        guard windows.allSatisfy({ !$0.bundleIdentifier.isEmpty && $0.bundleIdentifier.count <= 255
            && $0.applicationName.count <= 120 && $0.frame.isNormalized }) else {
            return "Revise os aplicativos e as posições do layout."
        }
        return nil
    }
}

struct SceneLayoutWindow: Identifiable, Codable, Hashable, Sendable {
    var id: UUID = UUID()
    var bundleIdentifier: String
    var applicationName: String
    var selection: SceneLayoutWindowSelection
    var display: SceneLayoutDisplayRole
    var frame: SceneLayoutRect
}

/// Quando há várias janelas, a escolha é feita na prévia. A ordem AX não identifica
/// um documento e não serve como vínculo persistente entre execuções.
enum SceneLayoutWindowSelection: String, Codable, CaseIterable, Sendable {
    case singleWindow
    case chooseInPreview

    var label: String {
        switch self {
        case .singleWindow: "Única janela do aplicativo"
        case .chooseInPreview: "Escolher na prévia"
        }
    }
}

enum SceneLayoutMissingDisplayPolicy: String, Codable, CaseIterable, Sendable {
    case stop
    case usePrimary

    var label: String {
        switch self {
        case .stop: "Interromper e manter as janelas"
        case .usePrimary: "Usar o monitor principal"
        }
    }
}

/// Externos são ordenados pela posição da mesa, da esquerda para a direita e de
/// cima para baixo. O vínculo exato com a tela atual existe apenas durante a prévia.
enum SceneLayoutDisplayRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case primary, builtIn, external1, external2, external3, external4
    var id: String { rawValue }
    var label: String {
        switch self {
        case .primary: "Monitor principal"
        case .builtIn: "Tela do Mac"
        case .external1: "Externo 1"
        case .external2: "Externo 2"
        case .external3: "Externo 3"
        case .external4: "Externo 4"
        }
    }
}

struct SceneLayoutRect: Codable, Hashable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    var isFinite: Bool { [x, y, width, height].allSatisfy(\.isFinite) && width > 0 && height > 0 }
    var isNormalized: Bool {
        isFinite && x >= 0 && y >= 0 && width >= 0.05 && height >= 0.05
            && x + width <= 1.001 && y + height <= 1.001
    }

    func normalized(in screen: SceneLayoutRect) -> SceneLayoutRect {
        .init(x: (x - screen.x) / screen.width, y: (y - screen.y) / screen.height,
              width: width / screen.width, height: height / screen.height)
    }
    func resolved(in screen: SceneLayoutRect) -> SceneLayoutRect {
        .init(x: screen.x + x * screen.width, y: screen.y + y * screen.height,
              width: width * screen.width, height: height * screen.height)
    }
    func isNear(_ other: SceneLayoutRect, tolerance: Double = 3) -> Bool {
        abs(x - other.x) <= tolerance && abs(y - other.y) <= tolerance
            && abs(width - other.width) <= tolerance && abs(height - other.height) <= tolerance
    }

    static let full = Self(x: 0, y: 0, width: 1, height: 1)
    static let left = Self(x: 0, y: 0, width: 0.5, height: 1)
    static let right = Self(x: 0.5, y: 0, width: 0.5, height: 1)
}
