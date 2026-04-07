import Combine
import SwiftUI

@main
struct BurrowApp: App {

    // MARK: - State

    @StateObject private var accountViewModel = AccountViewModel()
    @StateObject private var tunnelManager = TunnelManager()
    @StateObject private var serverListViewModel = ServerListViewModel()
    @StateObject private var connectionStore = ConnectionViewModelStore()

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(accountViewModel)
                .environmentObject(connectionStore.resolve(
                    tunnelManager: tunnelManager,
                    accountViewModel: accountViewModel
                ))
                .environmentObject(serverListViewModel)
        }
        .defaultSize(width: 800, height: 600)
    }
}

/// Holds a lazily-created ConnectionViewModel so it can be a @StateObject.
@MainActor
final class ConnectionViewModelStore: ObservableObject {
    private var viewModel: ConnectionViewModel?

    func resolve(
        tunnelManager: TunnelManager,
        accountViewModel: AccountViewModel
    ) -> ConnectionViewModel {
        if let existing = viewModel { return existing }
        let vm = ConnectionViewModel(
            tunnelManager: tunnelManager,
            accountViewModel: accountViewModel
        )
        viewModel = vm
        return vm
    }
}
