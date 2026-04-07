import SwiftUI

/// Sidebar view showing relay servers grouped by country and city.
struct ServerListView: View {
    @ObservedObject var serverListViewModel: ServerListViewModel
    @ObservedObject var connectionViewModel: ConnectionViewModel

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

                        if expandedCountries.contains(country.id) {
                            ForEach(country.cities) { city in
                                cityRow(country: country, city: city)
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $serverListViewModel.searchText, prompt: "Search countries or cities")
        .task {
            if serverListViewModel.countries.isEmpty {
                await serverListViewModel.loadRelays()
            }
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
                Image(systemName: expandedCountries.contains(country.id) ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 10)

                Text(country.countryCode.countryFlag)

                Text(country.countryName)
                    .fontWeight(.medium)

                Spacer()

                Text("\(country.activeRelayCount)")
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

                Text("\(city.activeRelayCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.leading, 26)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(city.cityName), \(city.activeRelayCount) servers")
    }
}
