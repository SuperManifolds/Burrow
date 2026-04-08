import SwiftUI

/// A row displaying a favourited city with country flag, name, ping, and unfavourite button.
struct FavouriteRowView: View {
    let city: RelayCityGroup
    let countryCode: String
    let ping: Int?
    let onUnfavourite: () -> Void
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 8) {
                Button {
                    onUnfavourite()
                } label: {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Remove from favourites"))

                Text(countryCode.countryFlag)

                Text(city.cityName)
                    .foregroundStyle(.primary)

                Spacer()

                if let ping {
                    Text("\(ping) ms")
                        .font(.caption)
                        .foregroundStyle(Color.ping(ping))
                        .monospacedDigit()
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview {
    List {
        FavouriteRowView(
            city: RelayCityGroup(
                cityName: "Stockholm",
                location: RelayLocation(
                    country: "Sweden",
                    city: "Stockholm",
                    latitude: 59.33,
                    longitude: 18.07
                ),
                relays: []
            ),
            countryCode: "se",
            ping: 12,
            onUnfavourite: {},
            onSelect: {}
        )
        FavouriteRowView(
            city: RelayCityGroup(
                cityName: "Berlin",
                location: RelayLocation(
                    country: "Germany",
                    city: "Berlin",
                    latitude: 52.52,
                    longitude: 13.41
                ),
                relays: []
            ),
            countryCode: "de",
            ping: 34,
            onUnfavourite: {},
            onSelect: {}
        )
    }
    .frame(width: 260, height: 200)
}
#endif
