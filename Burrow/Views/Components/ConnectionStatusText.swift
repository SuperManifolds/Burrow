import SwiftUI

/// Displays the connection status label, location, hostname, and duration badge.
struct ConnectionStatusText: View {
    @ObservedObject var connectionViewModel: ConnectionViewModel
    @ObservedObject var serverListViewModel: ServerListViewModel

    var body: some View {
        VStack(spacing: 6) {
            Text(connectionViewModel.statusDisplayText)
                .font(.title2)
                .fontWeight(.semibold)

            if case .connected = connectionViewModel.status {
                if let locationText = connectedLocationText {
                    Text(locationText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
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
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .accessibilityHidden(true)
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
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel(
                    String(localized: "Connected for \(connectionViewModel.formattedDuration)")
                )
            }
        }
    }

    private var connectedLocationText: String? {
        guard let relay = connectionViewModel.connectedRelay,
              let info = serverListViewModel.relayIndex[relay.hostname] else { return nil }
        let flag = info.countryCode.countryFlag
        return "\(flag) \(info.countryName) · \(info.cityName)"
    }
}

#if DEBUG
#Preview("Disconnected") {
    ConnectionStatusText(
        connectionViewModel: ConnectionViewModel(
            tunnelManager: MockTunnelManager(),
            accountViewModel: AccountViewModel()
        ),
        serverListViewModel: ServerListViewModel()
    )
    .padding()
}

#Preview("Connected") {
    ConnectionStatusText(
        connectionViewModel: ConnectionViewModel(
            tunnelManager: MockTunnelManager(
                status: .connected(since: Date().addingTimeInterval(-3600)),
                connectedRelay: Relay(
                    hostname: "se-got-wg-001", location: "se-got",
                    active: true, owned: true, provider: "31173",
                    ipv4AddrIn: "185.213.154.68",
                    ipv6AddrIn: "2a03:1b20:5:f011::a01f",
                    publicKey: "bGVhc2VzYXRpc2ZpZWQ=", weight: 100
                )
            ),
            accountViewModel: AccountViewModel()
        ),
        serverListViewModel: ServerListViewModel.preview()
    )
    .padding()
}
#endif
