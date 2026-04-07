import Foundation

/// Strategy for selecting a relay from a list of candidates.
protocol RelaySelecting: Sendable {
    /// Select a relay from the given list, optionally filtered to a location.
    /// - Parameters:
    ///   - relays: All available relays.
    ///   - location: Optional location filter (country/city).
    /// - Returns: The selected relay.
    func selectRelay(from relays: [Relay], in location: RelayLocation?) -> Relay?
}

// MARK: - Built-in Strategies

/// Selects a random relay weighted by the relay's `weight` field.
struct WeightedRandomRelaySelector: RelaySelecting {
    func selectRelay(from relays: [Relay], in location: RelayLocation?) -> Relay? {
        let candidates = relays.filter(\.active)
        guard !candidates.isEmpty else { return nil }

        let totalWeight = candidates.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return candidates.randomElement() }

        var random = Int.random(in: 0..<totalWeight)
        for relay in candidates {
            random -= relay.weight
            if random < 0 {
                return relay
            }
        }

        return candidates.last
    }
}
