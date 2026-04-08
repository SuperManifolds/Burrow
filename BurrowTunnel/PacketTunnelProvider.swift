import Foundation
import Network
import NetworkExtension
import os
import WireGuardKit

/// Simple file logger that writes to the shared app group container.
/// Both the main app and extension can read/write this file.
private enum TunnelLog {
    static let logURL: URL? = {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: AppIdentifiers.appGroup)?
            .appendingPathComponent("tunnel.log")
    }()

    static func write(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(message)\n"
        NSLog("[Burrow Tunnel] \(message)")

        guard let url = logURL else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            handle.closeFile()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    static func clear() {
        guard let url = logURL else { return }
        try? "".write(to: url, atomically: true, encoding: .utf8)
    }
}

/// NEPacketTunnelProvider subclass that manages the WireGuard tunnel using WireGuardKit.
///
/// This runs in a separate process as a Network Extension. The main Burrow app communicates
/// with it via NETunnelProviderManager and NETunnelProviderSession.
class PacketTunnelProvider: NEPacketTunnelProvider {

    // MARK: - Properties

    private lazy var adapter: WireGuardAdapter = {
        WireGuardAdapter(with: self, shouldHandleReasserting: false) { logLevel, message in
            TunnelLog.write("[WireGuard \(logLevel)] \(message)")
        }
    }()

    // MARK: - Tunnel Lifecycle

    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        TunnelLog.clear()
        TunnelLog.write("startTunnel called")

        guard let protocolConfig = protocolConfiguration as? NETunnelProviderProtocol,
              let providerConfig = protocolConfig.providerConfiguration else {
            TunnelLog.write("ERROR: missing protocol configuration")
            completionHandler(PacketTunnelError.missingConfiguration)
            return
        }

        // Log the config keys (not values, for security)
        TunnelLog.write("providerConfig keys: \(providerConfig.keys.sorted())")
        TunnelLog.write("serverAddress: \(protocolConfig.serverAddress ?? "nil")")

        // Log addresses to verify CIDR format
        if let addresses = providerConfig["addresses"] as? String {
            TunnelLog.write("addresses: \(addresses)")
        }
        if let dns = providerConfig["dns"] as? String {
            TunnelLog.write("dns: \(dns)")
        }
        if let endpoint = providerConfig["peerEndpoint"] as? String {
            TunnelLog.write("peerEndpoint: \(endpoint)")
        }
        if let allowedIPs = providerConfig["peerAllowedIPs"] as? String {
            TunnelLog.write("peerAllowedIPs: \(allowedIPs)")
        }

        // Build TunnelConfiguration from serialized parameters
        guard let tunnelConfig = buildTunnelConfiguration(from: providerConfig) else {
            TunnelLog.write("ERROR: failed to build tunnel configuration")
            completionHandler(PacketTunnelError.invalidConfiguration)
            return
        }

        TunnelLog.write("TunnelConfig built successfully")
        TunnelLog.write("  interface addresses: \(tunnelConfig.interface.addresses.map { $0.stringRepresentation })")
        TunnelLog.write("  interface dns: \(tunnelConfig.interface.dns.map { $0.stringRepresentation })")
        TunnelLog.write("  peers: \(tunnelConfig.peers.count)")
        if let peer = tunnelConfig.peers.first {
            TunnelLog.write("  peer endpoint: \(peer.endpoint?.stringRepresentation ?? "nil")")
            TunnelLog.write("  peer allowedIPs: \(peer.allowedIPs.map { $0.stringRepresentation })")
        }

        let networkSettings = makeNetworkSettings(from: tunnelConfig)
        TunnelLog.write("Network settings built, applying...")
        TunnelLog.write("  tunnelRemoteAddress: \(networkSettings.tunnelRemoteAddress)")
        TunnelLog.write("  dns: \(networkSettings.dnsSettings?.servers ?? [])")
        TunnelLog.write("  dns matchDomains: \(networkSettings.dnsSettings?.matchDomains ?? [])")
        TunnelLog.write("  mtu: \(networkSettings.mtu ?? 0)")
        TunnelLog.write("  ipv4 addresses: \(networkSettings.ipv4Settings?.addresses ?? [])")
        TunnelLog.write("  ipv4 routes: \(networkSettings.ipv4Settings?.includedRoutes?.count ?? 0)")
        TunnelLog.write("  ipv6 addresses: \(networkSettings.ipv6Settings?.addresses ?? [])")
        TunnelLog.write("  ipv6 routes: \(networkSettings.ipv6Settings?.includedRoutes?.count ?? 0)")

        // Apply network settings to create the utun interface, then start WireGuard
        setTunnelNetworkSettings(networkSettings) { [weak self] settingsError in
            if let settingsError {
                TunnelLog.write("ERROR: setTunnelNetworkSettings failed: \(settingsError)")
                completionHandler(settingsError)
                return
            }

            TunnelLog.write("Network settings applied successfully, starting WireGuard adapter...")

            self?.adapter.start(tunnelConfiguration: tunnelConfig) { adapterError in
                if let error = adapterError {
                    TunnelLog.write("ERROR: WireGuard adapter start failed: \(error)")
                    completionHandler(error)
                    return
                }

                TunnelLog.write("WireGuard adapter started successfully")
                TunnelLog.write("  interfaceName: \(self?.adapter.interfaceName ?? "nil")")
                completionHandler(nil)

                // Log runtime config at intervals to check handshake progress
                for delay in [2, 5, 10] {
                    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay)) {
                        self?.adapter.getRuntimeConfiguration { config in
                            guard let config else {
                                TunnelLog.write("WARNING: No runtime config at \(delay)s")
                                return
                            }
                            // Extract key fields
                            let lines = config.components(separatedBy: "\n")
                            let tx = lines.first(where: { $0.hasPrefix("tx_bytes=") }) ?? "tx_bytes=?"
                            let rx = lines.first(where: { $0.hasPrefix("rx_bytes=") }) ?? "rx_bytes=?"
                            let hs = lines.first(where: {
                                $0.hasPrefix("last_handshake_time_sec=")
                            }) ?? "last_handshake=?"
                            let ep = lines.first(where: { $0.hasPrefix("endpoint=") }) ?? "endpoint=?"
                            TunnelLog.write("Status at \(delay)s: \(tx) \(rx) \(hs) \(ep)")
                        }
                    }
                }
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
        completionHandler?(Data("ok".utf8))
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

    /// Build NEPacketTunnelNetworkSettings from the WireGuard tunnel configuration.
    private func makeNetworkSettings(from config: TunnelConfiguration) -> NEPacketTunnelNetworkSettings {
        // Use the actual peer endpoint IP as tunnelRemoteAddress so the system
        // knows to route WireGuard's own traffic via the physical interface.
        let serverAddress: String = {
            guard let endpoint = config.peers.first?.endpoint else { return "127.0.0.1" }
            switch endpoint.host {
                case .ipv4(let address): return "\(address)"
                case .ipv6(let address): return "\(address)"
                case .name(let hostname, _): return hostname
                @unknown default: return "127.0.0.1"
            }
        }()
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: serverAddress)

        // DNS — matchDomains = [""] forces ALL DNS queries through the tunnel
        if !config.interface.dns.isEmpty {
            let dnsSettings = NEDNSSettings(servers: config.interface.dns.map { $0.stringRepresentation })
            dnsSettings.matchDomains = [""]
            settings.dnsSettings = dnsSettings
        }

        // MTU
        settings.mtu = NSNumber(value: config.interface.mtu ?? 1280)

        // IPv4
        var ipv4Routes = [NEIPv4Route]()
        var ipv4IncludedRoutes = [NEIPv4Route]()
        ipv4IncludedRoutes.append(NEIPv4Route.default())

        for addressRange in config.interface.addresses where addressRange.address is IPv4Address {
            ipv4Routes.append(NEIPv4Route(
                destinationAddress: "\(addressRange.address)",
                subnetMask: "\(addressRange.subnetMask())"
            ))
            let route = NEIPv4Route(
                destinationAddress: "\(addressRange.maskedAddress())",
                subnetMask: "\(addressRange.subnetMask())"
            )
            route.gatewayAddress = "\(addressRange.address)"
            ipv4IncludedRoutes.append(route)
        }

        for peer in config.peers {
            for addressRange in peer.allowedIPs where addressRange.address is IPv4Address {
                ipv4IncludedRoutes.append(NEIPv4Route(
                    destinationAddress: "\(addressRange.address)",
                    subnetMask: "\(addressRange.subnetMask())"
                ))
            }
        }

        let ipv4Settings = NEIPv4Settings(
            addresses: ipv4Routes.map { $0.destinationAddress },
            subnetMasks: ipv4Routes.map { $0.destinationSubnetMask }
        )
        ipv4Settings.includedRoutes = ipv4IncludedRoutes

        // Exclude the WireGuard server endpoint from tunnel routing
        // to prevent a routing loop (tunnel traffic must reach server via physical interface)
        var ipv4ExcludedRoutes = [NEIPv4Route]()
        for peer in config.peers {
            if let endpoint = peer.endpoint, case .ipv4(let address) = endpoint.host {
                ipv4ExcludedRoutes.append(NEIPv4Route(
                    destinationAddress: "\(address)",
                    subnetMask: "255.255.255.255"
                ))
            }
        }
        if !ipv4ExcludedRoutes.isEmpty {
            ipv4Settings.excludedRoutes = ipv4ExcludedRoutes
        }

        settings.ipv4Settings = ipv4Settings

        // IPv6
        var ipv6Routes = [NEIPv6Route]()
        var ipv6IncludedRoutes = [NEIPv6Route]()
        ipv6IncludedRoutes.append(NEIPv6Route.default())

        for addressRange in config.interface.addresses where addressRange.address is IPv6Address {
            ipv6Routes.append(NEIPv6Route(
                destinationAddress: "\(addressRange.address)",
                networkPrefixLength: NSNumber(value: min(120, addressRange.networkPrefixLength))
            ))
            let route = NEIPv6Route(
                destinationAddress: "\(addressRange.maskedAddress())",
                networkPrefixLength: NSNumber(value: addressRange.networkPrefixLength)
            )
            route.gatewayAddress = "\(addressRange.address)"
            ipv6IncludedRoutes.append(route)
        }

        for peer in config.peers {
            for addressRange in peer.allowedIPs where addressRange.address is IPv6Address {
                ipv6IncludedRoutes.append(NEIPv6Route(
                    destinationAddress: "\(addressRange.address)",
                    networkPrefixLength: NSNumber(value: addressRange.networkPrefixLength)
                ))
            }
        }

        let ipv6Settings = NEIPv6Settings(
            addresses: ipv6Routes.map { $0.destinationAddress },
            networkPrefixLengths: ipv6Routes.map { $0.destinationNetworkPrefixLength }
        )
        ipv6Settings.includedRoutes = ipv6IncludedRoutes
        settings.ipv6Settings = ipv6Settings

        return settings
    }
}

// MARK: - Error Types

enum PacketTunnelError: LocalizedError {
    case missingConfiguration
    case invalidConfiguration

    var errorDescription: String? {
        switch self {
            case .missingConfiguration:
                return String(localized: "No WireGuard configuration found in tunnel provider settings.")
            case .invalidConfiguration:
                return String(localized: "The WireGuard configuration could not be parsed.")
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
