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
    @Published private(set) var pings: [String: Int] = [:]

    /// Countries filtered by the current search text.
    var filteredCountries: [RelayCountryGroup] {
        guard !searchText.isEmpty else { return countries }
        let query = searchText.lowercased()

        return countries.compactMap { country in
            if country.countryName.lowercased().contains(query) {
                return country
            }

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
    private let pingService = PingService()

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
            countries = relayService.groupedRelays(from: relayList)
            measurePings()
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

    #if DEBUG
    /// Create a view model pre-populated with relay data from the bundled JSON.
    static func preview() -> ServerListViewModel {
        let vm = ServerListViewModel()
        guard let url = Bundle.main.url(forResource: "preview_relays", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return vm
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let relayList = try? decoder.decode(RelayList.self, from: data) else {
            return vm
        }
        let service = RelayListService(apiClient: MullvadAPIClient())
        vm.countries = service.groupedRelays(from: relayList)
        for country in vm.countries {
            for city in country.cities {
                vm.pings[city.id] = Int.random(in: 10...200)
            }
        }
        return vm
    }
    #endif

    /// Measure ping to one relay per city.
    private func measurePings() {
        let targets: [(String, String)] = countries.flatMap { $0.cities }.compactMap { city in
            guard let relay = city.relays.first(where: \.active) else { return nil }
            return (city.id, relay.ipv4AddrIn)
        }

        Task.detached { [pingService] in
            let results = await pingService.measureAll(targets)
            await MainActor.run { [weak self] in
                for (cityID, ms) in results {
                    self?.pings[cityID] = ms
                }
            }
        }
    }
}
