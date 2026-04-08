import SwiftUI

/// A row displaying a city name with its ping latency.
struct CityRowView: View {
    let city: RelayCityGroup
    let ping: Int?
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack {
                Text(city.cityName)
                    .foregroundStyle(.primary)

                Spacer()

                if let ping {
                    Text("\(ping) ms")
                        .font(.caption)
                        .foregroundStyle(pingColor(ping))
                        .monospacedDigit()
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.leading, 26)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(city.cityName)")
    }

    private func pingColor(_ ms: Int) -> Color {
        switch ms {
            case ..<25:     Color(.systemGreen)
            case ..<50:     Color(.systemMint)
            case ..<80:     Color(.systemTeal)
            case ..<120:    Color(.systemYellow)
            case ..<180:    Color(.systemOrange)
            case ..<250:    Color(.systemPink)
            default:        Color(.systemRed)
        }
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
        onSelect: {}
    )
    .padding()
}

#Preview("Loading Ping") {
    CityRowView(
        city: RelayCityGroup(
            cityName: "Gothenburg",
            location: RelayLocation(
                country: "Sweden",
                city: "Gothenburg",
                latitude: 57.71,
                longitude: 11.97
            ),
            relays: []
        ),
        ping: nil,
        onSelect: {}
    )
    .padding()
}
#endif
