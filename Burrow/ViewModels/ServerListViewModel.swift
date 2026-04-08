import Combine
import Foundation
import Network

/// Manages the relay server list — fetching, grouping, searching, and selection.
@MainActor
final class ServerListViewModel: ObservableObject {

    // MARK: - Published State

    @Published private(set) var countries: [RelayCountryGroup] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var error: String?
    @Published var searchText: String = ""
    @Published var selectedRelay: Relay?

    /// Ping latency in ms per city ID.
    @Published private(set) var pings: [String: Int] = [:]

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

    /// Measure ping to one relay per city concurrently.
    func measurePings() {
        let cities = countries.flatMap { $0.cities }

        for city in cities {
            guard let relay = city.relays.first(where: \.active) else { continue }
            let cityID = city.id

            Task.detached { [weak self] in
                let ms = await Self.measureTCPLatency(to: relay.ipv4AddrIn, port: 443)
                await MainActor.run {
                    self?.pings[cityID] = ms
                }
            }
        }
    }

    /// Measure TCP connection establishment time to estimate latency.
    private static func measureTCPLatency(to host: String, port: UInt16) async -> Int? {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return nil }
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: nwPort,
            using: .tcp
        )

        return await withCheckedContinuation { (continuation: CheckedContinuation<Int?, Never>) in
            let start = DispatchTime.now()
            var resumed = false

            connection.stateUpdateHandler = { state in
                guard !resumed else { return }
                switch state {
                    case .ready, .failed, .waiting:
                        resumed = true
                        let elapsed = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
                        let ms = Int(elapsed / 1_000_000)
                        connection.cancel()
                        continuation.resume(returning: ms)
                    case .cancelled:
                        if !resumed {
                            resumed = true
                            continuation.resume(returning: nil)
                        }
                    default:
                        break
                }
            }

            connection.start(queue: .global(qos: .utility))

            // Timeout after 3 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                guard !resumed else { return }
                resumed = true
                connection.cancel()
                continuation.resume(returning: nil)
            }
        }
    }
}
