import SwiftUI

/// Sidebar view showing relay servers grouped by country and city.
struct ServerListView: View {
    @ObservedObject var serverListViewModel: ServerListViewModel
    @ObservedObject var connectionViewModel: ConnectionViewModel
    @EnvironmentObject var accountViewModel: AccountViewModel
    @EnvironmentObject var tunnelManager: TunnelManager

    @State private var expandedCountries: Set<String> = []

    var body: some View {
        Group {
            if serverListViewModel.isLoading && serverListViewModel.countries.isEmpty {
                VStack {
                    Spacer()
                    ProgressView("Loading servers...")
                    Spacer()
                }
            } else if let error = serverListViewModel.error {
                VStack(spacing: 8) {
                    Text("Failed to load servers")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        Task { await serverListViewModel.loadRelays() }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(serverListViewModel.filteredCountries) { country in
                        countryRow(country)

                        if isExpanded(country) {
                            ForEach(country.cities) { city in
                                cityRow(country: country, city: city)
                            }
                        }
                    }
                }
                .searchable(
                    text: $serverListViewModel.searchText,
                    placement: .sidebar,
                    prompt: "Search countries or cities"
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                accountMenu
            }
        }
        .task {
            if serverListViewModel.countries.isEmpty {
                await serverListViewModel.loadRelays()
            }
        }
    }

    // MARK: - Account Menu

    private var accountMenu: some View {
        Menu {
            Button("Print Tunnel Log") {
                if let log = tunnelManager.readTunnelLog() {
                    print("=== TUNNEL LOG ===")
                    print(log)
                    print("=== END TUNNEL LOG ===")
                } else {
                    print("[Burrow] No tunnel log available")
                }
            }
            Divider()
            Button("Log Out") {
                connectionViewModel.settingsViewModel = nil
                accountViewModel.logout()
            }
            Divider()
            Button("Quit Burrow") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image(systemName: "person.circle")
        }
        .accessibilityLabel(String(localized: "Account menu"))
    }

    // MARK: - Helpers

    private func isExpanded(_ country: RelayCountryGroup) -> Bool {
        expandedCountries.contains(country.id) || !serverListViewModel.searchText.isEmpty
    }

    private func pingColor(_ ms: Int) -> Color {
        switch ms {
            case ..<25:     Color(.systemGreen)
            case ..<50:     Color(.systemMint)
            case ..<80:     Color(.systemTeal)
            case ..<120:    Color(.systemYellow)
            case ..<180:    Color(.systemOrange)
            case ..<250:    Color(.systemPink)
            default:        Color(.systemRed)
        }
    }

    // MARK: - Rows

    private func countryRow(_ country: RelayCountryGroup) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if expandedCountries.contains(country.id) {
                    expandedCountries.remove(country.id)
                } else {
                    expandedCountries.insert(country.id)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isExpanded(country) ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 10)

                Text(country.countryCode.countryFlag)

                Text(country.countryName)
                    .fontWeight(.medium)

                Spacer()

                Text("\(country.cities.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .buttonStyle(.plain)
    }

    private func cityRow(country: RelayCountryGroup, city: RelayCityGroup) -> some View {
        Button {
            if let relay = serverListViewModel.selectRelay(in: city) {
                serverListViewModel.selectedRelay = relay
                Task {
                    await connectionViewModel.connect(to: relay)
                }
            }
        } label: {
            HStack {
                Text(city.cityName)
                    .foregroundStyle(.primary)

                Spacer()

                if let ping = serverListViewModel.pings[city.id] {
                    Text("\(ping) ms")
                        .font(.caption)
                        .foregroundStyle(pingColor(ping))
                        .monospacedDigit()
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.leading, 26)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(city.cityName)")
    }
}
