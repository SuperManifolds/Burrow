import Foundation

/// Manages the gotatun-cli process lifecycle and implements the XPC protocol.
final class TunnelService: NSObject, BurrowDaemonXPC {

    static let shared = TunnelService()

    private var tunnelProcess: Process?
    private var interfaceName: String?
    private var status: DaemonStatus = .disconnected
    private var savedDNS: String?
    private var savedGateway: String?
    private var savedService: String?
    private var peerEndpointIP: String?
    private var statsTimer: Timer?
    var statsDirectory: URL?

    private static let tunInterfaceBase = 100
    private static let maxInterfaceProbe = 10
    private static let socketTimeout: TimeInterval = 5
    private static let handshakeTimeout: TimeInterval = 10
    private static let pollInterval: TimeInterval = 0.1
    private static let handshakePollInterval: TimeInterval = 0.5
    private static let statsInterval: TimeInterval = 2
    private static let socketRetryInterval: TimeInterval = 0.2
    private static let uapiReadBufferSize = 4096


    private override init() {
        super.init()
        restoreNetworkIfNeeded()
    }

    // MARK: - BurrowDaemonXPC

    func connect(
        privateKey: String,
        addresses: String,
        peerPublicKey: String,
        peerEndpoint: String,
        dns: String,
        mtu: Int,
        reply: @escaping (NSError?) -> Void
    ) {
        guard !privateKey.isEmpty,
              !peerPublicKey.isEmpty,
              peerEndpoint.contains(":"),
              !addresses.isEmpty else {
            reply(makeError(code: 1, message: "Invalid tunnel configuration"))
            return
        }

        let newEndpointIP = peerEndpoint.components(separatedBy: ":").first

        // Fast path: reconfigure peer on existing tunnel
        if tunnelProcess?.isRunning == true,
           let iface = interfaceName,
           savedGateway != nil {
            status = .connecting
            do {
                try configureWireGuard(
                    interface: iface,
                    privateKey: privateKey,
                    peerPublicKey: peerPublicKey,
                    peerEndpoint: peerEndpoint
                )

                if peerEndpointIP != newEndpointIP {
                    if let oldEP = peerEndpointIP {
                        Route.deleteHost(oldEP)
                    }
                    if let gw = savedGateway, let newEP = newEndpointIP {
                        Route.addHost(newEP, gateway: gw)
                    }
                    peerEndpointIP = newEndpointIP
                }

                try waitForHandshake(interface: iface)

                status = .connected
                log("Switched peer to \(peerEndpoint)")
                reply(nil)
            } catch {
                log("Peer switch failed: \(error.localizedDescription)")
                forceCleanup()
                reply(error as NSError)
            }
            return
        }

        // Full connect
        if tunnelProcess != nil {
            forceCleanup()
        }

        status = .connecting

        guard let gotatunPath = findGotatunBinary() else {
            status = .disconnected
            reply(makeError(code: 2, message: "gotatun binary not found"))
            return
        }

        let iface = availableInterface()

        // Save network state BEFORE changes
        savedGateway = Route.defaultGateway()
        let service = NetworkSetup.activeService()
        savedService = service
        savedDNS = NetworkSetup.getDNS(service: service)
        peerEndpointIP = newEndpointIP

        // Clean stale socket
        try? FileManager.default.removeItem(
            atPath: "/var/run/wireguard/\(iface).sock"
        )

        do {
            let process = try startGotatun(path: gotatunPath, interface: iface)
            tunnelProcess = process
            interfaceName = iface

            try configureWireGuard(
                interface: iface,
                privateKey: privateKey,
                peerPublicKey: peerPublicKey,
                peerEndpoint: peerEndpoint
            )

            try configureNetwork(
                interface: iface,
                addresses: addresses,
                dns: dns,
                mtu: mtu
            )

            try waitForHandshake(interface: iface)

            startStatsPolling(interface: iface)

            status = .connected
            log("Connected on \(iface)")
            reply(nil)
        } catch {
            log("Connect failed: \(error.localizedDescription)")
            forceCleanup()
            reply(error as NSError)
        }
    }

    func disconnect(reply: @escaping () -> Void) {
        forceCleanup()
        log("Disconnected")
        reply()
    }

    func getStatus(reply: @escaping (String) -> Void) {
        if status == .connected, tunnelProcess?.isRunning != true {
            forceCleanup()
        }
        reply(status.rawValue)
    }

    func restart(reply: @escaping () -> Void) {
        log("Restart requested")
        forceCleanup()
        reply()
        // Exit after replying — launchd will restart us with the new binary
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            exit(0)
        }
    }

    // MARK: - Cleanup

    private func forceCleanup() {
        status = .disconnecting
        stopStatsPolling()
        restoreNetwork()

        if let process = tunnelProcess, process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }
        tunnelProcess = nil

        if let iface = interfaceName {
            try? FileManager.default.removeItem(
                atPath: "/var/run/wireguard/\(iface).sock"
            )
        }
        interfaceName = nil
        status = .disconnected
    }

    // MARK: - Transfer Stats

    private func startStatsPolling(interface: String) {
        stopStatsPolling()
        let socketPath = "/var/run/wireguard/\(interface).sock"
        let timer = Timer(timeInterval: Self.statsInterval, repeats: true) { [weak self] _ in
            self?.pollAndWriteStats(socketPath: socketPath)
        }
        RunLoop.main.add(timer, forMode: .default)
        statsTimer = timer
    }

    private func stopStatsPolling() {
        statsTimer?.invalidate()
        statsTimer = nil
    }

    private func pollAndWriteStats(socketPath: String) {
        guard let response = try? sendUAPI(socketPath: socketPath, command: "get=1") else { return }

        var tx: UInt64 = 0
        var rx: UInt64 = 0
        for line in response.components(separatedBy: "\n") {
            if line.hasPrefix("tx_bytes=") {
                tx = UInt64(line.dropFirst("tx_bytes=".count)) ?? 0
            } else if line.hasPrefix("rx_bytes=") {
                rx = UInt64(line.dropFirst("rx_bytes=".count)) ?? 0
            }
        }

        guard let dir = statsDirectory else { return }
        let url = dir.appendingPathComponent(TunnelIO.statsFilename)
        let json = "{\"tx\":\(tx),\"rx\":\(rx)}"
        try? json.data(using: .utf8)?.write(to: url)
    }

    private func restoreNetworkIfNeeded() {
        let wgDir = "/var/run/wireguard"
        let sockets = (try? FileManager.default.contentsOfDirectory(atPath: wgDir)) ?? []
        let stale = sockets.filter { $0.hasPrefix("utun") && $0.hasSuffix(".sock") }
        guard !stale.isEmpty else { return }

        log("Cleaning up stale tunnel state from previous instance")

        // Remove routes FIRST so activeService detects the real interface
        for sock in stale {
            let iface = String(sock.dropLast(5))
            Route.deleteNet("0.0.0.0/1", interface: iface)
            Route.deleteNet("128.0.0.0/1", interface: iface)
            try? FileManager.default.removeItem(atPath: "\(wgDir)/\(sock)")
        }

        NetworkSetup.setDNS(service: NetworkSetup.activeService(), server: "empty")
        ProcessControl.kill(name: "gotatun")
    }

    // MARK: - Start gotatun

    private func startGotatun(path: URL, interface: String) throws -> Process {
        let process = Process()
        process.executableURL = path
        process.arguments = ["-f", "--disable-drop-privileges", interface]
        process.terminationHandler = { proc in
            Self.shared.log("gotatun exited with code \(proc.terminationStatus)")
            CFRunLoopPerformBlock(CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue) {
                guard Self.shared.tunnelProcess?.processIdentifier == proc.processIdentifier,
                      Self.shared.status == .connected else { return }
                Self.shared.forceCleanup()
            }
            CFRunLoopWakeUp(CFRunLoopGetMain())
        }
        try process.run()

        let socketPath = "/var/run/wireguard/\(interface).sock"
        let deadline = Date().addingTimeInterval(Self.socketTimeout)
        while !FileManager.default.fileExists(atPath: socketPath), Date() < deadline {
            guard process.isRunning else {
                throw makeError(code: 3, message: "gotatun exited unexpectedly")
            }
            Thread.sleep(forTimeInterval: Self.pollInterval)
        }

        guard FileManager.default.fileExists(atPath: socketPath) else {
            process.terminate()
            throw makeError(code: 3, message: "gotatun failed to start")
        }

        return process
    }

    // MARK: - WireGuard UAPI

    private func configureWireGuard(
        interface: String,
        privateKey: String,
        peerPublicKey: String,
        peerEndpoint: String
    ) throws {
        guard let privateKeyHex = base64ToHex(privateKey),
              let peerPublicKeyHex = base64ToHex(peerPublicKey) else {
            throw makeError(code: 5, message: "Invalid WireGuard key encoding")
        }

        let command = [
            "set=1",
            "private_key=\(privateKeyHex)",
            "listen_port=0",
            "replace_peers=true",
            "public_key=\(peerPublicKeyHex)",
            "endpoint=\(peerEndpoint)",
            "allowed_ip=0.0.0.0/0",
            "allowed_ip=::/0",
        ].joined(separator: "\n")

        let socketPath = "/var/run/wireguard/\(interface).sock"
        let response = try sendUAPI(socketPath: socketPath, command: command)

        if let errLine = response.components(separatedBy: "\n")
            .last(where: { $0.hasPrefix("errno=") }),
           errLine != "errno=0" {
            throw makeError(code: 9, message: "WireGuard configuration rejected by gotatun")
        }
    }

    private func waitForHandshake(interface: String) throws {
        let timeout = Self.handshakeTimeout
        let socketPath = "/var/run/wireguard/\(interface).sock"
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            let response: String
            do {
                response = try sendUAPI(socketPath: socketPath, command: "get=1")
            } catch {
                log("Handshake check failed: \(error.localizedDescription)")
                Thread.sleep(forTimeInterval: Self.handshakePollInterval)
                continue
            }

            for line in response.components(separatedBy: "\n") {
                if line.hasPrefix("last_handshake_time_sec=") {
                    let value = line.replacingOccurrences(
                        of: "last_handshake_time_sec=", with: ""
                    )
                    if let sec = Int(value), sec > 0 {
                        log("Handshake confirmed")
                        return
                    }
                }
            }
            Thread.sleep(forTimeInterval: Self.handshakePollInterval)
        }

        throw makeError(
            code: 10,
            message: "WireGuard handshake did not complete — the server may be unreachable"
        )
    }

    private func sendUAPI(socketPath: String, command: String) throws -> String {
        let fd = try connectToUAPISocket(path: socketPath)
        defer { close(fd) }

        var tv = timeval(tv_sec: Int(Self.socketTimeout), tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var cmd = command
        if !cmd.hasSuffix("\n\n") {
            if !cmd.hasSuffix("\n") { cmd += "\n" }
            cmd += "\n"
        }
        guard let data = cmd.data(using: .utf8) else {
            throw makeError(code: 8, message: "Failed to encode UAPI command")
        }
        let written = data.withUnsafeBytes { buf -> Int in
            guard let ptr = buf.baseAddress else { return 0 }
            return write(fd, ptr, buf.count)
        }
        guard written == data.count else {
            throw makeError(code: 8, message: "Failed to send WireGuard configuration")
        }

        var response = Data()
        var buf = [UInt8](repeating: 0, count: Self.uapiReadBufferSize)
        while true {
            let n = read(fd, &buf, buf.count)
            if n <= 0 { break }
            response.append(contentsOf: buf[..<n])
            if response.count >= 2,
               response[response.count - 1] == 0x0A,
               response[response.count - 2] == 0x0A {
                break
            }
        }
        return String(data: response, encoding: .utf8) ?? ""
    }

    // MARK: - Network Configuration

    private func configureNetwork(
        interface: String, addresses: String, dns: String, mtu: Int
    ) throws {
        let addrParts = addresses.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        let ipv4 = addrParts.first?.components(separatedBy: "/").first
        let ipv6 = addrParts.dropFirst().first?.components(separatedBy: "/").first

        guard let ipv4 else {
            throw makeError(code: 11, message: "No IPv4 address in tunnel configuration")
        }

        InterfaceConfig.setMTU(interface, mtu: mtu)
        let rc = InterfaceConfig.setIPv4(interface, address: ipv4)
        if rc != 0 {
            throw makeError(code: 12, message: "Failed to configure tunnel interface")
        }
        if let ipv6 {
            InterfaceConfig.setIPv6(interface, address: ipv6)
        }

        guard let gw = savedGateway else {
            throw makeError(code: 13, message: "Could not detect default gateway")
        }
        if let ep = peerEndpointIP {
            Route.addHost(ep, gateway: gw)
        }

        let r1 = Route.addNet("0.0.0.0/1", interface: interface)
        let r2 = Route.addNet("128.0.0.0/1", interface: interface)
        if r1 != 0 || r2 != 0 {
            throw makeError(code: 14, message: "Failed to add tunnel routes")
        }

        let service = savedService ?? NetworkSetup.activeService()
        NetworkSetup.setDNS(service: service, server: dns)
    }

    private func restoreNetwork() {
        if let iface = interfaceName {
            Route.deleteNet("0.0.0.0/1", interface: iface)
            Route.deleteNet("128.0.0.0/1", interface: iface)
        }
        if let ep = peerEndpointIP {
            Route.deleteHost(ep)
        }

        let service = savedService ?? NetworkSetup.activeService()
        NetworkSetup.setDNS(service: service, server: savedDNS ?? "empty")

        peerEndpointIP = nil
        savedGateway = nil
        savedDNS = nil
        savedService = nil
    }

    // MARK: - Binary Location

    private func findGotatunBinary() -> URL? {
        var pathBuf = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        var size = UInt32(MAXPATHLEN)
        guard _NSGetExecutablePath(&pathBuf, &size) == 0 else { return nil }

        var url = URL(fileURLWithPath: String(cString: pathBuf)).standardized
        while url.pathComponents.count > 1 {
            url = url.deletingLastPathComponent()
            if url.lastPathComponent.hasSuffix(".app") {
                let gotatun = url.appendingPathComponent("Contents/Resources/gotatun")
                if FileManager.default.isExecutableFile(atPath: gotatun.path) {
                    return gotatun
                }
            }
        }

        for path in ["/usr/local/bin/gotatun", "/opt/homebrew/bin/gotatun"] {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    // MARK: - Helpers

    private func availableInterface() -> String {
        for i in Self.tunInterfaceBase..<(Self.tunInterfaceBase + Self.maxInterfaceProbe) {
            let name = "utun\(i)"
            if !FileManager.default.fileExists(atPath: "/var/run/wireguard/\(name).sock") {
                return name
            }
        }
        return "utun\(Self.tunInterfaceBase)"
    }

    private func connectToUAPISocket(path: String) throws -> Int32 {
        let deadline = Date().addingTimeInterval(Self.socketTimeout)
        while Date() < deadline {
            let fd = socket(AF_UNIX, SOCK_STREAM, 0)
            guard fd >= 0 else {
                throw makeError(code: 6, message: "Failed to create socket")
            }

            var addr = sockaddr_un()
            addr.sun_family = sa_family_t(AF_UNIX)
            let pathLen = min(path.utf8.count, MemoryLayout.size(ofValue: addr.sun_path) - 1)
            path.withCString { cstr in
                withUnsafeMutableBytes(of: &addr.sun_path) { buf in
                    guard let base = buf.baseAddress else { return }
                    memcpy(base, cstr, pathLen)
                }
            }
            let result = withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                    Darwin.connect(fd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
            if result == 0 { return fd }
            close(fd)
            Thread.sleep(forTimeInterval: Self.socketRetryInterval)
        }
        throw makeError(code: 7, message: "gotatun not responding")
    }

    private func base64ToHex(_ base64: String) -> String? {
        guard let data = Data(base64Encoded: base64) else { return nil }
        return data.map { String(format: "%02x", $0) }.joined()
    }

    private func log(_ message: String) {
        Log.daemon.info("\(message)")
    }

    private func makeError(code: Int, message: String) -> NSError {
        NSError(domain: "BurrowDaemon", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
