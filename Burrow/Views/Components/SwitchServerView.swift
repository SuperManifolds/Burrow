import SwiftUI

/// Shows the selected server info and a switch button when a different server is selected while connected.
struct SwitchServerView: View {
    let locationText: String?
    let hostname: String?
    let onSwitch: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Text(String(localized: "Switch to"))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
            if let locationText {
                Text(locationText)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            if let hostname {
                Text(hostname)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))

        Button {
            onSwitch()
        } label: {
            Text(String(localized: "Switch"))
                .frame(minWidth: 140)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .hoverScale()
        .transition(.scale.combined(with: .opacity))
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 24) {
        SwitchServerView(
            locationText: "🇩🇪 Germany · Berlin",
            hostname: "de-ber-wg-001",
            onSwitch: {}
        )
    }
    .padding()
}
#endif
