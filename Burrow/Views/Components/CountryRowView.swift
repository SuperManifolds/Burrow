import SwiftUI

/// A row displaying a country name with expand/collapse chevron and city count.
struct CountryRowView: View {
    let country: RelayCountryGroup
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button {
            onToggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 10)
                    .accessibilityHidden(true)

                Text(country.countryCode.countryFlag)

                Text(country.countryName)
                    .fontWeight(.medium)

                Spacer()

                Text("\(country.cities.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(country.countryName), \(country.cities.count) cities")
        .accessibilityHint(isExpanded
            ? String(localized: "Double tap to collapse")
            : String(localized: "Double tap to expand"))
    }
}

#if DEBUG
#Preview("Expanded with Cities") {
    let cities = [
        RelayCityGroup(
            cityName: "Stockholm",
            location: RelayLocation(
                country: "Sweden",
                city: "Stockholm",
                latitude: 59.33,
                longitude: 18.07
            ),
            relays: []
        ),
        RelayCityGroup(
            cityName: "Gothenburg",
            location: RelayLocation(
                country: "Sweden",
                city: "Gothenburg",
                latitude: 57.71,
                longitude: 11.97
            ),
            relays: []
        )
    ]

    List {
        CountryRowView(
            country: RelayCountryGroup(
                countryCode: "se",
                countryName: "Sweden",
                cities: cities
            ),
            isExpanded: true,
            onToggle: {}
        )

        ForEach(cities) { city in
            CityRowView(city: city, ping: 35)
        }
    }
    .frame(width: 260, height: 200)
}
#endif
