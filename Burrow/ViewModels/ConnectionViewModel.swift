import Combine
import Foundation

/// Manages VPN connection state and coordinates between tunnel manager and UI.
@MainActor
final class ConnectionViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var status: ConnectionStatus = .disconnected
    @Published private(set) var connectedRelay: Relay?
    @Published private(set) var connectionDuration: TimeInterval = 0

    // MARK: - Dependencies

    private let tunnelManager: TunnelManager
    private let accountViewModel: AccountViewModel
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
        guard let device = accountViewModel.device,
              let privateKey = accountViewModel.privateKey() else {
            return
        }

        do {
            try await tunnelManager.connect(to: relay, with: device, privateKey: privateKey)
            startDurationTimer()
        } catch {
            // Error handling will be driven by tunnelManager.status
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
