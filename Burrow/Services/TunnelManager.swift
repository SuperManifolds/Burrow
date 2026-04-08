import Combine
import Foundation
import NetworkExtension

/// Manages the VPN tunnel lifecycle using NETunnelProviderManager.
///
/// This class handles creating, configuring, starting, and stopping the WireGuard
/// tunnel via the Network Extension framework. It communicates with the
/// `PacketTunnelProvider` running in the BurrowTunnel extension.
@MainActor
final class TunnelManager: ObservableObject, TunnelManaging {

    // MARK: - Published State

    @Published private(set) var status: ConnectionStatus = .disconnected
    @Published private(set) var connectedRelay: Relay?
    @Published private(set) var connectedDate: Date?

    // MARK: - Properties

    private var tunnelManager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?

    /// The bundle identifier for the Network Extension target.
    private let tunnelBundleIdentifier = "io.sorlie.Burrow.BurrowTunnel"

    /// The app group used to share data between the app and extension.
    private let appGroupIdentifier = "group.com.burrow.vpn"

    /// Read the diagnostic log from the tunnel extension.
    func readTunnelLog() -> String? {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent("tunnel.log") else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

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
        print("[Burrow TunnelManager] Found \(managers.count) existing managers")

        if let existing = managers.first(where: {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?
                .providerBundleIdentifier == tunnelBundleIdentifier
        }) {
            print("[Burrow TunnelManager] Reusing existing manager")
            tunnelManager = existing
        } else {
            print("[Burrow TunnelManager] Creating new manager for \(tunnelBundleIdentifier)")
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
        port: Int = 51820,
        dns: String = "10.64.0.1"
    ) async throws {
        guard let manager = tunnelManager else {
            try await loadTunnelManager()
            try await connect(to: relay, with: device, privateKey: privateKey, port: port, dns: dns)
            return
        }

        // Configure the tunnel provider with structured parameters
        let protocolConfig = NETunnelProviderProtocol()
        protocolConfig.providerBundleIdentifier = tunnelBundleIdentifier
        protocolConfig.serverAddress = relay.ipv4AddrIn
        protocolConfig.providerConfiguration = [
            "privateKey": privateKey.base64EncodedString(),
            "addresses": "\(device.ipv4Address), \(device.ipv6Address)",
            "dns": dns,
            "peerPublicKey": relay.publicKey,
            "peerEndpoint": "\(relay.ipv4AddrIn):\(port)",
            "peerAllowedIPs": "0.0.0.0/0, ::/0"
        ]

        manager.protocolConfiguration = protocolConfig
        manager.localizedDescription = "Burrow VPN"
        manager.isEnabled = true

        // Save and start
        print("[Burrow TunnelManager] Saving preferences...")
        try await manager.saveToPreferences()
        print("[Burrow TunnelManager] Loading preferences...")
        try await manager.loadFromPreferences()

        guard let session = manager.connection as? NETunnelProviderSession else {
            print("[Burrow TunnelManager] ERROR: connection is not NETunnelProviderSession, got: \(type(of: manager.connection))")
            throw TunnelError.invalidSession
        }

        print("[Burrow TunnelManager] Starting tunnel...")
        try session.startTunnel(options: nil)
        print("[Burrow TunnelManager] startTunnel called successfully")

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

    enum TunnelError: LocalizedError {
        case invalidSession

        var errorDescription: String? {
            switch self {
                case .invalidSession:
                    return "Failed to create tunnel session."
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
