import SwiftUI

/// Expandable country section showing cities and relay counts.
struct CountrySectionView: View {
    let country: RelayCountryGroup
    let onSelectCity: (RelayCityGroup) -> Void
    @State private var isExpanded: Bool

    init(country: RelayCountryGroup, defaultExpanded: Bool = false, onSelectCity: @escaping (RelayCityGroup) -> Void) {
        self.country = country
        self.onSelectCity = onSelectCity
        self._isExpanded = State(initialValue: defaultExpanded)
    }

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

#Preview {
    let relay1 = Relay(
        hostname: "se-got-wg-001", location: "se-got", active: true, owned: true,
        provider: "31173", ipv4AddrIn: "185.213.154.68", ipv6AddrIn: "2a03:1b20:5:f011::a01f",
        publicKey: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", weight: 100
    )
    let relay2 = Relay(
        hostname: "se-sto-wg-001", location: "se-sto", active: true, owned: true,
        provider: "31173", ipv4AddrIn: "185.213.154.100", ipv6AddrIn: "2a03:1b20:5:f011::a02f",
        publicKey: "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=", weight: 80
    )
    let country = RelayCountryGroup(
        countryCode: "se",
        countryName: "Sweden",
        cities: [
            RelayCityGroup(
                cityName: "Gothenburg",
                location: RelayLocation(country: "Sweden", city: "Gothenburg", latitude: 57.7, longitude: 11.97),
                relays: [relay1]
            ),
            RelayCityGroup(
                cityName: "Stockholm",
                location: RelayLocation(country: "Sweden", city: "Stockholm", latitude: 59.33, longitude: 18.07),
                relays: [relay2]
            )
        ]
    )

    List {
        CountrySectionView(country: country, defaultExpanded: true) { city in
            print("Selected \(city.cityName)")
        }
    }
    .frame(width: 260, height: 200)
}
