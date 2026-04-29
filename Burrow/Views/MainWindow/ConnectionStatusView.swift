import SwiftUI

/// Large connection status display with connect/disconnect button.
struct ConnectionStatusView: View {
    @ObservedObject var connectionViewModel: ConnectionViewModel
    @ObservedObject var serverListViewModel: ServerListViewModel
    @State private var iconScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Status icon
            Image(systemName: statusIcon)
                .font(.system(size: 64))
                .foregroundStyle(Color.connectionStatus(connectionViewModel.status))
                .symbolEffect(.pulse, isActive: connectionViewModel.status == .connecting)
                .contentTransition(.symbolEffect(.replace))
                .scaleEffect(iconScale)
                .accessibilityLabel(connectionViewModel.statusDisplayText)
                .onChange(of: connectionViewModel.status) {
                    withAnimation(.spring(duration: 0.4, bounce: 0.5)) {
                        iconScale = 1.15
                    }
                    withAnimation(.spring(duration: 0.4, bounce: 0.3).delay(0.2)) {
                        iconScale = 1.0
                    }
                    AccessibilityNotification.Announcement(
                        connectionViewModel.statusDisplayText
                    ).post()
                }

            ConnectionStatusText(
                connectionViewModel: connectionViewModel,
                serverListViewModel: serverListViewModel
            )

            if hasDifferentServerSelected {
                SwitchServerView(
                    locationText: serverListViewModel.selectedRelay.flatMap { locationText(for: $0) },
                    hostname: serverListViewModel.selectedRelay?.hostname
                ) {
                    guard let relay = serverListViewModel.selectedRelay else { return }
                    Task {
                        await connectionViewModel.disconnect()
                        try? await Task.sleep(for: .milliseconds(500))
                        await connectionViewModel.connect(to: relay)
                    }
                }
            }

            ConnectButton(
                isActive: connectionViewModel.status.isActive,
                isDisabled: !connectionViewModel.status.isActive
                    && serverListViewModel.selectedRelay == nil,
                onConnect: {
                    if let relay = serverListViewModel.selectedRelay {
                        Task { await connectionViewModel.connect(to: relay) }
                    }
                },
                onDisconnect: {
                    Task { await connectionViewModel.disconnect() }
                }
            )

            if !connectionViewModel.status.isActive {
                ConnectionHint(
                    connectionViewModel: connectionViewModel,
                    serverListViewModel: serverListViewModel
                )
            }

            Spacer()

            // Connection details bar (only when connected)
            if case .connected = connectionViewModel.status {
                ConnectionDetailsBar(
                    ipAddress: connectionViewModel.connectedRelay?.ipv4AddrIn,
                    ping: connectedPing,
                    transferTx: connectionViewModel.transferTx,
                    transferRx: connectionViewModel.transferRx
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .animation(.spring(duration: 0.5, bounce: 0.2), value: connectionViewModel.status)
        .animation(.spring(duration: 0.4, bounce: 0.15), value: serverListViewModel.selectedRelay?.hostname)
    }

    // MARK: - Helpers

    private var statusIcon: String {
        switch connectionViewModel.status {
            case .connected:
                return "checkmark.shield.fill"
            case .connecting, .disconnecting:
                return "antenna.radiowaves.left.and.right"
            case .disconnected:
                return "shield.slash"
        }
    }

    /// Whether a different city is selected than the one currently connected to.
    private var hasDifferentServerSelected: Bool {
        guard case .connected = connectionViewModel.status,
              let connected = connectionViewModel.connectedRelay,
              let selected = serverListViewModel.selectedRelay else {
            return false
        }
        return connected.location != selected.location
    }

    private func locationText(for relay: Relay) -> String? {
        guard let info = serverListViewModel.relayIndex[relay.hostname] else { return nil }
        let flag = info.countryCode.countryFlag
        return "\(flag) \(info.countryName) · \(info.cityName)"
    }

    /// Look up ping for the city containing the connected relay.
    private var connectedPing: Int? {
        guard let relay = connectionViewModel.connectedRelay,
              let info = serverListViewModel.relayIndex[relay.hostname] else { return nil }
        return serverListViewModel.pings[info.cityId]
    }

}

#if DEBUG
#Preview("Disconnected") {
    let connectionVM = ConnectionViewModel(
        tunnelManager: MockTunnelManager(),
        accountViewModel: AccountViewModel()
    )

    ConnectionStatusView(
        connectionViewModel: connectionVM,
        serverListViewModel: ServerListViewModel()
    )
    .frame(width: 500, height: 500)
}

#Preview("Connected") {
    let relay = Relay(
        hostname: "se-got-wg-001",
        location: "se-got",
        active: true,
        owned: true,
        provider: "31173",
        ipv4AddrIn: "185.213.154.68",
        ipv6AddrIn: "2a03:1b20:5:f011::a01f",
        publicKey: "bGVhc2VzYXRpc2ZpZWQ=",
        weight: 100
    )
    let connectionVM: ConnectionViewModel = {
        let vm = ConnectionViewModel(
            tunnelManager: MockTunnelManager(
                status: .connected(since: Date().addingTimeInterval(-3600)),
                connectedRelay: relay
            ),
            accountViewModel: AccountViewModel()
        )
        vm.setPreviewTransferStats(tx: 1_207_959_552, rx: 356_515_840)
        return vm
    }()

    ConnectionStatusView(
        connectionViewModel: connectionVM,
        serverListViewModel: ServerListViewModel.preview()
    )
    .frame(width: 700, height: 500)
}

#Preview("Switch Server") {
    let connectedRelay = Relay(
        hostname: "se-got-wg-001",
        location: "se-got",
        active: true,
        owned: true,
        provider: "31173",
        ipv4AddrIn: "185.213.154.68",
        ipv6AddrIn: "2a03:1b20:5:f011::a01f",
        publicKey: "bGVhc2VzYXRpc2ZpZWQ=",
        weight: 100
    )
    let connectionVM: ConnectionViewModel = {
        let vm = ConnectionViewModel(
            tunnelManager: MockTunnelManager(
                status: .connected(since: Date().addingTimeInterval(-3600)),
                connectedRelay: connectedRelay
            ),
            accountViewModel: AccountViewModel()
        )
        vm.setPreviewTransferStats(tx: 1_207_959_552, rx: 356_515_840)
        return vm
    }()
    let serverListVM: ServerListViewModel = {
        let vm = ServerListViewModel.preview()
        for country in vm.countries where country.countryCode == "de" {
            if let city = country.cities.first,
               let relay = city.relays.first {
                vm.selectedRelay = relay
                break
            }
        }
        return vm
    }()

    ConnectionStatusView(
        connectionViewModel: connectionVM,
        serverListViewModel: serverListVM
    )
    .frame(width: 700, height: 550)
}
#endif
