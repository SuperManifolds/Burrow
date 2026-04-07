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

    // MARK: - Dependencies

    private let tunnelManager: TunnelManager
    private let accountViewModel: AccountViewModel
    var settingsViewModel: SettingsViewModel?
    private var durationTimer: Timer?

    // MARK: - Initialization

    init(tunnelManager: TunnelManager, accountViewModel: AccountViewModel) {
        self.tunnelManager = tunnelManager
        self.accountViewModel = accountViewModel

        // Observe tunnel manager status changes
        tunnelManager.$status
            .receive(on: RunLoop.main)
            .assign(to: &$status)

        tunnelManager.$connectedRelay
            .receive(on: RunLoop.main)
            .assign(to: &$connectedRelay)
    }

    // MARK: - Public API

    /// Connect to a specific relay.
    func connect(to relay: Relay) async {
        error = nil

        guard let device = accountViewModel.device else {
            error = "No device registered. Try logging out and back in."
            print("[Burrow] Connect failed: no device")
            return
        }

        guard let privateKey = accountViewModel.privateKey() else {
            error = "Missing private key. Try logging out and back in."
            print("[Burrow] Connect failed: no private key")
            return
        }

        do {
            let port = settingsViewModel?.effectivePort ?? 51820
            let dns = settingsViewModel?.effectiveDNS ?? "10.64.0.1"
            print("[Burrow] Connecting to \(relay.hostname) (\(relay.ipv4AddrIn):\(port))")
            try await tunnelManager.connect(to: relay, with: device, privateKey: privateKey, port: port, dns: dns)
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
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            Task { @MainActor [weak self] in
                self?.connectionDuration = Date().timeIntervalSince(startDate)
            }
        }
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
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
}
