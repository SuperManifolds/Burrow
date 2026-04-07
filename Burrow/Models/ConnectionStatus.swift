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
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .disconnecting:
            return "Disconnecting..."
        }
    }
}
