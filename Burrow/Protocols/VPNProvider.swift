import Foundation

/// Abstraction for a VPN service provider's API.
///
/// Conform to this protocol to add support for a new VPN provider.
/// The app's ViewModels and Views interact only with this protocol,
/// keeping provider-specific logic isolated to the concrete implementation.
protocol VPNProvider: Sendable {
    /// Human-readable provider name (e.g. "Mullvad").
    var providerName: String { get }

    /// Placeholder text for the account input field (e.g. "0000 0000 0000 0000").
    var accountInputPlaceholder: String { get }

    /// Maximum character length of formatted account input.
    var accountInputMaxLength: Int { get }

    /// Format raw account input for display (e.g. group digits as "1234 5678 9012 3456").
    func formatAccountInput(_ input: String) -> String

    /// Validate whether the account input is ready for login.
    func validateAccountInput(_ input: String) -> Bool

    /// Authenticate with the provider and receive an access token.
    func authenticate(accountNumber: String) async throws -> AccountCredential

    /// Register a new device (WireGuard public key) with the provider.
    func registerDevice(token: String, publicKey: String) async throws -> Device

    /// Fetch the complete list of available relay servers.
    func fetchRelayList() async throws -> RelayList

    /// List all devices registered to the account.
    func listDevices(token: String) async throws -> [Device]

    /// Remove a device from the account.
    func removeDevice(token: String, deviceID: String) async throws
}
