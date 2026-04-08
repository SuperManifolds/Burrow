import SwiftUI

/// A button style that highlights on hover, matching native menu bar dropdowns.
private struct MenuBarButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed ? .accent.opacity(0.2)
                          : isHovered ? .primary.opacity(0.08)
                          : .clear)
            )
            .onHover { isHovered = $0 }
    }
}

/// Compact dropdown view shown from the menu bar icon.
struct MenuBarView: View {
    @ObservedObject var connectionViewModel: ConnectionViewModel
    @ObservedObject var serverListViewModel: ServerListViewModel
    @ObservedObject var accountViewModel: AccountViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            statusHeader
                .padding(12)

            if connectionViewModel.status.isActive {
                Divider()
                disconnectButton
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
            }

            if !serverListViewModel.favouriteCities.isEmpty {
                Divider()
                favouritesSection
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
            }

            Divider()
            actionsSection
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
        }
        .frame(width: 280)
        .task {
            if serverListViewModel.countries.isEmpty {
                await serverListViewModel.loadRelays()
            }
        }
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: statusIcon)
                .font(.title2)
                .foregroundStyle(Color.connectionStatus(connectionViewModel.status))

            VStack(alignment: .leading, spacing: 2) {
                Text(connectionViewModel.status.displayText)
                    .font(.headline)

                if case .connected = connectionViewModel.status {
                    if let locationText = connectedLocationText {
                        Text(locationText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if case .connected = connectionViewModel.status {
                Text(connectionViewModel.formattedDuration)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Favourites

    private var favouritesSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Favourites")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 8)
                .padding(.bottom, 2)

            ForEach(serverListViewModel.favouriteCities, id: \.favouriteID) { entry in
                Button {
                    connectToCity(entry.city)
                } label: {
                    HStack(spacing: 8) {
                        Text(entry.countryCode.countryFlag)
                        Text(entry.city.cityName)
                            .font(.body)
                        Spacer()
                        if let ping = serverListViewModel.pings[entry.city.id] {
                            Text("\(ping) ms")
                                .font(.caption)
                                .foregroundStyle(Color.ping(ping))
                                .monospacedDigit()
                        }
                        if isConnectedToCity(entry.city) {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundStyle(.accent)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MenuBarButtonStyle())
            }
        }
    }

    // MARK: - Actions

    private var disconnectButton: some View {
        Button {
            Task { await connectionViewModel.disconnect() }
        } label: {
            HStack {
                Image(systemName: "xmark.circle")
                Text(String(localized: "Disconnect"))
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuBarButtonStyle())
    }

    private var actionsSection: some View {
        VStack(spacing: 2) {
            Button {
                openWindow(id: "main")
            } label: {
                HStack {
                    Image(systemName: "macwindow")
                    Text(String(localized: "Open Burrow"))
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
            }
            .buttonStyle(MenuBarButtonStyle())

            Divider()
                .padding(.vertical, 4)

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text(String(localized: "Quit Burrow"))
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
            }
            .buttonStyle(MenuBarButtonStyle())
        }
    }

    // MARK: - Helpers

    private var statusIcon: String {
        switch connectionViewModel.status {
            case .connected: "checkmark.shield.fill"
            case .connecting, .disconnecting: "antenna.radiowaves.left.and.right"
            case .disconnected: "shield.slash"
        }
    }

    private var connectedLocationText: String? {
        guard let relay = connectionViewModel.connectedRelay else { return nil }
        let countryCode = String(relay.location.prefix(2))
        for country in serverListViewModel.countries where country.countryCode == countryCode {
            for city in country.cities where city.relays.contains(where: { $0.hostname == relay.hostname }) {
                let flag = country.countryCode.countryFlag
                return "\(flag) \(country.countryName) · \(city.cityName)"
            }
        }
        return nil
    }

    private func isConnectedToCity(_ city: RelayCityGroup) -> Bool {
        guard let connected = connectionViewModel.connectedRelay else { return false }
        return connected.location == city.relays.first?.location
    }

    private func connectToCity(_ city: RelayCityGroup) {
        if let relay = serverListViewModel.selectRelay(in: city) {
            serverListViewModel.selectedRelay = relay
            serverListViewModel.saveSelectedRelay()
            Task {
                await connectionViewModel.connect(to: relay)
            }
        }
    }
}

#if DEBUG
#Preview {
    MenuBarView(
        connectionViewModel: ConnectionViewModel(
            tunnelManager: MockTunnelManager(),
            accountViewModel: AccountViewModel()
        ),
        serverListViewModel: ServerListViewModel.preview(),
        accountViewModel: AccountViewModel()
    )
}
#endif
