import Combine
import Foundation

/// Manages the relay server list — fetching, grouping, searching, and selection.
@MainActor
final class ServerListViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var countries: [RelayCountryGroup] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: String?
    @Published var searchText: String = ""
    @Published var selectedRelay: Relay?

    /// Countries filtered by the current search text.
    var filteredCountries: [RelayCountryGroup] {
        guard !searchText.isEmpty else { return countries }
        let query = searchText.lowercased()

        return countries.compactMap { country in
            // Match country name
            if country.countryName.lowercased().contains(query) {
                return country
            }

            // Match city names within country
            let matchingCities = country.cities.filter {
                $0.cityName.lowercased().contains(query)
            }

            if matchingCities.isEmpty { return nil }

            return RelayCountryGroup(
                countryCode: country.countryCode,
                countryName: country.countryName,
                cities: matchingCities
            )
        }
    }

    // MARK: - Dependencies

    private let relayService: RelayListService

    // MARK: - Initialization

    init(apiClient: APIClientProtocol = MullvadAPIClient()) {
        self.relayService = RelayListService(apiClient: apiClient)
    }

    // MARK: - Public API

    /// Fetch and group the relay list.
    func loadRelays() async {
        isLoading = true
        error = nil

        do {
            let relayList = try await relayService.fetchRelayList()
            countries = await relayService.groupedRelays(from: relayList)
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// Select a random active relay from a specific city.
    func selectRelay(in city: RelayCityGroup) -> Relay? {
        let selector = WeightedRandomRelaySelector()
        return selector.selectRelay(from: city.relays, in: nil)
    }
}
