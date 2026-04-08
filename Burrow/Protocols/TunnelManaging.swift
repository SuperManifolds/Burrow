import Combine
import Foundation

/// Abstraction for VPN tunnel lifecycle management.
///
/// Conform to this protocol to provide a different tunnel backend
/// (e.g. OpenVPN, custom WireGuard, test doubles).
@MainActor
protocol TunnelManaging: AnyObject {
    /// The current connection status of the tunnel.
    var status: ConnectionStatus { get }

    /// Publisher for observing status changes.
    var statusPublisher: Published<ConnectionStatus>.Publisher { get }

    /// The relay currently connected to, if any.
    var connectedRelay: Relay? { get }

    /// Publisher for observing connected relay changes.
    var connectedRelayPublisher: Published<Relay?>.Publisher { get }

    /// When the current connection was established.
    var connectedDate: Date? { get }

    /// Connect to a specific relay server.
    /// - Parameters:
    ///   - relay: The relay server to connect to.
    ///   - device: The registered device with tunnel addresses.
    ///   - privateKey: The WireGuard private key (raw 32 bytes).
    ///   - port: The WireGuard port to use.
    ///   - dns: The DNS server address.
    func connect(
        to relay: Relay,
        with device: Device,
        privateKey: Data,
        port: Int,
        dns: String
    ) async throws

    /// Disconnect from the current relay server.
    func disconnect() async

    /// Read diagnostic log from the tunnel extension.
    func readTunnelLog() -> String?
}

// MARK: - Default Parameters

extension TunnelManaging {
    /// Convenience connect with default port and DNS.
    func connect(
        to relay: Relay,
        with device: Device,
        privateKey: Data
    ) async throws {
        try await connect(
            to: relay,
            with: device,
            privateKey: privateKey,
            port: 51820,
            dns: "10.64.0.1"
        )
    }
}

// MARK: - Mock for Previews and Tests

#if DEBUG
@MainActor
final class MockTunnelManager: TunnelManaging {
    @Published private(set) var status: ConnectionStatus
    @Published private(set) var connectedRelay: Relay?
    @Published private(set) var connectedDate: Date?

    var statusPublisher: Published<ConnectionStatus>.Publisher { $status }
    var connectedRelayPublisher: Published<Relay?>.Publisher { $connectedRelay }

    init(status: ConnectionStatus = .disconnected, connectedRelay: Relay? = nil) {
        self.status = status
        self.connectedRelay = connectedRelay
        self.connectedDate = nil
    }

    func connect(
        to relay: Relay,
        with device: Device,
        privateKey: Data,
        port: Int,
        dns: String
    ) async throws {
        status = .connecting
        connectedRelay = relay
    }

    func disconnect() async {
        status = .disconnected
        connectedRelay = nil
        connectedDate = nil
    }

    func readTunnelLog() -> String? { nil }
}
#endif
