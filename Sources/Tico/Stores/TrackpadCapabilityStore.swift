import Combine
import Foundation

struct TrackpadDeviceCapability: Codable, Equatable, Hashable, Sendable {
    var deviceID: String
    var minimumObservedPressure: Double?
    var maximumObservedPressure: Double?
    var pressureSampleCount: Int
    var lastSeenAt: Date

    var hasReliablePressure: Bool {
        pressureSampleCount >= 20
            && (maximumObservedPressure ?? 0) - (minimumObservedPressure ?? 0) >= 0.08
    }
}

final class TrackpadCapabilityStore: ObservableObject {
    @Published private(set) var devices: [String: TrackpadDeviceCapability] = [:]

    private let defaults: UserDefaults
    private let storageKey: String

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = TicoBrand.userDefaultsPrefix + "trackpad-capabilities"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(
               [String: TrackpadDeviceCapability].self,
               from: data
           ) {
            devices = decoded
        }
    }

    func observe(deviceID: String?, pressure: Double?, at date: Date = Date()) {
        guard let pressure else { return }
        let id = deviceID ?? "default"
        var capability = devices[id] ?? TrackpadDeviceCapability(
            deviceID: id,
            minimumObservedPressure: nil,
            maximumObservedPressure: nil,
            pressureSampleCount: 0,
            lastSeenAt: date
        )
        capability.minimumObservedPressure = min(
            capability.minimumObservedPressure ?? pressure,
            pressure
        )
        capability.maximumObservedPressure = max(
            capability.maximumObservedPressure ?? pressure,
            pressure
        )
        capability.pressureSampleCount += 1
        capability.lastSeenAt = date
        devices[id] = capability
        if capability.pressureSampleCount % 10 == 0 {
            persist()
        }
    }

    func reset(deviceID: String) {
        devices[deviceID] = nil
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(devices) else { return }
        defaults.set(data, forKey: storageKey)
    }
}
