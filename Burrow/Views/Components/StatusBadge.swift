import SwiftUI

/// A colored pill showing the current connection status.
struct StatusBadge: View {
    let status: ConnectionStatus
    var overrideText: String?

    var body: some View {
        let text = overrideText ?? status.displayText
        HStack(spacing: 6) {
            Circle()
                .fill(Color.connectionStatus(status))
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.connectionStatus(status).opacity(0.15))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "VPN status: \(text)"))
    }
}

#Preview {
    VStack(spacing: 12) {
        StatusBadge(status: .disconnected)
        StatusBadge(status: .connecting)
        StatusBadge(status: .connected(since: .now))
        StatusBadge(status: .disconnecting)
    }
    .padding()
}
