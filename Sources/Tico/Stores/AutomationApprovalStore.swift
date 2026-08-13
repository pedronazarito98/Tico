import CryptoKit
import Foundation

@MainActor
final class AutomationApprovalStore {
    private let defaults: UserDefaults
    private let storageKey: String

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = TicoBrand.userDefaultsPrefix + "approved-automations"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    func isApproved(_ content: String) -> Bool {
        approvedHashes.contains(hash(content))
    }

    func approve(_ content: String) {
        var hashes = approvedHashes
        hashes.insert(hash(content))
        defaults.set(Array(hashes), forKey: storageKey)
    }

    func revokeAll() {
        defaults.removeObject(forKey: storageKey)
    }

    private var approvedHashes: Set<String> {
        Set(defaults.stringArray(forKey: storageKey) ?? [])
    }

    private func hash(_ content: String) -> String {
        SHA256.hash(data: Data(content.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
