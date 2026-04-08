import Foundation

/// Represents the current state of the VPN tunnel connection.
enum ConnectionStatus: Sendable, Equatable {
    case disconnected
    case connecting
    case connected(since: Date)
    case disconnecting

    /// Whether the tunnel is currently active (connecting or connected).
    var isActive: Bool {
        switch self {
            case .connecting, .connected:
                return true
            case .disconnected, .disconnecting:
                return false
        }
    }

    /// Human-readable description of the current status.
    var displayText: String {
        switch self {
            case .disconnected:
                return String(localized: "Disconnected")
            case .connecting:
                return String(localized: "Connecting...")
            case .connected:
                return String(localized: "Connected")
            case .disconnecting:
                return String(localized: "Disconnecting...")
        }
    }
}
