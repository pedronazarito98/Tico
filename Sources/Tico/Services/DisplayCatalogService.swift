import AppKit

/// Catálogo transitório para a condição de monitor. Usa a mesma identidade do
/// WindowContextReader; identificadores não aparecem em rótulos nem em diagnósticos.
@MainActor
enum DisplayCatalogService {
    struct Choice: Identifiable {
        let id: String
        let name: String
    }

    static func availableDisplays() -> [Choice] {
        NSScreen.screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] else { return nil }
            return Choice(id: String(describing: number), name: screen.localizedName)
        }
    }
}
