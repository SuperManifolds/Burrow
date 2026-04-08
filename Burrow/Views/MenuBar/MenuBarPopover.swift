import SwiftUI

/// Compact popover shown from the menu bar icon.
struct MenuBarPopover: View {
    @ObservedObject var connectionViewModel: ConnectionViewModel
    @ObservedObject var serverListViewModel: ServerListViewModel
    @ObservedObject var accountViewModel: AccountViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Status header
            statusHeader
                .padding()

            Divider()

            // Quick server list
            if serverListViewModel.countries.isEmpty {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading servers...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(serverListViewModel.filteredCountries.prefix(20)) { country in
                            ForEach(country.cities) { city in
                                cityRow(country: country, city: city)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .searchable(text: $serverListViewModel.searchText, prompt: "Search")
            }

            Divider()

            // Footer
            HStack {
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)

                Spacer()

                if accountViewModel.isLoggedIn {
                    Button("Log Out") {
                        accountViewModel.logout()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 320, height: 400)
        .task {
            if serverListViewModel.countries.isEmpty {
                await serverListViewModel.loadRelays()
            }
        }
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        VStack(spacing: 8) {
            HStack {
                StatusBadge(status: connectionViewModel.status)
                Spacer()
                if case .connected = connectionViewModel.status {
                    Text(connectionViewModel.formattedDuration)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            if let relay = connectionViewModel.connectedRelay {
                HStack {
                    Text(relay.hostname)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Disconnect") {
                        Task { await connectionViewModel.disconnect() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    // MARK: - City Row

    private func cityRow(country: RelayCountryGroup, city: RelayCityGroup) -> some View {
        Button {
            if let relay = serverListViewModel.selectRelay(in: city) {
                serverListViewModel.selectedRelay = relay
                Task { await connectionViewModel.connect(to: relay) }
            }
        } label: {
            HStack(spacing: 8) {
                Text(country.countryCode.countryFlag)
                    .font(.callout)

                VStack(alignment: .leading, spacing: 1) {
                    Text(city.cityName)
                        .font(.callout)
                    Text(country.countryName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(city.activeRelayCount)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview {
    let accountVM = AccountViewModel()
    let connectionVM = ConnectionViewModel(tunnelManager: MockTunnelManager(), accountViewModel: accountVM)

    MenuBarPopover(
        connectionViewModel: connectionVM,
        serverListViewModel: ServerListViewModel(),
        accountViewModel: accountVM
    )
}
#endif
