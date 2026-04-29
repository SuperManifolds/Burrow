import Combine
import Foundation
import Network
import OSLog

/// Manages VPN connection state and coordinates between tunnel manager and UI.
@MainActor
final class ConnectionViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var status: ConnectionStatus = .disconnected
    @Published private(set) var connectedRelay: Relay?
    @Published private(set) var connectionDuration: TimeInterval = 0
    @Published private(set) var error: String?
    @Published private(set) var transferTx: UInt64 = 0
    @Published private(set) var transferRx: UInt64 = 0
    @Published private(set) var isConnectivityVerified: Bool = false

    // MARK: - Dependencies

    private let tunnelManager: any TunnelManaging
    private let accountViewModel: AccountViewModel
    var settingsViewModel: SettingsViewModel?
    var notificationService: NotificationService?
    var relayLocationResolver: ((String) -> (location: String, city: String)?)?
    private var durationTask: Task<Void, Never>?
    private var disconnectIsUserInitiated = false
    private var previousStatus: ConnectionStatus = .disconnected

    // MARK: - Initialization

    init(tunnelManager: any TunnelManaging, accountViewModel: AccountViewModel) {
        self.tunnelManager = tunnelManager
        self.accountViewModel = accountViewModel

        // Observe tunnel manager status changes
        tunnelManager.statusPublisher
            .receive(on: RunLoop.main)
            .assign(to: &$status)

        tunnelManager.connectedRelayPublisher
            .receive(on: RunLoop.main)
            .assign(to: &$connectedRelay)

        $status
            .receive(on: RunLoop.main)
            .sink { [weak self] newStatus in
                self?.handleStatusTransition(to: newStatus)
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Public API

    /// Connect to a specific relay.
    func connect(to relay: Relay) async {
        error = nil
        disconnectIsUserInitiated = false

        guard let device = accountViewModel.device else {
            error = String(localized: "No device registered. Try logging out and back in.")
            Log.connection.error("Connect failed: no device")
            return
        }

        guard let privateKey = accountViewModel.privateKey() else {
            error = String(localized: "Missing private key. Try logging out and back in.")
            Log.connection.error("Connect failed: no private key")
            return
        }

        do {
            let port = settingsViewModel?.effectivePort ?? TunnelDefaults.port
            let dns = settingsViewModel?.effectiveDNS ?? TunnelDefaults.dns
            let mtu = settingsViewModel?.effectiveMTU ?? TunnelDefaults.mtu
            Log.connection.info("Connecting to \(relay.hostname) (\(relay.ipv4AddrIn):\(port), MTU:\(mtu))")
            try await tunnelManager.connect(
                to: relay, with: device, privateKey: privateKey,
                port: port, dns: dns, mtu: mtu
            )
            startDurationTimer()
            verifyConnectivity()
        } catch {
            self.error = error.localizedDescription
            Log.connection.error("Connect error: \(error)")
            if settingsViewModel?.showConnectionNotifications ?? true {
                notificationService?.postConnectionFailed(error: error.localizedDescription)
            }
        }
    }

    /// Disconnect from the current relay.
    func disconnect() async {
        disconnectIsUserInitiated = true
        stopVerification()
        await tunnelManager.disconnect()
        stopDurationTimer()
        connectionDuration = 0
        transferTx = 0
        transferRx = 0
    }

    /// Read the diagnostic log from the tunnel extension.
    func readTunnelLog() -> String? {
        tunnelManager.readTunnelLog()
    }

    /// Toggle connection state for the given relay.
    func toggle(relay: Relay) async {
        if status.isActive {
            await disconnect()
        } else {
            await connect(to: relay)
        }
    }

    // MARK: - Connectivity Verification

    private static let connectivityMaxAttempts = 3
    private static let connectivityRetryInterval: Duration = .seconds(2)
    private static let connectivityProbeTimeout: Double = 3

    private var verificationTask: Task<Void, Never>?

    private func verifyConnectivity() {
        verificationTask?.cancel()
        isConnectivityVerified = false

        verificationTask = Task {
            for attempt in 1...Self.connectivityMaxAttempts {
                guard !Task.isCancelled, status.isActive else { return }

                if await probeConnectivity() {
                    guard !Task.isCancelled else { return }
                    isConnectivityVerified = true
                    return
                }

                if attempt < Self.connectivityMaxAttempts {
                    try? await Task.sleep(for: Self.connectivityRetryInterval)
                }
            }

            // All attempts failed
            guard !Task.isCancelled, status.isActive else { return }
            error = String(localized: "Connected but internet is not reachable")
        }
    }

    private func stopVerification() {
        verificationTask?.cancel()
        verificationTask = nil
        isConnectivityVerified = false
    }

    private func probeConnectivity() async -> Bool {
        let dns = settingsViewModel?.effectiveDNS ?? TunnelDefaults.dns
        return await withCheckedContinuation { cont in
            let host = NWEndpoint.Host(dns)
            guard let port = NWEndpoint.Port(rawValue: 53) else {
                cont.resume(returning: false)
                return
            }

            let lock = NSLock()
            var resumed = false
            let finish = { (result: Bool) in
                lock.lock()
                let shouldResume = !resumed
                resumed = true
                lock.unlock()
                if shouldResume {
                    cont.resume(returning: result)
                }
            }

            let connection = NWConnection(host: host, port: port, using: .tcp)

            let timeout = DispatchWorkItem { [weak connection] in
                connection?.cancel()
                finish(false)
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + Self.connectivityProbeTimeout, execute: timeout)

            connection.stateUpdateHandler = { state in
                switch state {
                    case .ready:
                        timeout.cancel()
                        connection.cancel()
                        finish(true)
                    case .failed, .cancelled:
                        timeout.cancel()
                        finish(false)
                    default:
                        break
                }
            }
            connection.start(queue: .global())
        }
    }

    // MARK: - Status Transitions

    private func handleStatusTransition(to newStatus: ConnectionStatus) {
        defer { previousStatus = newStatus }

        guard settingsViewModel?.showConnectionNotifications ?? true else { return }
        guard let notificationService else { return }

        switch (previousStatus, newStatus) {
            case (.connecting, .connected):
                let location = connectedRelay.flatMap { relayLocationResolver?($0.hostname) }
                notificationService.postConnected(
                    location: location?.location,
                    hostname: connectedRelay?.hostname
                )
            case (.disconnecting, .disconnected), (.connected, .disconnected), (.connecting, .disconnected):
                notificationService.postDisconnected(userInitiated: disconnectIsUserInitiated)
                disconnectIsUserInitiated = false
            default:
                break
        }
    }

    // MARK: - Duration Timer

    private func startDurationTimer() {
        stopDurationTimer()
        let startDate = Date()
        let manager = tunnelManager
        durationTask = Task.detached { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard self != nil else { break }
                let duration = Date().timeIntervalSince(startDate)
                let stats = manager.readTransferStats()
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.connectionDuration = duration
                    if let stats {
                        self.transferTx = stats.tx
                        self.transferRx = stats.rx
                    }
                }
            }
        }
    }

    private func stopDurationTimer() {
        durationTask?.cancel()
        durationTask = nil
    }
}

// MARK: - Display

extension ConnectionViewModel {
    /// Status text accounting for connectivity verification.
    var statusDisplayText: String {
        switch status {
            case .connected:
                if isConnectivityVerified {
                    return String(localized: "Connected")
                }
                return String(localized: "Verifying...")
            default:
                return status.displayText
        }
    }

    /// Formatted duration string (e.g. "01:23:45").
    var formattedDuration: String {
        let hours = Int(connectionDuration) / 3600
        let minutes = (Int(connectionDuration) % 3600) / 60
        let seconds = Int(connectionDuration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    /// Format bytes to human-readable string (e.g. "1.12 GB", "340 MB").
    static func formattedBytes(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB, .useTB]
        return formatter.string(fromByteCount: Int64(bytes))
    }

    #if DEBUG
    /// Seed transfer stats for SwiftUI previews.
    func setPreviewTransferStats(tx: UInt64, rx: UInt64) {
        transferTx = tx
        transferRx = rx
    }
    #endif
}
