import Foundation

/// Manages fetching, caching, and grouping of Mullvad relay servers.
actor RelayListService {

    // MARK: - Properties

    private let apiClient: APIClientProtocol
    private let cacheURL: URL
    private let cacheMaxAge: TimeInterval

    private var cachedRelayList: RelayList?
    private var lastFetchDate: Date?

    // MARK: - Initialization

    init(
        apiClient: APIClientProtocol,
        cacheDirectory: URL? = nil,
        cacheMaxAge: TimeInterval = 3600 // 1 hour
    ) {
        self.apiClient = apiClient
        self.cacheMaxAge = cacheMaxAge

        let directory = cacheDirectory ?? FileManager.default.urls(
            for: .cachesDirectory, in: .userDomainMask
        ).first!.appendingPathComponent("com.burrow.vpn", isDirectory: true)

        self.cacheURL = directory.appendingPathComponent("relays.json")
    }

    // MARK: - Public API

    /// Fetch the relay list, using cache if available and fresh.
    /// - Parameter forceRefresh: Bypass the cache and fetch from the API.
    /// - Returns: The current relay list.
    func fetchRelayList(forceRefresh: Bool = false) async throws -> RelayList {
        // Return cached data if fresh
        if !forceRefresh, let cached = try loadCachedRelayList(), isCacheFresh() {
            return cached
        }

        // Fetch from API
        let relayList = try await apiClient.fetchRelayList()
        cachedRelayList = relayList
        lastFetchDate = Date()

        // Persist to disk in the background
        try? saveToDisk(relayList)

        return relayList
    }

    /// Group relays by country and city for UI display.
    /// - Parameter relayList: The relay list to group.
    /// - Returns: Sorted array of country groups, each containing city groups.
    func groupedRelays(from relayList: RelayList) -> [RelayCountryGroup] {
        // Build a mapping of location key → (location, relays)
        var cityMap: [String: (location: RelayLocation, relays: [Relay])] = [:]

        for relay in relayList.wireguard.relays {
            guard let location = relayList.locations[relay.location] else { continue }
            if cityMap[relay.location] != nil {
                cityMap[relay.location]?.relays.append(relay)
            } else {
                cityMap[relay.location] = (location, [relay])
            }
        }

        // Group by country
        var countryMap: [String: (name: String, cities: [RelayCityGroup])] = [:]

        for (locationKey, entry) in cityMap {
            let countryCode = String(locationKey.prefix(2))
            let cityGroup = RelayCityGroup(
                cityName: entry.location.city,
                location: entry.location,
                relays: entry.relays.sorted { $0.hostname < $1.hostname }
            )

            if countryMap[countryCode] != nil {
                countryMap[countryCode]?.cities.append(cityGroup)
            } else {
                countryMap[countryCode] = (entry.location.country, [cityGroup])
            }
        }

        // Sort countries alphabetically, cities alphabetically within
        return countryMap.map { code, entry in
            RelayCountryGroup(
                countryCode: code,
                countryName: entry.name,
                cities: entry.cities.sorted { $0.cityName < $1.cityName }
            )
        }.sorted { $0.countryName < $1.countryName }
    }

    // MARK: - Cache Management

    private func isCacheFresh() -> Bool {
        guard let lastFetch = lastFetchDate else { return false }
        return Date().timeIntervalSince(lastFetch) < cacheMaxAge
    }

    private func loadCachedRelayList() throws -> RelayList? {
        if let cached = cachedRelayList {
            return cached
        }

        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: cacheURL)
        let relayList = try Self.decodeRelayList(from: data)
        cachedRelayList = relayList

        // Use file modification date as last fetch date
        let attributes = try FileManager.default.attributesOfItem(atPath: cacheURL.path)
        lastFetchDate = attributes[.modificationDate] as? Date

        return relayList
    }

    private func saveToDisk(_ relayList: RelayList) throws {
        let directory = cacheURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true
        )

        let data = try Self.encodeRelayList(relayList)
        try data.write(to: cacheURL, options: .atomic)
    }

    // Nonisolated helpers to avoid Swift 6 actor-isolation warnings with Codable
    private nonisolated static func decodeRelayList(from data: Data) throws -> RelayList {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(RelayList.self, from: data)
    }

    private nonisolated static func encodeRelayList(_ relayList: RelayList) throws -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return try encoder.encode(relayList)
    }
}
