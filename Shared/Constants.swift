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

/// Default tunnel configuration values.
enum TunnelDefaults {
    static let port = 51820
    static let dns = "10.64.0.1"
    static let mtu = 1280
}
