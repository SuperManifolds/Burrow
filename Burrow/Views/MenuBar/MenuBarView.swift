import SwiftUI

/// A button style that highlights on hover, matching native menu bar dropdowns.
private struct MenuBarButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed ? .accent.opacity(0.2)
                          : isHovered ? .primary.opacity(0.08)
                          : .clear)
            )
            .onHover { isHovered = $0 }
    }
}

/// Compact dropdown view shown from the menu bar icon.
struct MenuBarView: View {
    @ObservedObject var connectionViewModel: ConnectionViewModel
    @ObservedObject var serverListViewModel: ServerListViewModel
    @ObservedObject var accountViewModel: AccountViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // Status header
            HStack(spacing: 10) {
                Image(systemName: statusIcon)
                    .font(.title2)
                    .foregroundStyle(Color.connectionStatus(connectionViewModel.status))
                    .contentTransition(.symbolEffect(.replace))

                VStack(alignment: .leading, spacing: 2) {
                    Text(connectionViewModel.status.displayText)
                        .font(.headline)

                    if case .connected = connectionViewModel.status {
                        if let locationText = connectedLocationText {
                            Text(locationText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                if case .connected = connectionViewModel.status {
                    Text(connectionViewModel.formattedDuration)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .padding(12)

            // Disconnect
            if connectionViewModel.status.isActive {
                Divider()
                Button {
                    Task { await connectionViewModel.disconnect() }
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text(String(localized: "Disconnect"))
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MenuBarButtonStyle())
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
            }

            // Favourites
            if !serverListViewModel.favouriteCities.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Favourites")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 2)

                    ForEach(serverListViewModel.favouriteCities, id: \.favouriteID) { entry in
                        Button {
                            connectToCity(entry.city)
                        } label: {
                            HStack(spacing: 8) {
                                Text(entry.countryCode.countryFlag)
                                Text(entry.city.cityName)
                                    .font(.body)
                                Spacer()
                                if let ping = serverListViewModel.pings[entry.city.id] {
                                    Text("\(ping) ms")
                                        .font(.caption)
                                        .foregroundStyle(Color.ping(ping))
                                        .monospacedDigit()
                                        .accessibilityLabel(String(localized: "Latency: \(ping) milliseconds"))
                                }
                                if isConnectedToCity(entry.city) {
                                    Image(systemName: "checkmark")
                                        .font(.caption)
                                        .foregroundStyle(.accent)
                                        .accessibilityHidden(true)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(MenuBarButtonStyle())
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
            }

            Divider()

            // Actions
            VStack(spacing: 2) {
                Button {
                    openWindow(id: "main")
                    NSApplication.shared.activate()
                } label: {
                    HStack {
                        Image(systemName: "macwindow")
                        Text(String(localized: "Open Burrow"))
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MenuBarButtonStyle())

                SettingsLink {
                    HStack {
                        Image(systemName: "gear")
                        Text(String(localized: "Settings…"))
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MenuBarButtonStyle())
                .simultaneousGesture(TapGesture().onEnded {
                    NSApplication.shared.activate()
                })

                Divider()
                    .padding(.vertical, 4)

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    HStack {
                        Image(systemName: "power")
                        Text(String(localized: "Quit Burrow"))
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MenuBarButtonStyle())
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
        }
        .frame(width: 280)
        .task {
            if serverListViewModel.countries.isEmpty {
                await serverListViewModel.loadRelays()
            }
        }
    }

    // MARK: - Helpers

    private var statusIcon: String {
        switch connectionViewModel.status {
            case .connected: "checkmark.shield.fill"
            case .connecting, .disconnecting: "antenna.radiowaves.left.and.right"
            case .disconnected: "shield.slash"
        }
    }

    private var connectedLocationText: String? {
        guard let relay = connectionViewModel.connectedRelay,
              let info = serverListViewModel.relayIndex[relay.hostname] else { return nil }
        let flag = info.countryCode.countryFlag
        return "\(flag) \(info.countryName) · \(info.cityName)"
    }

    private func isConnectedToCity(_ city: RelayCityGroup) -> Bool {
        guard let connected = connectionViewModel.connectedRelay else { return false }
        return connected.location == city.relays.first?.location
    }

    private func connectToCity(_ city: RelayCityGroup) {
        if let relay = serverListViewModel.selectRelay(in: city) {
            serverListViewModel.selectedRelay = relay
            serverListViewModel.saveSelectedRelay()
            Task {
                await connectionViewModel.connect(to: relay)
            }
        }
    }
}

#if DEBUG
#Preview {
    MenuBarView(
        connectionViewModel: ConnectionViewModel(
            tunnelManager: MockTunnelManager(),
            accountViewModel: AccountViewModel()
        ),
        serverListViewModel: ServerListViewModel.preview(),
        accountViewModel: AccountViewModel()
    )
}
#endif
