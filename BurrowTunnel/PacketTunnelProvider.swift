import Foundation
import Network
import NetworkExtension
import os
import WireGuardKit

/// NEPacketTunnelProvider subclass that manages the WireGuard tunnel using WireGuardKit.
///
/// This runs in a separate process as a Network Extension. The main Burrow app communicates
/// with it via NETunnelProviderManager and NETunnelProviderSession.
class PacketTunnelProvider: NEPacketTunnelProvider {

    // MARK: - Properties

    private lazy var adapter: WireGuardAdapter = {
        WireGuardAdapter(with: self) { logLevel, message in
            wg_log(logLevel.osLogLevel, message: message)
        }
    }()

    // MARK: - Tunnel Lifecycle

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        guard let protocolConfig = protocolConfiguration as? NETunnelProviderProtocol,
              let providerConfig = protocolConfig.providerConfiguration else {
            completionHandler(PacketTunnelError.missingConfiguration)
            return
        }

        // Build TunnelConfiguration from serialized parameters
        guard let tunnelConfig = buildTunnelConfiguration(from: providerConfig) else {
            completionHandler(PacketTunnelError.invalidConfiguration)
            return
        }

        adapter.start(tunnelConfiguration: tunnelConfig) { adapterError in
            if let error = adapterError {
                wg_log(.error, message: "Failed to start WireGuard adapter: \(error)")
                completionHandler(error)
            } else {
                completionHandler(nil)
            }
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        adapter.stop { error in
            if let error {
                wg_log(.error, message: "Failed to stop WireGuard adapter: \(error)")
            }
            completionHandler()
        }
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        completionHandler?("ok".data(using: .utf8))
    }

    override func sleep(completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    override func wake() {
        // No-op: WireGuardKit handles reconnection on wake
    }

    // MARK: - Configuration Builder

    /// Build a WireGuardKit TunnelConfiguration from the provider configuration dictionary.
    ///
    /// Expected keys in providerConfig:
    /// - `privateKey`: Base64-encoded 32-byte private key
    /// - `addresses`: Comma-separated CIDR addresses (e.g. "10.64.0.1/32, fc00::1/128")
    /// - `dns`: DNS server IP (e.g. "10.64.0.1")
    /// - `peerPublicKey`: Base64-encoded peer public key
    /// - `peerEndpoint`: Endpoint string (e.g. "193.27.12.1:51820")
    /// - `peerAllowedIPs`: Comma-separated CIDR ranges (e.g. "0.0.0.0/0, ::/0")
    private func buildTunnelConfiguration(from config: [String: Any]) -> TunnelConfiguration? {
        guard let privateKeyBase64 = config["privateKey"] as? String,
              let privateKey = PrivateKey(base64Key: privateKeyBase64),
              let addressesString = config["addresses"] as? String,
              let dnsString = config["dns"] as? String,
              let peerPublicKeyBase64 = config["peerPublicKey"] as? String,
              let peerPublicKey = PublicKey(base64Key: peerPublicKeyBase64),
              let peerEndpointString = config["peerEndpoint"] as? String,
              let peerEndpoint = Endpoint(from: peerEndpointString),
              let allowedIPsString = config["peerAllowedIPs"] as? String else {
            return nil
        }

        // Build interface
        var interfaceConfig = InterfaceConfiguration(privateKey: privateKey)
        interfaceConfig.addresses = addressesString
            .split(separator: ",")
            .compactMap { IPAddressRange(from: String($0.trimmingCharacters(in: .whitespaces))) }
        interfaceConfig.dns = dnsString
            .split(separator: ",")
            .compactMap { DNSServer(from: String($0.trimmingCharacters(in: .whitespaces))) }

        // Build peer
        var peerConfig = PeerConfiguration(publicKey: peerPublicKey)
        peerConfig.endpoint = peerEndpoint
        peerConfig.allowedIPs = allowedIPsString
            .split(separator: ",")
            .compactMap { IPAddressRange(from: String($0.trimmingCharacters(in: .whitespaces))) }

        return TunnelConfiguration(
            name: "Burrow",
            interface: interfaceConfig,
            peers: [peerConfig]
        )
    }
}

// MARK: - Error Types

enum PacketTunnelError: LocalizedError {
    case missingConfiguration
    case invalidConfiguration

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "No WireGuard configuration found in tunnel provider settings."
        case .invalidConfiguration:
            return "The WireGuard configuration could not be parsed."
        }
    }
}

// MARK: - Logging

private func wg_log(_ level: OSLogType, message: String) {
    NSLog("[Burrow Tunnel] [\(level)] \(message)")
}

extension WireGuardLogLevel {
    var osLogLevel: OSLogType {
        switch self {
        case .verbose:
            return .debug
        case .error:
            return .error
        }
    }
}
