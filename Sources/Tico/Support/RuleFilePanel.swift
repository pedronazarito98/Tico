import AppKit
import UniformTypeIdentifiers

@MainActor
enum RuleFilePanel {
    static func chooseImportURL() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Importar regras do \(TicoBrand.displayName)"
        panel.prompt = "Importar"
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func chooseExportURL() -> URL? {
        let panel = NSSavePanel()
        panel.title = "Exportar regras do \(TicoBrand.displayName)"
        panel.prompt = "Exportar"
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(TicoBrand.displayName)-rules.json"
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }
}
