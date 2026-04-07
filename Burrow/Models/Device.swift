import Foundation

/// A WireGuard device registered with Mullvad's API.
struct Device: Sendable, Codable, Equatable, Identifiable {
    /// Unique device identifier assigned by Mullvad.
    let id: String

    /// Human-readable device name.
    let name: String

    /// WireGuard public key (base64-encoded).
    let pubkey: String

    /// Assigned IPv4 tunnel address (e.g. "10.x.x.x/32").
    let ipv4Address: String

    /// Assigned IPv6 tunnel address (e.g. "fc00:.../128").
    let ipv6Address: String
}
