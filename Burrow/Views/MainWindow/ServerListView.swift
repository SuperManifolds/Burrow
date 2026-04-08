import SwiftUI

/// Sidebar view showing relay servers grouped by country and city.
struct ServerListView: View {
    @ObservedObject var serverListViewModel: ServerListViewModel
    @ObservedObject var connectionViewModel: ConnectionViewModel
    @EnvironmentObject var accountViewModel: AccountViewModel

    @State private var expandedCountries: Set<String>
    @State private var selectedTag: String?

    init(
        serverListViewModel: ServerListViewModel,
        connectionViewModel: ConnectionViewModel,
        expandedCountries: Set<String> = []
    ) {
        self.serverListViewModel = serverListViewModel
        self.connectionViewModel = connectionViewModel
        _expandedCountries = State(initialValue: expandedCountries)
    }

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
                List(selection: selectedHostnameBinding) {
                    if !serverListViewModel.favouriteCities.isEmpty
                        && serverListViewModel.searchText.isEmpty {
                        Section {
                            ForEach(
                                serverListViewModel.favouriteCities,
                                id: \.favouriteID
                            ) { entry in
                                FavouriteRowView(
                                    city: entry.city,
                                    countryCode: entry.countryCode,
                                    ping: serverListViewModel.pings[entry.city.id],
                                    onUnfavourite: {
                                        serverListViewModel.toggleFavourite(entry.city)
                                    }
                                )
                                .tag("fav-\(entry.city.relays.first(where: \.active)?.hostname ?? entry.city.id)")
                            }
                        } header: {
                            Text("Favourites")
                        }
                    }

                    Section {
                        ForEach(serverListViewModel.filteredCountries) { country in
                            CountryRowView(
                                country: country,
                                isExpanded: isExpanded(country)
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if expandedCountries.contains(country.id) {
                                        expandedCountries.remove(country.id)
                                    } else {
                                        expandedCountries.insert(country.id)
                                    }
                                }
                            }

                            if isExpanded(country) {
                                ForEach(country.cities) { city in
                                    CityRowView(
                                        city: city,
                                        ping: serverListViewModel.pings[city.id],
                                        isFavourite: serverListViewModel.isFavourite(city),
                                        onToggleFavourite: {
                                            serverListViewModel.toggleFavourite(city)
                                        }
                                    )
                                    .tag(city.relays.first(where: \.active)?.hostname ?? city.id)
                                }
                            }
                        }
                    } header: {
                        if !serverListViewModel.favouriteCities.isEmpty
                            && serverListViewModel.searchText.isEmpty {
                            Text("All Servers")
                        }
                    }
                }
                .contextMenu(forSelectionType: String.self) { _ in
                } primaryAction: { hostnames in
                    guard let hostname = hostnames.first else { return }
                    for country in serverListViewModel.countries {
                        for city in country.cities where city.relays.contains(where: { $0.hostname == hostname }) {
                            selectAndConnect(city)
                            return
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
                if let log = connectionViewModel.readTunnelLog() {
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

    // MARK: - Selection Binding

    private var selectedHostnameBinding: Binding<String?> {
        Binding(
            get: { selectedTag },
            set: { tag in
                selectedTag = tag
                DispatchQueue.main.async {
                    guard let tag else {
                        serverListViewModel.selectedRelay = nil
                        return
                    }
                    let hostname = tag.hasPrefix("fav-")
                        ? String(tag.dropFirst(4))
                        : tag
                    for country in serverListViewModel.countries {
                        for city in country.cities {
                            if let relay = city.relays.first(where: { $0.hostname == hostname }) {
                                serverListViewModel.selectedRelay = relay
                                serverListViewModel.saveSelectedRelay()
                                return
                            }
                        }
                    }
                }
            }
        )
    }

    // MARK: - Helpers

    private func selectAndConnect(_ city: RelayCityGroup) {
        if let relay = serverListViewModel.selectRelay(in: city) {
            serverListViewModel.selectedRelay = relay
            serverListViewModel.saveSelectedRelay()
            Task {
                await connectionViewModel.connect(to: relay)
            }
        }
    }

    private func isExpanded(_ country: RelayCountryGroup) -> Bool {
        expandedCountries.contains(country.id) || !serverListViewModel.searchText.isEmpty
    }

}

#if DEBUG
#Preview {
    let serverListVM = ServerListViewModel.preview()
    let accountVM = AccountViewModel()
    let connectionVM = ConnectionViewModel(
        tunnelManager: MockTunnelManager(),
        accountViewModel: accountVM
    )

    ServerListView(
        serverListViewModel: serverListVM,
        connectionViewModel: connectionVM,
        expandedCountries: ["se"]
    )
    .environmentObject(accountVM)
    .frame(width: 260, height: 500)
}
#endif
