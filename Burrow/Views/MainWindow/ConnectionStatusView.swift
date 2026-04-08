import SwiftUI

/// Large connection status display with connect/disconnect button.
struct ConnectionStatusView: View {
    @ObservedObject var connectionViewModel: ConnectionViewModel
    @ObservedObject var serverListViewModel: ServerListViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Status icon
            Image(systemName: statusIcon)
                .font(.system(size: 64))
                .foregroundStyle(Color.connectionStatus(connectionViewModel.status))
                .symbolEffect(.pulse, isActive: connectionViewModel.status == .connecting)
                .contentTransition(.symbolEffect(.replace))
                .accessibilityLabel(connectionViewModel.status.displayText)

            // Status text
            VStack(spacing: 4) {
                Text(connectionViewModel.status.displayText)
                    .font(.title2)
                    .fontWeight(.semibold)

                if case .connected = connectionViewModel.status {
                    Text(connectionViewModel.formattedDuration)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(String(localized: "Connected for \(connectionViewModel.formattedDuration)"))
                }

                if let relay = connectionViewModel.connectedRelay {
                    Text(relay.hostname)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Connect / Disconnect button
            Button {
                Task {
                    if connectionViewModel.status.isActive {
                        await connectionViewModel.disconnect()
                    } else if let relay = serverListViewModel.selectedRelay {
                        await connectionViewModel.connect(to: relay)
                    }
                }
            } label: {
                Text(connectionViewModel.status.isActive ? String(localized: "Disconnect") : String(localized: "Connect"))
                    .frame(minWidth: 140)
            }
            .buttonStyle(.borderedProminent)
            .tint(connectionViewModel.status.isActive ? .red : .accentColor)
            .controlSize(.large)
            .disabled(
                !connectionViewModel.status.isActive && serverListViewModel.selectedRelay == nil
            )

            if let error = connectionViewModel.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else if !connectionViewModel.status.isActive && serverListViewModel.selectedRelay == nil {
                Text("Select a server from the sidebar")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
        .animation(.easeInOut(duration: 0.3), value: connectionViewModel.status)
    }

    // MARK: - Helpers

    private var statusIcon: String {
        switch connectionViewModel.status {
            case .connected:
                return "checkmark.shield.fill"
            case .connecting, .disconnecting:
                return "antenna.radiowaves.left.and.right"
            case .disconnected:
                return "shield.slash"
        }
    }
}
