import Foundation
import Security

/// Concrete implementation of `KeychainStoring` using macOS Keychain Services.
final class KeychainService: KeychainStoring, Sendable {

    // MARK: - Properties

    private let serviceName: String

    // MARK: - Initialization

    nonisolated init(serviceName: String = "com.burrow.vpn") {
        self.serviceName = serviceName
    }

    // MARK: - KeychainStoring

    func save(_ data: Data, forKey key: String) throws {
        // Delete any existing item first
        try? delete(forKey: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }
    }

    func load(forKey key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.loadFailed(status: status)
        }
    }

    func delete(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status: status)
        }
    }
}

// MARK: - Errors

/// Errors specific to Keychain operations.
enum KeychainError: LocalizedError {
    case saveFailed(status: OSStatus)
    case loadFailed(status: OSStatus)
    case deleteFailed(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to Keychain (status: \(status))."
        case .loadFailed(let status):
            return "Failed to load from Keychain (status: \(status))."
        case .deleteFailed(let status):
            return "Failed to delete from Keychain (status: \(status))."
        }
    }
}

// MARK: - Well-Known Keys

extension KeychainService {
    /// Well-known Keychain key identifiers for Burrow.
    enum Key {
        static let accessToken = "burrow.accessToken"
        static let privateKey = "burrow.privateKey"
        static let accountNumber = "burrow.accountNumber"
        static let deviceInfo = "burrow.deviceInfo"
    }
}
