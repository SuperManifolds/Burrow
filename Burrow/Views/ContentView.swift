import SwiftUI

/// Root view that shows either onboarding (login) or the main app interface.
struct ContentView: View {
    @EnvironmentObject var accountViewModel: AccountViewModel
    @EnvironmentObject var connectionViewModel: ConnectionViewModel
    @EnvironmentObject var serverListViewModel: ServerListViewModel
    @EnvironmentObject var settingsViewModel: SettingsViewModel

    var body: some View {
        Group {
            if accountViewModel.isLoggedIn {
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
                .onAppear {
                    connectionViewModel.settingsViewModel = settingsViewModel
                }
                .task {
                    if settingsViewModel.autoConnect,
                       !connectionViewModel.status.isActive,
                       serverListViewModel.selectedRelay == nil {
                        while serverListViewModel.countries.isEmpty {
                            try? await Task.sleep(for: .milliseconds(100))
                        }
                        if let relay = serverListViewModel.selectedRelay {
                            await connectionViewModel.connect(to: relay)
                        }
                    }
                }
            } else {
                LoginView(accountViewModel: accountViewModel)
            }
        }
    }
}

#if DEBUG
#Preview("Logged In") {
    let accountVM = AccountViewModel.preview(loggedIn: true)
    let connectionVM = ConnectionViewModel(
        tunnelManager: MockTunnelManager(),
        accountViewModel: accountVM
    )
    let serverListVM = ServerListViewModel.preview()
    let settingsVM = SettingsViewModel(accountViewModel: accountVM)

    ContentView()
        .environmentObject(accountVM)
        .environmentObject(connectionVM)
        .environmentObject(serverListVM)
        .environmentObject(settingsVM)
        .frame(width: 800, height: 600)
}

#Preview("Logged Out") {
    let accountVM = AccountViewModel.preview(loggedIn: false)
    let connectionVM = ConnectionViewModel(
        tunnelManager: MockTunnelManager(),
        accountViewModel: accountVM
    )
    let serverListVM = ServerListViewModel()
    let settingsVM = SettingsViewModel(accountViewModel: accountVM)

    ContentView()
        .environmentObject(accountVM)
        .environmentObject(connectionVM)
        .environmentObject(serverListVM)
        .environmentObject(settingsVM)
        .frame(width: 800, height: 600)
}
#endif
