import Combine
import Foundation

/// TunnelManaging implementation that routes connect/disconnect through XPC
/// to the BurrowDaemon, which runs gotatun-cli with direct utun access.
@MainActor
final class GotaTunDaemonManager: ObservableObject, TunnelManaging {

    // MARK: - Published State

    @Published private(set) var status: ConnectionStatus = .disconnected
    @Published private(set) var connectedRelay: Relay?
    @Published private(set) var connectedDate: Date?

    var statusPublisher: Published<ConnectionStatus>.Publisher { $status }
    var connectedRelayPublisher: Published<Relay?>.Publisher { $connectedRelay }

    // MARK: - Properties

    private let machService = AppIdentifiers.daemonBundleID
    private var connection: NSXPCConnection?
    private var statusPollTask: Task<Void, Never>?

    private static let statusPollInterval: Duration = .seconds(5)
    private static let xpcTimeoutSeconds: Double = 3

    // MARK: - Public API

    func connect(
        to relay: Relay,
        with device: Device,
        privateKey: Data,
        port: Int = TunnelDefaults.port,
        dns: String = TunnelDefaults.dns,
        mtu: Int = TunnelDefaults.mtu
    ) async throws {
        status = .connecting
        connectedRelay = relay

        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                let once = OnceResume(cont)
                guard let proxy = xpcProxy(errorHandler: { once.fail($0) }) else {
                    once.fail(DaemonError.daemonNotRunning)
                    return
                }
                proxy.connect(
                    privateKey: privateKey.base64EncodedString(),
                    addresses: "\(device.ipv4Address), \(device.ipv6Address)",
                    peerPublicKey: relay.publicKey,
                    peerEndpoint: "\(relay.ipv4AddrIn):\(port)",
                    dns: dns,
                    mtu: mtu
                ) { error in
                    if let error {
                        once.fail(error)
                    } else {
                        once.succeed()
                    }
                }
            }

            let now = Date()
            connectedDate = now
            status = .connected(since: now)
            startStatusPolling()
        } catch {
            resetState()
            throw DaemonError.connectionFailed(error.localizedDescription)
        }
    }

    func disconnect() async {
        status = .disconnecting
        stopStatusPolling()

        if let proxy = xpcProxy(errorHandler: { _ in }) {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                let once = OnceVoidResume(cont)
                proxy.disconnect {
                    once.resume()
                }
                // If XPC drops, the invalidation handler fires and
                // the reply never comes. Time out after 3 seconds.
                DispatchQueue.global().asyncAfter(deadline: .now() + Self.xpcTimeoutSeconds) {
                    once.resume()
                }
            }
        }

        resetState()
    }

    nonisolated func readTunnelLog() -> String? { TunnelIO.readLog() }

    nonisolated func readTransferStats() -> (tx: UInt64, rx: UInt64)? { TunnelIO.readStats() }

    // MARK: - Status Polling

    /// Polls the daemon to detect if gotatun crashed while we think we're connected.
    private func startStatusPolling() {
        stopStatusPolling()
        statusPollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.statusPollInterval)
                guard let self, self.status.isActive else { break }
                await self.checkDaemonStatus()
            }
        }
    }

    private func stopStatusPolling() {
        statusPollTask?.cancel()
        statusPollTask = nil
    }

    private func checkDaemonStatus() async {
        guard let proxy = xpcProxy(errorHandler: { _ in }) else {
            handleDaemonLost()
            return
        }

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            let once = OnceVoidResume(cont)
            proxy.getStatus { [weak self] daemonStatus in
                Task { @MainActor in
                    if daemonStatus != DaemonStatus.connected.rawValue {
                        self?.handleDaemonLost()
                    }
                    once.resume()
                }
            }
            // Timeout in case XPC drops
            DispatchQueue.global().asyncAfter(deadline: .now() + Self.xpcTimeoutSeconds) {
                once.resume()
            }
        }
    }

    private func handleDaemonLost() {
        guard status.isActive else { return }
        stopStatusPolling()
        resetState()
    }

    // MARK: - XPC Connection

    private func xpcProxy(errorHandler: @escaping (Error) -> Void) -> BurrowDaemonXPC? {
        let conn = connection ?? createConnection()
        return conn.remoteObjectProxyWithErrorHandler(errorHandler) as? BurrowDaemonXPC
    }

    private func createConnection() -> NSXPCConnection {
        let conn = NSXPCConnection(machServiceName: machService, options: .privileged)
        conn.remoteObjectInterface = NSXPCInterface(with: BurrowDaemonXPC.self)
        conn.invalidationHandler = { [weak self] in
            Task { @MainActor in
                self?.connection = nil
                self?.handleDaemonLost()
            }
        }
        conn.resume()
        connection = conn
        return conn
    }

    // MARK: - Private

    private func resetState() {
        status = .disconnected
        connectedRelay = nil
        connectedDate = nil
    }

    // MARK: - Continuation Safety

    /// Ensures a throwing continuation is resumed exactly once.
    private final class OnceResume: @unchecked Sendable {
        private var continuation: CheckedContinuation<Void, Error>?
        private let lock = NSLock()

        init(_ cont: CheckedContinuation<Void, Error>) { continuation = cont }

        func succeed() {
            lock.lock()
            let cont = continuation
            continuation = nil
            lock.unlock()
            cont?.resume()
        }

        func fail(_ error: Error) {
            lock.lock()
            let cont = continuation
            continuation = nil
            lock.unlock()
            cont?.resume(throwing: error)
        }
    }

    /// Ensures a non-throwing continuation is resumed exactly once.
    private final class OnceVoidResume: @unchecked Sendable {
        private var continuation: CheckedContinuation<Void, Never>?
        private let lock = NSLock()

        init(_ cont: CheckedContinuation<Void, Never>) { continuation = cont }

        func resume() {
            lock.lock()
            let cont = continuation
            continuation = nil
            lock.unlock()
            cont?.resume()
        }
    }

    // MARK: - Errors

    enum DaemonError: LocalizedError {
        case daemonNotRunning
        case connectionFailed(String)

        var errorDescription: String? {
            switch self {
                case .daemonNotRunning:
                    return String(localized: """
                        Performance mode daemon is not running. \
                        Try toggling Performance mode in Settings.
                        """)
                case .connectionFailed(let detail):
                    return String(localized: "VPN connection failed: \(detail)")
            }
        }
    }
}
