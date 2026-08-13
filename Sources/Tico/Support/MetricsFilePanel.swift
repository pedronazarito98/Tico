import AppKit
import UniformTypeIdentifiers

@MainActor
enum MetricsFilePanel {
    static func chooseExportURL() -> URL? {
        let panel = NSSavePanel()
        panel.title = "Exportar métricas"
        panel.nameFieldStringValue = "tico-metricas.csv"
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true
        return panel.runModal() == .OK ? panel.url : nil
    }
}

