import Foundation

/// Status values used in XPC communication between app and daemon.
enum DaemonStatus: String {
    case disconnected
    case connecting
    case connected
    case disconnecting
}

/// XPC protocol for communication between the Burrow app and BurrowDaemon.
///
/// The daemon manages a gotatun-cli process that creates a direct utun
/// interface, bypassing NEPacketTunnelProvider for higher throughput.
@objc protocol BurrowDaemonXPC {

    /// Start a WireGuard tunnel via gotatun-cli.
    /// - Parameters:
    ///   - privateKey: Base64-encoded 32-byte WireGuard private key.
    ///   - addresses: Comma-separated CIDR addresses (e.g. "10.64.0.1/32, fc00::1/128").
    ///   - peerPublicKey: Base64-encoded peer public key.
    ///   - peerEndpoint: Peer endpoint as "IP:port".
    ///   - dns: DNS server address.
    ///   - mtu: MTU value.
    ///   - reply: Callback with nil on success, or an error.
    func connect(
        privateKey: String,
        addresses: String,
        peerPublicKey: String,
        peerEndpoint: String,
        dns: String,
        mtu: Int,
        reply: @escaping (NSError?) -> Void
    )

    /// Stop the tunnel and tear down the interface.
    func disconnect(reply: @escaping () -> Void)

    /// Get the current connection status.
    /// - Parameter reply: Callback with status string ("connected", "disconnected", "connecting").
    func getStatus(reply: @escaping (String) -> Void)

    /// Ask the daemon to exit so launchd restarts it with the latest binary.
    func restart(reply: @escaping () -> Void)
}
