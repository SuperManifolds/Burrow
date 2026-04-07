import SwiftUI

/// Sidebar view showing relay servers grouped by country and city.
struct ServerListView: View {
    @ObservedObject var serverListViewModel: ServerListViewModel
    @ObservedObject var connectionViewModel: ConnectionViewModel

    var body: some View {
        List {
            if serverListViewModel.isLoading && serverListViewModel.countries.isEmpty {
                ProgressView("Loading servers...")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
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
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else {
                ForEach(serverListViewModel.filteredCountries) { country in
                    CountrySectionView(country: country) { city in
                        if let relay = serverListViewModel.selectRelay(in: city) {
                            serverListViewModel.selectedRelay = relay
                            Task {
                                await connectionViewModel.connect(to: relay)
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
}
