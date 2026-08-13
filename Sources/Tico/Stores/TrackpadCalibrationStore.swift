import Combine
import Foundation

final class TrackpadCalibrationStore: ObservableObject {
    static let currentVersion = 1

    @Published private(set) var calibrationSet: GestureCalibrationSet {
        didSet { persist() }
    }
    @Published private(set) var lastError: String?

    private let defaults: UserDefaults
    private let storageKey: String

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = TicoBrand.userDefaultsPrefix + "trackpad-calibration"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        if let data = defaults.data(forKey: storageKey) {
            do {
                let document = try JSONDecoder().decode(CalibrationDocument.self, from: data)
                guard document.version <= Self.currentVersion else {
                    throw CalibrationStoreError.unsupportedVersion(document.version)
                }
                calibrationSet = document.calibrations
            } catch {
                calibrationSet = GestureCalibrationSet()
                lastError = error.localizedDescription
            }
        } else {
            calibrationSet = GestureCalibrationSet()
        }
    }

    func calibration(for gesture: TrackpadGesture) -> GestureCalibration {
        calibrationSet.calibration(for: gesture)
    }

    func applyPreset(_ preset: GestureCalibrationPreset, to gesture: TrackpadGesture) {
        guard preset != .custom else { return }
        calibrationSet.values[gesture] = preset.calibration(for: gesture)
    }

    func update(_ calibration: GestureCalibration, for gesture: TrackpadGesture) {
        var value = calibration
        value.preset = .custom
        value.sensitivity = min(max(value.sensitivity, 0.25), 2)
        value.confidenceThreshold = min(max(value.confidenceThreshold, 0.1), 0.95)
        value.minimumVelocity = value.minimumVelocity.map { max(0, $0) }
        value.maximumVelocity = value.maximumVelocity.map { max(0, $0) }
        value.normalizeVelocityRange()
        calibrationSet.values[gesture] = value
    }

    func reset(_ gesture: TrackpadGesture) {
        calibrationSet.values.removeValue(forKey: gesture)
    }

    func resetAll() {
        calibrationSet = GestureCalibrationSet()
    }

    private func persist() {
        do {
            let document = CalibrationDocument(
                version: Self.currentVersion,
                calibrations: calibrationSet
            )
            defaults.set(try JSONEncoder().encode(document), forKey: storageKey)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }
}

private struct CalibrationDocument: Codable {
    let version: Int
    let calibrations: GestureCalibrationSet
}

private enum CalibrationStoreError: LocalizedError {
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case let .unsupportedVersion(version):
            "A calibração versão \(version) não é suportada."
        }
    }
}
