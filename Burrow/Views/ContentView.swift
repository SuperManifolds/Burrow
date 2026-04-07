import SwiftUI

/// Root view that shows either onboarding (login) or the main app interface.
struct ContentView: View {
    @EnvironmentObject var accountViewModel: AccountViewModel
    @EnvironmentObject var connectionViewModel: ConnectionViewModel
    @EnvironmentObject var serverListViewModel: ServerListViewModel

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
    }
}
