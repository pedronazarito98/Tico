import Combine
import Foundation

final class AppSettingsStore: ObservableObject {
    static let currentSettingsVersion = 1

    @Published var launchAtLogin: Bool {
        didSet { persist(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    @Published var showMenuBarExtra: Bool {
        didSet { persist(showMenuBarExtra, forKey: Keys.showMenuBarExtra) }
    }

    @Published var startEventCaptureOnLaunch: Bool {
        didSet { persist(startEventCaptureOnLaunch, forKey: Keys.startEventCaptureOnLaunch) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
        showMenuBarExtra = defaults.object(forKey: Keys.showMenuBarExtra) as? Bool ?? true
        startEventCaptureOnLaunch = defaults.object(forKey: Keys.startEventCaptureOnLaunch) as? Bool ?? false
        defaults.set(Self.currentSettingsVersion, forKey: Keys.version)
    }

    func reset() {
        launchAtLogin = false
        showMenuBarExtra = true
        startEventCaptureOnLaunch = false
        defaults.set(Self.currentSettingsVersion, forKey: Keys.version)
    }

    private func persist(_ value: Bool, forKey key: String) {
        defaults.set(value, forKey: key)
        defaults.set(Self.currentSettingsVersion, forKey: Keys.version)
    }

    private enum Keys {
        static let prefix = TicoBrand.userDefaultsPrefix + "settings."
        static let version = prefix + "version"
        static let launchAtLogin = prefix + "launchAtLogin"
        static let showMenuBarExtra = prefix + "showMenuBarExtra"
        static let startEventCaptureOnLaunch = prefix + "startEventCaptureOnLaunch"
    }
}
