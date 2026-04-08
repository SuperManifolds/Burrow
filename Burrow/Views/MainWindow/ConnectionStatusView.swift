import SwiftUI

/// Large connection status display with connect/disconnect button.
struct ConnectionStatusView: View {
    @ObservedObject var connectionViewModel: ConnectionViewModel
    @ObservedObject var serverListViewModel: ServerListViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Status icon
            Image(systemName: statusIcon)
                .font(.system(size: 64))
                .foregroundStyle(Color.connectionStatus(connectionViewModel.status))
                .symbolEffect(.pulse, isActive: connectionViewModel.status == .connecting)
                .contentTransition(.symbolEffect(.replace))
                .accessibilityLabel(connectionViewModel.status.displayText)

            // Status text
            VStack(spacing: 6) {
                Text(connectionViewModel.status.displayText)
                    .font(.title2)
                    .fontWeight(.semibold)

                if case .connected = connectionViewModel.status {
                    if let locationText = connectedLocationText {
                        Text(locationText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    if let relay = connectionViewModel.connectedRelay {
                        HStack(spacing: 4) {
                            Text(relay.hostname)
                            Text("·")
                            Text("WireGuard")
                                .foregroundStyle(.accent)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    // Duration badge
                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(connectionViewModel.formattedDuration)
                            .font(.caption)
                            .fontWeight(.medium)
                            .monospacedDigit()
                    }
                    .foregroundStyle(.accent.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.accent.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .accessibilityLabel(
                        String(localized: "Connected for \(connectionViewModel.formattedDuration)")
                    )
                }
            }

            // Connect / Disconnect button
            Button {
                Task {
                    if connectionViewModel.status.isActive {
                        await connectionViewModel.disconnect()
                    } else if let relay = serverListViewModel.selectedRelay {
                        await connectionViewModel.connect(to: relay)
                    }
                }
            } label: {
                let label = connectionViewModel.status.isActive
                    ? String(localized: "Disconnect")
                    : String(localized: "Connect")
                Text(label)
                    .frame(minWidth: 140)
            }
            .buttonStyle(.borderedProminent)
            .tint(connectionViewModel.status.isActive ? .red : .accentColor)
            .controlSize(.large)
            .disabled(
                !connectionViewModel.status.isActive && serverListViewModel.selectedRelay == nil
            )

            if let error = connectionViewModel.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else if !connectionViewModel.status.isActive
                        && serverListViewModel.selectedRelay == nil {
                Text("Select a server from the sidebar")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Connection details bar (only when connected)
            if case .connected = connectionViewModel.status {
                connectionDetailsBar
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .animation(.easeInOut(duration: 0.3), value: connectionViewModel.status)
    }

    // MARK: - Connection Details Bar

    @ViewBuilder
    private var connectionDetailsBar: some View {
        HStack(spacing: 10) {
            ConnectionDetailCard(label: String(localized: "IP Address")) {
                Text(connectionViewModel.connectedRelay?.ipv4AddrIn ?? "—")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }

            ConnectionDetailCard(label: String(localized: "Protocol")) {
                Text("WireGuard")
                    .font(.callout)
                    .fontWeight(.semibold)
            }

            ConnectionDetailCard(label: String(localized: "Latency")) {
                if let ping = connectedPing {
                    HStack(spacing: 4) {
                        Text("\(ping) ms")
                            .font(.callout)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                        Text(latencyLabel(ping))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .fixedSize()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.ping(ping).opacity(0.2))
                            .foregroundStyle(Color.ping(ping))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                } else {
                    Text("—")
                        .font(.callout)
                        .fontWeight(.semibold)
                }
            }

            ConnectionDetailCard(label: String(localized: "Transfer")) {
                HStack(spacing: 8) {
                    Text("↑ \(ConnectionViewModel.formattedBytes(connectionViewModel.transferTx))")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(Color(.systemGreen))
                    Text("↓ \(ConnectionViewModel.formattedBytes(connectionViewModel.transferRx))")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(Color(.systemBlue))
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal)
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

    /// Find the country and city for the connected relay.
    private var connectedCity: (country: RelayCountryGroup, city: RelayCityGroup)? {
        guard let relay = connectionViewModel.connectedRelay else { return nil }
        let countryCode = String(relay.location.prefix(2))
        for country in serverListViewModel.countries where country.countryCode == countryCode {
            for city in country.cities where city.relays.contains(where: { $0.hostname == relay.hostname }) {
                return (country, city)
            }
        }
        return nil
    }

    /// Resolve connected relay's location to "🇸🇪 Sweden · City".
    private var connectedLocationText: String? {
        guard let match = connectedCity else { return nil }
        let flag = match.country.countryCode.countryFlag
        return "\(flag) \(match.country.countryName) · \(match.city.cityName)"
    }

    /// Look up ping for the city containing the connected relay.
    private var connectedPing: Int? {
        guard let match = connectedCity else { return nil }
        return serverListViewModel.pings[match.city.id]
    }

    private func latencyLabel(_ ms: Int) -> String {
        switch ms {
            case ..<25: String(localized: "Excellent")
            case ..<50: String(localized: "Great")
            case ..<80: String(localized: "Good")
            case ..<120: String(localized: "Fair")
            case ..<180: String(localized: "Slow")
            default: String(localized: "Poor")
        }
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
#endif
