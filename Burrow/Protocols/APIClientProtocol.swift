import Foundation

/// Abstraction for Mullvad's REST API.
protocol APIClientProtocol: Sendable {
    /// Authenticate with a Mullvad account number and receive an access token.
    /// - Parameter accountNumber: The 16-digit Mullvad account number.
    /// - Returns: Account credentials with access token and expiry.
    func authenticate(accountNumber: String) async throws -> AccountCredential

    /// Register a new WireGuard device (public key) with Mullvad.
    /// - Parameters:
    ///   - token: A valid access token from `authenticate`.
    ///   - publicKey: Base64-encoded WireGuard public key.
    /// - Returns: The registered device with assigned tunnel addresses.
    func registerDevice(token: String, publicKey: String) async throws -> Device

    /// Fetch the complete list of available WireGuard relays.
    /// - Returns: The full relay list including locations and server details.
    func fetchRelayList() async throws -> RelayList
}
