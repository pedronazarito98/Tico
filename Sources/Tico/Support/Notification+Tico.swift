import Foundation

extension Notification.Name {
    static let ticoOpenMainWindow = Notification.Name("Tico.openMainWindow")
    static let ticoCreateRule = Notification.Name("Tico.createRule")
    static let ticoDeleteSelectedRule = Notification.Name("Tico.deleteSelectedRule")
    static let ticoStartCapture = Notification.Name("Tico.startCapture")
    static let ticoStopCapture = Notification.Name("Tico.stopCapture")
    static let ticoSelectSection = Notification.Name("Tico.selectSection")
    static let ticoImportRules = Notification.Name("Tico.importRules")
    static let ticoExportRules = Notification.Name("Tico.exportRules")
}
