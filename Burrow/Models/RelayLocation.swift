import Foundation

/// Geographic location metadata for a relay group (country + city).
struct RelayLocation: Sendable, Codable, Equatable {
    /// Full country name (e.g. "United States").
    let country: String

    /// City name (e.g. "New York").
    let city: String

    /// Geographic latitude.
    let latitude: Double

    /// Geographic longitude.
    let longitude: Double
}

// MARK: - API Response Structures

/// Top-level relay list response from `GET /app/v1/relays`.
struct RelayList: Sendable, Codable {
    /// Map of location keys (e.g. "us-nyc") to location metadata.
    let locations: [String: RelayLocation]

    /// WireGuard-specific relay data.
    let wireguard: WireGuardRelays

    enum CodingKeys: String, CodingKey {
        case locations, wireguard
    }
}

/// WireGuard relay configuration from the relay list API.
struct WireGuardRelays: Sendable, Codable {
    /// All available WireGuard relays.
    let relays: [Relay]

    /// Allowed port ranges as `[min, max]` pairs.
    let portRanges: [[Int]]

    /// Default IPv4 gateway for WireGuard tunnels.
    let ipv4Gateway: String

    /// Default IPv6 gateway for WireGuard tunnels.
    let ipv6Gateway: String

    enum CodingKeys: String, CodingKey {
        case relays, portRanges, ipv4Gateway, ipv6Gateway
    }
}

// MARK: - Grouped Display Models

/// A country with its associated cities and relays, for UI display.
struct RelayCountryGroup: Sendable, Identifiable {
    let countryCode: String
    let countryName: String
    let cities: [RelayCityGroup]
    let activeRelayCount: Int

    var id: String { countryCode }

    init(countryCode: String, countryName: String, cities: [RelayCityGroup]) {
        self.countryCode = countryCode
        self.countryName = countryName
        self.cities = cities
        self.activeRelayCount = cities.reduce(0) { $0 + $1.activeRelayCount }
    }
}

/// A city with its associated relays, for UI display.
struct RelayCityGroup: Sendable, Identifiable {
    let cityName: String
    let location: RelayLocation
    let relays: [Relay]
    let activeRelayCount: Int

    var id: String { "\(location.country)-\(cityName)" }

    init(cityName: String, location: RelayLocation, relays: [Relay]) {
        self.cityName = cityName
        self.location = location
        self.relays = relays
        self.activeRelayCount = relays.filter(\.active).count
    }
}
