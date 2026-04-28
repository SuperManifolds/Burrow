import AppIntents

/// A city-level server entity for Shortcuts parameter resolution.
struct ServerEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Server")

    static var defaultQuery = ServerEntityQuery()

    var id: String
    var cityName: String
    var countryName: String
    var countryCode: String

    init(city: RelayCityGroup, country: RelayCountryGroup) {
        self.id = city.id
        self.cityName = city.cityName
        self.countryName = country.countryName
        self.countryCode = country.countryCode
    }

    var displayRepresentation: DisplayRepresentation {
        let flag = countryCode.countryFlag
        return DisplayRepresentation(title: "\(flag) \(cityName), \(countryName)")
    }
}

struct ServerEntityQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [ServerEntity] {
        guard let serverList = AppState.shared.serverListViewModel else { return [] }
        return serverList.countries.flatMap { country in
            country.cities.compactMap { city in
                guard identifiers.contains(city.id) else { return nil }
                return ServerEntity(city: city, country: country)
            }
        }
    }

    @MainActor
    func suggestedEntities() async throws -> [ServerEntity] {
        guard let serverList = AppState.shared.serverListViewModel else { return [] }
        let favouriteIDs = serverList.favouriteCityIDs
        return serverList.countries.flatMap { country in
            country.cities
                .filter { favouriteIDs.contains($0.id) }
                .map { ServerEntity(city: $0, country: country) }
        }
    }
}

extension ServerEntityQuery: EntityStringQuery {
    @MainActor
    func entities(matching query: String) async throws -> [ServerEntity] {
        guard let serverList = AppState.shared.serverListViewModel else { return [] }
        let lowered = query.lowercased()
        return serverList.countries.flatMap { country in
            country.cities.compactMap { city in
                let matches = city.cityName.lowercased().contains(lowered)
                    || country.countryName.lowercased().contains(lowered)
                    || country.countryCode.lowercased() == lowered
                guard matches else { return nil }
                return ServerEntity(city: city, country: country)
            }
        }
    }
}
