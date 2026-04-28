import AppKit
import Combine
import KeyboardShortcuts
import SwiftUI

@main
struct BurrowApp: App {

    // MARK: - State

    @StateObject private var accountViewModel = AccountViewModel()
    @StateObject private var tunnelManager = TunnelManager()
    @StateObject private var serverListViewModel = ServerListViewModel()
    @StateObject private var connectionStore = ConnectionViewModelStore()
    @StateObject private var settingsStore = SettingsViewModelStore()
    @StateObject private var updaterViewModel = UpdaterViewModel()

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
                accountViewModel: accountViewModel,
                updaterViewModel: updaterViewModel
            )
        }

        MenuBarExtra {
            if !isPreview {
                MenuBarView(
                    connectionViewModel: connectionViewModel,
                    serverListViewModel: serverListViewModel,
                    accountViewModel: accountViewModel,
                    updaterViewModel: updaterViewModel
                )
            }
        } label: {
            if !isPreview {
                MenuBarLabel(
                    connectionViewModel: connectionViewModel,
                    serverListViewModel: serverListViewModel,
                    settingsViewModel: settingsStore.resolve(accountViewModel: accountViewModel)
                )
            }
        }
        .menuBarExtraStyle(.window)
    }

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PLAYGROUNDS"] == "1"
    }

}

// MARK: - Menu Bar Label

private struct MenuBarLabel: View {
    @ObservedObject var connectionViewModel: ConnectionViewModel
    @ObservedObject var serverListViewModel: ServerListViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel

    var body: some View {
        HStack(spacing: 4) {
            if settingsViewModel.coloredMenuBarIcon {
                Image(nsImage: coloredIcon)
            } else {
                Image(systemName: icon)
                    .symbolRenderingMode(.monochrome)
            }

            if let statusText {
                Text(statusText)
                    .monospacedDigit()
            }
        }
        .task {
            if serverListViewModel.countries.isEmpty {
                await serverListViewModel.loadRelays()
            }
        }
        .task {
            for await _ in KeyboardShortcuts.events(.keyUp, for: .toggleConnection) {
                toggleConnection()
            }
        }
    }

    private func toggleConnection() {
        guard connectionViewModel.status != .connecting,
              connectionViewModel.status != .disconnecting else { return }

        Task {
            if connectionViewModel.status.isActive {
                await connectionViewModel.disconnect()
            } else if let relay = serverListViewModel.selectedRelay
                        ?? serverListViewModel.favouriteCities.first
                            .flatMap({ serverListViewModel.selectRelay(in: $0.city) }) {
                await connectionViewModel.connect(to: relay)
            }
        }
    }

    private var icon: String {
        switch connectionViewModel.status {
            case .connected: "checkmark.shield.fill"
            case .connecting, .disconnecting: "antenna.radiowaves.left.and.right"
            case .disconnected: "shield.slash"
        }
    }

    private var coloredIcon: NSImage {
        guard let base = NSImage(systemSymbolName: icon, accessibilityDescription: "Burrow") else {
            return NSImage()
        }
        let config = NSImage.SymbolConfiguration(paletteColors: [iconNSColor])
        let image = base.withSymbolConfiguration(config) ?? base
        image.isTemplate = false
        return image
    }

    private var iconNSColor: NSColor {
        switch connectionViewModel.status {
            case .connected: .systemGreen
            case .connecting, .disconnecting: .systemOrange
            case .disconnected: .secondaryLabelColor
        }
    }

    private var statusText: String? {
        guard case .connected = connectionViewModel.status else { return nil }

        let mode = settingsViewModel.menuBarDisplay
        guard mode != .iconOnly else { return nil }

        let time = connectionViewModel.formattedDuration
        let location: String? = {
            guard let relay = connectionViewModel.connectedRelay,
                  let info = serverListViewModel.relayIndex[relay.hostname] else { return nil }
            return "\(info.countryCode.countryFlag) \(info.cityName)"
        }()

        switch mode {
            case .iconOnly:
                return nil
            case .iconAndTime:
                return time
            case .iconAndLocation:
                return location
            case .iconAndBoth:
                guard let location else { return time }
                return "\(location) \(time)"
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
