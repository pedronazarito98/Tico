import Combine
import Foundation

enum AppCommand {
    case openMainWindow
    case createRule
    case deleteSelectedRule
    case startCapture
    case stopCapture
    case selectSection(TicoSection)
    case importRules
    case exportRules
}

struct PendingAppCommand: Identifiable {
    let id: UUID
    let command: AppCommand

    init(id: UUID = UUID(), command: AppCommand) {
        self.id = id
        self.command = command
    }
}

/// Owns typed commands emitted by menus, shortcuts and app notifications.
///
/// The pending envelope is consumed by the main window once. This keeps the
/// command owner explicit while keeping notification handling in one place.
@MainActor
final class AppCommandRouter: ObservableObject {
    @Published private(set) var pendingCommand: PendingAppCommand?

    private let notificationCenter: NotificationCenter
    private var cancellables = Set<AnyCancellable>()
    private var consumedCommandID: UUID?

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        observeNotifications()
    }

    func send(_ command: AppCommand) {
        pendingCommand = PendingAppCommand(command: command)
    }

    func consume(_ envelope: PendingAppCommand) -> AppCommand? {
        guard pendingCommand?.id == envelope.id,
              consumedCommandID != envelope.id else {
            return nil
        }
        consumedCommandID = envelope.id
        pendingCommand = nil
        return envelope.command
    }

    private func observeNotifications() {
        observe(.ticoOpenMainWindow) { _ in .openMainWindow }
        observe(.ticoCreateRule) { _ in .createRule }
        observe(.ticoDeleteSelectedRule) { _ in .deleteSelectedRule }
        observe(.ticoStartCapture) { _ in .startCapture }
        observe(.ticoStopCapture) { _ in .stopCapture }
        observe(.ticoImportRules) { _ in .importRules }
        observe(.ticoExportRules) { _ in .exportRules }
        observe(.ticoSelectSection) { notification in
            guard let rawValue = notification.object as? String,
                  let section = TicoSection(rawValue: rawValue) else {
                return nil
            }
            return .selectSection(section)
        }
    }

    private func observe(
        _ name: Notification.Name,
        decode: @escaping (Notification) -> AppCommand?
    ) {
        notificationCenter.publisher(for: name)
            .sink { [weak self] notification in
                guard let command = decode(notification) else { return }
                Task { @MainActor [weak self] in
                    self?.send(command)
                }
            }
            .store(in: &cancellables)
    }
}
