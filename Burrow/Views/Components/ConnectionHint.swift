import SwiftUI

/// Contextual hint shown below the connect button when disconnected.
/// Shows error, selected server info, or a prompt to select a server.
struct ConnectionHint: View {
    @ObservedObject var connectionViewModel: ConnectionViewModel
    @ObservedObject var serverListViewModel: ServerListViewModel

    var body: some View {
        if let error = connectionViewModel.error {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        } else if serverListViewModel.selectedRelay == nil {
            Text("Select a server from the sidebar")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .transition(.opacity)
        } else {
            VStack(spacing: 2) {
                if let locationText = selectedLocationText {
                    Text(locationText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let hostname = serverListViewModel.selectedRelay?.hostname {
                    Text(hostname)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var selectedLocationText: String? {
        guard let relay = serverListViewModel.selectedRelay,
              let info = serverListViewModel.relayIndex[relay.hostname] else { return nil }
        let flag = info.countryCode.countryFlag
        return "\(flag) \(info.countryName) · \(info.cityName)"
    }
}

#if DEBUG
#Preview("No Selection") {
    ConnectionHint(
        connectionViewModel: ConnectionViewModel(
            tunnelManager: MockTunnelManager(),
            accountViewModel: AccountViewModel()
        ),
        serverListViewModel: ServerListViewModel()
    )
    .padding()
}

#Preview("Server Selected") {
    ConnectionHint(
        connectionViewModel: ConnectionViewModel(
            tunnelManager: MockTunnelManager(),
            accountViewModel: AccountViewModel()
        ),
        serverListViewModel: ServerListViewModel.preview()
    )
    .padding()
}
#endif
