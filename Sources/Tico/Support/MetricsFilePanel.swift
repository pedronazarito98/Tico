import AppKit
import UniformTypeIdentifiers

@MainActor
enum MetricsFilePanel {
    static func chooseExportURL() -> URL? {
        let panel = NSSavePanel()
        panel.title = "Exportar atividade"
        panel.nameFieldStringValue = "tico-atividade.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }
}

