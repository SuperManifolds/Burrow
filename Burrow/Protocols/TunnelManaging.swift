import Foundation

/// Abstraction for VPN tunnel lifecycle management.
protocol TunnelManaging: Sendable {
    /// The current connection status of the tunnel.
    var status: ConnectionStatus { get async }

    /// Connect to a specific relay server.
    /// - Parameters:
    ///   - relay: The relay server to connect to.
    ///   - device: The registered device with tunnel addresses.
    ///   - privateKey: The WireGuard private key (raw 32 bytes).
    func connect(to relay: Relay, with device: Device, privateKey: Data) async throws

    /// Disconnect from the current relay server.
    func disconnect() async throws
}
