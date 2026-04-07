import SwiftUI

/// Root view that shows either onboarding (login) or the main app interface.
struct ContentView: View {
    @EnvironmentObject var accountViewModel: AccountViewModel
    @EnvironmentObject var tunnelManager: TunnelManager
    @EnvironmentObject var connectionViewModel: ConnectionViewModel
    @EnvironmentObject var serverListViewModel: ServerListViewModel
    @EnvironmentObject var settingsViewModel: SettingsViewModel

    var body: some View {
        Group {
            if accountViewModel.isLoggedIn {
                mainInterface
            } else {
                LoginView(accountViewModel: accountViewModel)
            }
        }
    }

    // MARK: - Main Interface

    private var mainInterface: some View {
        NavigationSplitView {
            ServerListView(
                serverListViewModel: serverListViewModel,
                connectionViewModel: connectionViewModel
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
        } detail: {
            ConnectionStatusView(
                connectionViewModel: connectionViewModel,
                serverListViewModel: serverListViewModel
            )
        }
        .navigationTitle("Burrow")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button("Print Tunnel Log") {
                        if let log = tunnelManager.readTunnelLog() {
                            print("=== TUNNEL LOG ===")
                            print(log)
                            print("=== END TUNNEL LOG ===")
                        } else {
                            print("[Burrow] No tunnel log available")
                        }
                    }
                    Divider()
                    Button("Log Out") {
                        connectionViewModel.settingsViewModel = nil
                        accountViewModel.logout()
                    }
                    Divider()
                    Button("Quit Burrow") {
                        NSApplication.shared.terminate(nil)
                    }
                } label: {
                    Image(systemName: "person.circle")
                }
                .accessibilityLabel("Account menu")
            }
        }
        .onAppear {
            connectionViewModel.settingsViewModel = settingsViewModel
        }
    }
}
