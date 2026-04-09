import SwiftUI

/// A colored pill showing the current connection status.
struct StatusBadge: View {
    let status: ConnectionStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.connectionStatus(status))
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)

            Text(status.displayText)
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
        .accessibilityLabel(String(localized: "VPN status: \(status.displayText)"))
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
