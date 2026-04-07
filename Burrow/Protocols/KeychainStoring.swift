import Foundation

/// Abstraction for secure credential storage.
protocol KeychainStoring: Sendable {
    /// Save data to the keychain under the given key.
    /// - Parameters:
    ///   - data: The data to store.
    ///   - key: A unique key identifier.
    func save(_ data: Data, forKey key: String) throws

    /// Load data from the keychain for the given key.
    /// - Parameter key: The key identifier to look up.
    /// - Returns: The stored data, or `nil` if not found.
    func load(forKey key: String) throws -> Data?

    /// Delete data from the keychain for the given key.
    /// - Parameter key: The key identifier to delete.
    func delete(forKey key: String) throws
}
