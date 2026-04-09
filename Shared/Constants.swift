import Foundation

/// Centralized app identifiers used across the project.
enum AppIdentifiers: Sendable {
    /// Main app bundle identifier.
    nonisolated static let bundleID = "io.sorlie.Burrow"

    /// Network Extension tunnel bundle identifier.
    nonisolated static let tunnelBundleID = "io.sorlie.Burrow.BurrowTunnel"

    /// App group shared between the app and tunnel extension.
    nonisolated static let appGroup = "group.com.burrow.vpn"
}

/// JSON structure for transfer stats shared between app and tunnel extension.
struct TransferStats: Sendable {
    let tx: UInt64
    let rx: UInt64
}

extension TransferStats: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.tx = try container.decode(UInt64.self, forKey: .tx)
        self.rx = try container.decode(UInt64.self, forKey: .rx)
    }
}

/// Default tunnel configuration values.
enum TunnelDefaults: Sendable {
    nonisolated static let port = 51820
    nonisolated static let dns = "10.64.0.1"
    nonisolated static let mtu = 1280
}
