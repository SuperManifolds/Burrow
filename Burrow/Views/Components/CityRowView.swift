import SwiftUI

/// A row displaying a city name with its ping latency.
struct CityRowView: View {
    let city: RelayCityGroup
    let ping: Int?
    var isFavourite: Bool = false
    var onToggleFavourite: (() -> Void)?

    var body: some View {
        HStack {
            if let onToggleFavourite {
                Button {
                    onToggleFavourite()
                } label: {
                    Image(systemName: isFavourite ? "star.fill" : "star")
                        .font(.caption)
                        .foregroundStyle(isFavourite ? .accent : .secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    isFavourite
                        ? String(localized: "Remove from favourites")
                        : String(localized: "Add to favourites")
                )
            }

            Text(city.cityName)
                .foregroundStyle(.primary)

            Spacer()

            if let ping {
                Text("\(ping) ms")
                    .font(.caption)
                    .foregroundStyle(Color.ping(ping))
                    .monospacedDigit()
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.leading, onToggleFavourite != nil ? 8 : 26)
        .accessibilityLabel("\(city.cityName)")
    }
}

#if DEBUG
#Preview("With Ping") {
    CityRowView(
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
        ping: 42,
        isFavourite: false,
        onToggleFavourite: {}
    )
    .padding()
}

#Preview("Favourited") {
    CityRowView(
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
        ping: 12,
        isFavourite: true,
        onToggleFavourite: {}
    )
    .padding()
}
#endif
