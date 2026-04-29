import Combine
import Foundation
import OSLog

/// Manages the relay server list — fetching, grouping, searching, and selection.
@MainActor
final class ServerListViewModel: ObservableObject {

    // MARK: - Published State

    struct RelayInfo {
        let countryCode: String
        let countryName: String
        let cityName: String
        let cityId: String
    }

    @Published private(set) var countries: [RelayCountryGroup] = []
    /// O(1) lookup from relay hostname to location info.
    private(set) var relayIndex: [String: RelayInfo] = [:]
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: String?
    @Published var searchText: String = ""
    @Published var selectedRelay: Relay?
    @Published private(set) var pings: [String: Int] = [:]
    @Published var favouriteCityIDs: Set<String>

    // MARK: - Favourites

    struct FavouriteCity {
        let city: RelayCityGroup
        let countryCode: String
        /// Distinct ID to avoid collisions with city rows in the same List.
        var favouriteID: String { "fav-\(city.id)" }
    }

    /// Favourite cities resolved from the current country list.
    var favouriteCities: [FavouriteCity] {
        guard !favouriteCityIDs.isEmpty else { return [] }
        var results: [FavouriteCity] = []
        for country in countries {
            for city in country.cities where favouriteCityIDs.contains(city.id) {
                results.append(FavouriteCity(city: city, countryCode: country.countryCode))
            }
        }
        return results.sorted { $0.city.cityName < $1.city.cityName }
    }

    func isFavourite(_ city: RelayCityGroup) -> Bool {
        favouriteCityIDs.contains(city.id)
    }

    func toggleFavourite(_ city: RelayCityGroup) {
        if favouriteCityIDs.contains(city.id) {
            favouriteCityIDs.remove(city.id)
        } else {
            favouriteCityIDs.insert(city.id)
        }
        saveFavourites()
    }

    private static let favouritesKey = "BurrowFavouriteCityIDs"
    private static let lastSelectedRelayKey = "BurrowLastSelectedRelay"

    private func saveFavourites() {
        UserDefaults.standard.set(
            Array(favouriteCityIDs),
            forKey: Self.favouritesKey
        )
    }

    private static func loadFavourites() -> Set<String> {
        let array = UserDefaults.standard.stringArray(
            forKey: favouritesKey
        ) ?? []
        return Set(array)
    }

    func saveSelectedRelay() {
        UserDefaults.standard.set(
            selectedRelay?.hostname,
            forKey: Self.lastSelectedRelayKey
        )
    }

    private func restoreLastSelectedRelay() {
        guard let hostname = UserDefaults.standard.string(
            forKey: Self.lastSelectedRelayKey
        ) else { return }
        for country in countries {
            for city in country.cities {
                if let relay = city.relays.first(where: { $0.hostname == hostname }) {
                    selectedRelay = relay
                    return
                }
            }
        }
    }

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

    init(provider: VPNProvider = MullvadAPIClient()) {
        self.relayService = RelayListService(provider: provider)
        self.favouriteCityIDs = Self.loadFavourites()
    }

    // MARK: - Public API

    /// Fetch and group the relay list.
    func loadRelays() async {
        Log.relays.info("Loading relays")
        isLoading = true
        error = nil

        do {
            let relayList = try await relayService.fetchRelayList()
            countries = relayService.groupedRelays(from: relayList)
            buildRelayIndex()
            restoreLastSelectedRelay()
            measurePings()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// Returns the selected relay, or falls back to the top favourite city.
    var bestAvailableRelay: Relay? {
        selectedRelay ?? favouriteCities.first.flatMap { selectRelay(in: $0.city) }
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
        vm.favouriteCityIDs = [] // Don't inherit persisted favourites in previews
        guard let url = Bundle.main.url(forResource: "preview_relays", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return vm
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let relayList = try? decoder.decode(RelayList.self, from: data) else {
            return vm
        }
        let service = RelayListService(provider: MullvadAPIClient())
        vm.countries = service.groupedRelays(from: relayList)
        vm.buildRelayIndex()
        var sampleFavourites: Set<String> = []
        for country in vm.countries {
            for city in country.cities {
                vm.pings[city.id] = Int.random(in: 10...200)
            }
            // Pick the first city of the first two countries as favourites
            if sampleFavourites.count < 3,
               let city = country.cities.first {
                sampleFavourites.insert(city.id)
            }
        }
        vm.favouriteCityIDs = sampleFavourites
        return vm
    }
    #endif

    private func buildRelayIndex() {
        var index: [String: RelayInfo] = [:]
        for country in countries {
            for city in country.cities {
                for relay in city.relays {
                    index[relay.hostname] = RelayInfo(
                        countryCode: country.countryCode,
                        countryName: country.countryName,
                        cityName: city.cityName,
                        cityId: city.id
                    )
                }
            }
        }
        relayIndex = index
    }

    /// Measure ping to one relay per city.
    private func measurePings() {
        Log.relays.info("Starting ping measurement for \(self.countries.flatMap(\.cities).count) cities")
        let targets: [(String, String)] = countries.flatMap { $0.cities }.compactMap { city in
            guard let relay = city.relays.first(where: \.active) else { return nil }
            return (city.id, relay.ipv4AddrIn)
        }

        Task.detached { [pingService] in
            let results = await pingService.measureAll(targets)
            await MainActor.run { [weak self] in
                guard let self else { return }
                var updated = self.pings
                for (cityID, ms) in results {
                    updated[cityID] = ms
                }
                self.pings = updated
            }
        }
    }
}
