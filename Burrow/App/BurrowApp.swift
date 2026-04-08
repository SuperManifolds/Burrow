import Combine
import SwiftUI

@main
struct BurrowApp: App {

    // MARK: - State

    @StateObject private var accountViewModel = AccountViewModel()
    @StateObject private var tunnelManager = TunnelManager()
    @StateObject private var serverListViewModel = ServerListViewModel()
    @StateObject private var connectionStore = ConnectionViewModelStore()
    @StateObject private var settingsStore = SettingsViewModelStore()

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
                .environmentObject(settingsStore.resolve(accountViewModel: accountViewModel))
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 800, height: 600)

        Settings {
            SettingsView(
                settingsViewModel: settingsStore.resolve(accountViewModel: accountViewModel),
                accountViewModel: accountViewModel
            )
        }
    }
}

/// Holds a lazily-created ConnectionViewModel so it can be a @StateObject.
@MainActor
final class ConnectionViewModelStore: ObservableObject {
    private var viewModel: ConnectionViewModel?

    func resolve(
        tunnelManager: any TunnelManaging,
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

/// Holds a lazily-created SettingsViewModel so it can be a @StateObject.
@MainActor
final class SettingsViewModelStore: ObservableObject {
    private var viewModel: SettingsViewModel?

    func resolve(accountViewModel: AccountViewModel) -> SettingsViewModel {
        if let existing = viewModel { return existing }
        let vm = SettingsViewModel(accountViewModel: accountViewModel)
        viewModel = vm
        return vm
    }
}
