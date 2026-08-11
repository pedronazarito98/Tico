import Combine
import Foundation

enum AppCommand {
    case openMainWindow
    case createRule
    case deleteSelectedRule
    case startCapture
    case stopCapture
    case selectSection(AirShortcutSection)
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

/// Owns typed commands emitted by menus, shortcuts and the legacy notification bridge.
///
/// The pending envelope is consumed by the main window once. This keeps the
/// command owner explicit while allowing the existing notification names to
/// remain a compatibility boundary during the shell migration.
@MainActor
final class AppCommandRouter: ObservableObject {
    @Published private(set) var pendingCommand: PendingAppCommand?

    private let notificationCenter: NotificationCenter
    private var cancellables = Set<AnyCancellable>()
    private var consumedCommandID: UUID?

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        observeLegacyCommands()
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

    private func observeLegacyCommands() {
        observeLegacy(.airShortcutOpenMainWindow) { _ in .openMainWindow }
        observeLegacy(.airShortcutCreateRule) { _ in .createRule }
        observeLegacy(.airShortcutDeleteSelectedRule) { _ in .deleteSelectedRule }
        observeLegacy(.airShortcutStartCapture) { _ in .startCapture }
        observeLegacy(.airShortcutStopCapture) { _ in .stopCapture }
        observeLegacy(.airShortcutImportRules) { _ in .importRules }
        observeLegacy(.airShortcutExportRules) { _ in .exportRules }
        observeLegacy(.airShortcutSelectSection) { notification in
            guard let rawValue = notification.object as? String,
                  let section = AirShortcutSection(rawValue: rawValue) else {
                return nil
            }
            return .selectSection(section)
        }
    }

    private func observeLegacy(
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
