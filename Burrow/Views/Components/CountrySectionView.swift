import SwiftUI

/// Expandable country section showing cities and relay counts.
struct CountrySectionView: View {
    let country: RelayCountryGroup
    let onSelectCity: (RelayCityGroup) -> Void

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ForEach(country.cities) { city in
                Button {
                    onSelectCity(city)
                } label: {
                    HStack {
                        Text(city.cityName)
                            .foregroundStyle(.primary)

                        Spacer()

                        Text("\(city.relays.filter(\.active).count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
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
