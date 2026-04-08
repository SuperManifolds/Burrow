import SwiftUI

/// Expandable country section showing cities and relay counts.
struct CountrySectionView: View {
    let country: RelayCountryGroup
    let onSelectCity: (RelayCityGroup) -> Void

    var body: some View {
        DisclosureGroup {
            ForEach(country.cities) { city in
                Button {
                    onSelectCity(city)
                } label: {
                    HStack {
                        Text(city.cityName)
                            .foregroundStyle(.primary)

                        Spacer()

                        Text("\(city.activeRelayCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "\(city.cityName), \(city.activeRelayCount) servers"))
            }
        } label: {
            HStack(spacing: 8) {
                Text(country.countryCode.countryFlag)
                    .font(.title3)

                Text(country.countryName)
                    .fontWeight(.medium)

                Spacer()

                Text("\(country.activeRelayCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}
