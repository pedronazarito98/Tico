import SwiftUI

@MainActor
public struct TicoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var shortcutStore: ShortcutStore
    @StateObject private var settings: AppSettingsStore
    @StateObject private var eventLogStore: EventLogStore
    @StateObject private var permissions: PermissionCoordinator
    @StateObject private var calibrationStore: TrackpadCalibrationStore
    @StateObject private var validationStore: TrackpadValidationStore
    @StateObject private var controller: AppController
    @StateObject private var commandRouter: AppCommandRouter
    private let lifecycle: any ApplicationLifecycleControlling

    public init() {
        let launchConfiguration = TicoLaunchConfiguration.current()
        let shortcutStore = ShortcutStore(
            fileURL: launchConfiguration.fileURL(named: "shortcuts.json")
        )
        let settings = AppSettingsStore(defaults: launchConfiguration.defaults)
        let eventLogStore = EventLogStore(
            fileURL: launchConfiguration.fileURL(named: "execution-log.json")
        )
        let permissions = launchConfiguration.makePermissionCoordinator()
        let calibrationStore = TrackpadCalibrationStore(defaults: launchConfiguration.defaults)
        let validationStore = TrackpadValidationStore(defaults: launchConfiguration.defaults)
        let metricsStore = MetricsStore(
            fileURL: launchConfiguration.fileURL(named: "metrics.json")
        )
        let capabilityStore = TrackpadCapabilityStore(defaults: launchConfiguration.defaults)
        let approvalStore = AutomationApprovalStore(defaults: launchConfiguration.defaults)
        let commandRouter: AppCommandRouter = AppCommandRouter()
        let lifecycle: any ApplicationLifecycleControlling = ApplicationLifecycleService()
        _shortcutStore = StateObject(wrappedValue: shortcutStore)
        _settings = StateObject(wrappedValue: settings)
        _eventLogStore = StateObject(wrappedValue: eventLogStore)
        _permissions = StateObject(wrappedValue: permissions)
        _calibrationStore = StateObject(wrappedValue: calibrationStore)
        _validationStore = StateObject(wrappedValue: validationStore)
        _controller = StateObject(
            wrappedValue: AppController(
                shortcutStore: shortcutStore,
                settings: settings,
                eventLogStore: eventLogStore,
                permissions: permissions,
                calibrationStore: calibrationStore,
                validationStore: validationStore,
                metricsStore: metricsStore,
                capabilityStore: capabilityStore,
                approvalStore: approvalStore,
                macOSShortcutCatalog: launchConfiguration.makeMacOSShortcutCatalog()
            )
        )
        _commandRouter = StateObject(wrappedValue: commandRouter)
        self.lifecycle = lifecycle
    }

    public var body: some Scene {
        WindowGroup(TicoBrand.displayName, id: "main") {
            ContentView(
                controller: controller,
                shortcutStore: shortcutStore,
                eventLogStore: eventLogStore,
                permissions: permissions,
                commandRouter: commandRouter
            )
            .tint(TicoBrand.Palette.primary)
        }
        .defaultSize(width: 1_080, height: 700)
        .commands {
            TicoCommands(commandRouter: commandRouter)
        }

        Settings {
            SettingsView(settings: settings)
                .tint(TicoBrand.Palette.primary)
        }

        MenuBarExtra(isInserted: menuBarExtraIsInserted) {
            MenuBarContentView(
                controller: controller,
                shortcutStore: shortcutStore,
                lifecycle: lifecycle
            )
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Image(nsImage: TicoBrand.Assets.menuBarImage)
                    .frame(width: 18, height: 18)

                if controller.captureIsRunning {
                    Circle()
                        .fill(.primary)
                        .frame(width: 5, height: 5)
                        .overlay {
                            Circle().stroke(.background, lineWidth: 1)
                        }
                }
            }
            .accessibilityLabel(TicoBrand.displayName)
            .accessibilityValue(controller.captureIsRunning ? "Captura ativa" : "Captura pausada")
        }
    }

    private var menuBarExtraIsInserted: Binding<Bool> {
        Binding(
            get: { settings.showMenuBarExtra },
            set: { isInserted in
                // MenuBarExtra may write its current value while SwiftUI is
                // updating scenes. Re-publishing an unchanged value creates a
                // scene-update feedback loop and freezes the whole app.
                guard settings.showMenuBarExtra != isInserted else { return }
                settings.showMenuBarExtra = isInserted
            }
        )
    }
}
