import Combine
import Foundation
import NetworkExtension

/// Manages the VPN tunnel lifecycle using NETunnelProviderManager.
///
/// This class handles creating, configuring, starting, and stopping the WireGuard
/// tunnel via the Network Extension framework. It communicates with the
/// `PacketTunnelProvider` running in the BurrowTunnel extension.
@MainActor
final class TunnelManager: ObservableObject {

    // MARK: - Published State

    @Published private(set) var status: ConnectionStatus = .disconnected
    @Published private(set) var connectedRelay: Relay?
    @Published private(set) var connectedDate: Date?

    // MARK: - Properties

    private var tunnelManager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?

    /// The bundle identifier for the Network Extension target.
    private let tunnelBundleIdentifier = "com.burrow.vpn.tunnel"

    /// The app group used to share data between the app and extension.
    private let appGroupIdentifier = "group.com.burrow.vpn"

    // MARK: - Initialization

    init() {
        observeStatusChanges()
    }

    deinit {
        if let observer = statusObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public API

    /// Load or create the tunnel provider manager.
    func loadTunnelManager() async throws {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()

        if let existing = managers.first(where: {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?
                .providerBundleIdentifier == tunnelBundleIdentifier
        }) {
            tunnelManager = existing
        } else {
            tunnelManager = NETunnelProviderManager()
        }
    }

    /// Connect to a relay server.
    /// - Parameters:
    ///   - relay: The relay to connect to.
    ///   - device: The registered device with tunnel addresses.
    ///   - privateKey: Raw 32-byte WireGuard private key.
    ///   - port: The port to connect on (default 51820).
    func connect(
        to relay: Relay,
        with device: Device,
        privateKey: Data,
        port: Int = 51820
    ) async throws {
        guard let manager = tunnelManager else {
            try await loadTunnelManager()
            try await connect(to: relay, with: device, privateKey: privateKey, port: port)
            return
        }

        // Configure the tunnel provider with structured parameters
        let protocolConfig = NETunnelProviderProtocol()
        protocolConfig.providerBundleIdentifier = tunnelBundleIdentifier
        protocolConfig.serverAddress = "\(relay.ipv4AddrIn):\(port)"
        protocolConfig.providerConfiguration = [
            "privateKey": privateKey.base64EncodedString(),
            "addresses": "\(device.ipv4Address), \(device.ipv6Address)",
            "dns": "10.64.0.1",
            "peerPublicKey": relay.publicKey,
            "peerEndpoint": "\(relay.ipv4AddrIn):\(port)",
            "peerAllowedIPs": "0.0.0.0/0, ::/0"
        ]

        manager.protocolConfiguration = protocolConfig
        manager.localizedDescription = "Burrow VPN"
        manager.isEnabled = true

        // Save and start
        try await manager.saveToPreferences()
        try await manager.loadFromPreferences()

        let session = manager.connection as? NETunnelProviderSession
        try session?.startTunnel(options: nil)

        connectedRelay = relay
        status = .connecting
    }

    /// Disconnect from the current relay.
    func disconnect() async {
        guard let manager = tunnelManager else { return }
        manager.connection.stopVPNTunnel()
        connectedRelay = nil
        status = .disconnecting
    }

    // MARK: - Status Observation

    private func observeStatusChanges() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let connection = notification.object as? NEVPNConnection else {
                return
            }
            Task { @MainActor in
                self.updateStatus(from: connection.status)
            }
        }
    }

    private func updateStatus(from vpnStatus: NEVPNStatus) {
        switch vpnStatus {
        case .disconnected, .invalid:
            status = .disconnected
            connectedDate = nil
            connectedRelay = nil
        case .connecting, .reasserting:
            status = .connecting
        case .connected:
            connectedDate = Date()
            status = .connected(since: connectedDate ?? Date())
        case .disconnecting:
            status = .disconnecting
        @unknown default:
            status = .disconnected
        }
    }
}


