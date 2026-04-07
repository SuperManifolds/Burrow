import Foundation

/// A single WireGuard relay server from Mullvad's relay list.
struct Relay: Sendable, Codable, Equatable, Identifiable {
    /// Hostname identifier (e.g. "us-nyc-wg-001").
    let hostname: String

    /// Location key mapping to `RelayLocation` (e.g. "us-nyc").
    let location: String

    /// Whether this relay is currently accepting connections.
    let active: Bool

    /// Whether this relay is owned by Mullvad (vs. rented).
    let owned: Bool

    /// Hosting provider identifier.
    let provider: String

    /// Public IPv4 address for WireGuard connections.
    let ipv4AddrIn: String

    /// Public IPv6 address for WireGuard connections.
    let ipv6AddrIn: String

    /// WireGuard public key (base64-encoded).
    let publicKey: String

    /// Selection weight for load balancing.
    let weight: Int

    var id: String { hostname }
}
