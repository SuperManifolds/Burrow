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

    private var connectionViewModel: ConnectionViewModel {
        connectionStore.resolve(
            tunnelManager: tunnelManager,
            accountViewModel: accountViewModel
        )
    }

    var body: some Scene {
        Window("Burrow", id: "main") {
            ContentView()
                .environmentObject(accountViewModel)
                .environmentObject(connectionViewModel)
                .environmentObject(serverListViewModel)
                .environmentObject(settingsStore.resolve(accountViewModel: accountViewModel))
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 800, height: 600)
        .defaultLaunchBehavior(accountViewModel.isLoggedIn ? .suppressed : .presented)

        Settings {
            SettingsView(
                settingsViewModel: settingsStore.resolve(accountViewModel: accountViewModel),
                accountViewModel: accountViewModel
            )
        }

        MenuBarExtra {
            if !isPreview {
                MenuBarView(
                    connectionViewModel: connectionViewModel,
                    serverListViewModel: serverListViewModel,
                    accountViewModel: accountViewModel
                )
            }
        } label: {
            if !isPreview {
                Image(systemName: menuBarIcon)
                    .symbolRenderingMode(.monochrome)
            }
        }
        .menuBarExtraStyle(.window)
    }

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"
    }

    private var menuBarIcon: String {
        switch connectionStore.resolve(
            tunnelManager: tunnelManager,
            accountViewModel: accountViewModel
        ).status {
            case .connected: "checkmark.shield.fill"
            case .connecting, .disconnecting: "antenna.radiowaves.left.and.right"
            case .disconnected: "shield.slash"
        }
    }
}

#if DEBUG
#Preview("Main Window") {
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
        .toolbar(.hidden, for: .windowToolbar)
}
#endif
