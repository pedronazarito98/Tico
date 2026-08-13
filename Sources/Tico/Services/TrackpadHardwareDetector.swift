import Foundation
import IOKit.hid

struct TrackpadHardwareDetector {
    func detect() -> [TrackpadHardwareInfo] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let matching: [String: Any] = [
            kIOHIDDeviceUsagePageKey as String: kHIDPage_Digitizer,
            kIOHIDDeviceUsageKey as String: kHIDUsage_Dig_TouchPad
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        guard let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            return []
        }

        return deviceSet.compactMap { device in
            let name = property(kIOHIDProductKey, from: device) as? String
                ?? "Trackpad sem nome"
            let transport = property(kIOHIDTransportKey, from: device) as? String
                ?? "Desconhecido"
            let builtIn = (property(kIOHIDBuiltInKey, from: device) as? NSNumber)?.boolValue
                ?? transport.localizedCaseInsensitiveContains("SPI")
            let location = (property(kIOHIDLocationIDKey, from: device) as? NSNumber)?
                .stringValue ?? (builtIn ? "built-in" : "external")
            return TrackpadHardwareInfo(
                id: "\(name)-\(transport)-\(location)",
                name: name,
                transport: transport,
                isBuiltIn: builtIn
            )
        }
        .sorted {
            if $0.isBuiltIn != $1.isBuiltIn { return $0.isBuiltIn }
            return $0.name < $1.name
        }
    }

    private func property(_ key: String, from device: IOHIDDevice) -> Any? {
        IOHIDDeviceGetProperty(device, key as CFString)
    }
}
