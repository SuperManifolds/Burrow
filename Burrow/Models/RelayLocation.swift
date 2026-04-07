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
}

// MARK: - Grouped Display Models

/// A country with its associated cities and relays, for UI display.
struct RelayCountryGroup: Sendable, Identifiable {
    let countryCode: String
    let countryName: String
    let cities: [RelayCityGroup]

    var id: String { countryCode }

    /// Total number of active relays across all cities.
    var activeRelayCount: Int {
        cities.reduce(0) { $0 + $1.relays.filter(\.active).count }
    }
}

/// A city with its associated relays, for UI display.
struct RelayCityGroup: Sendable, Identifiable {
    let cityName: String
    let location: RelayLocation
    let relays: [Relay]

    var id: String { "\(location.country)-\(cityName)" }
}
