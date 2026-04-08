import Combine
import Foundation

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

    // MARK: - Dependencies

    private let tunnelManager: any TunnelManaging
    private let accountViewModel: AccountViewModel
    var settingsViewModel: SettingsViewModel?
    private var durationTask: Task<Void, Never>?

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
    }

    // MARK: - Public API

    /// Connect to a specific relay.
    func connect(to relay: Relay) async {
        error = nil

        guard let device = accountViewModel.device else {
            error = String(localized: "No device registered. Try logging out and back in.")
            print("[Burrow] Connect failed: no device")
            return
        }

        guard let privateKey = accountViewModel.privateKey() else {
            error = String(localized: "Missing private key. Try logging out and back in.")
            print("[Burrow] Connect failed: no private key")
            return
        }

        do {
            let port = settingsViewModel?.effectivePort ?? 51820
            let dns = settingsViewModel?.effectiveDNS ?? "10.64.0.1"
            let mtu = settingsViewModel?.effectiveMTU ?? 1280
            print("[Burrow] Connecting to \(relay.hostname) (\(relay.ipv4AddrIn):\(port), MTU:\(mtu))")
            try await tunnelManager.connect(to: relay, with: device, privateKey: privateKey, port: port, dns: dns, mtu: mtu)
            startDurationTimer()
        } catch {
            self.error = error.localizedDescription
            print("[Burrow] Connect error: \(error)")
        }
    }

    /// Disconnect from the current relay.
    func disconnect() async {
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

// MARK: - Duration Formatting

extension ConnectionViewModel {
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
