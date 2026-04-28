import KeyboardShortcuts
import SwiftUI

/// Preferences window with tabbed sections for General, VPN, and Devices.
struct SettingsView: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @ObservedObject var accountViewModel: AccountViewModel
    @ObservedObject var updaterViewModel: UpdaterViewModel

    var body: some View {
        TabView {
            Tab("General", systemImage: "gear") {
                GeneralSettingsTab(
                    settingsViewModel: settingsViewModel,
                    updaterViewModel: updaterViewModel
                )
            }

            Tab("VPN", systemImage: "network") {
                VPNSettingsTab(settingsViewModel: settingsViewModel)
            }

            Tab("Devices", systemImage: "laptopcomputer.and.iphone") {
                DevicesSettingsTab(
                    settingsViewModel: settingsViewModel,
                    accountViewModel: accountViewModel
                )
            }
        }
        .frame(width: 450, height: 300)
    }
}

// MARK: - General Tab

private struct GeneralSettingsTab: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @ObservedObject var updaterViewModel: UpdaterViewModel

    var body: some View {
        Form {
            Toggle("Launch Burrow at login", isOn: $settingsViewModel.launchAtLogin)
            Toggle("Auto-connect on launch", isOn: $settingsViewModel.autoConnect)
            Toggle("Connection notifications", isOn: $settingsViewModel.showConnectionNotifications)

            Section("Keyboard Shortcut") {
                KeyboardShortcuts.Recorder(
                    String(localized: "Toggle Connection"),
                    name: .toggleConnection
                )
            }

            Section("Menu Bar") {
                Picker("Display", selection: $settingsViewModel.menuBarDisplay) {
                    ForEach(MenuBarDisplayMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                Toggle("Colored icon", isOn: $settingsViewModel.coloredMenuBarIcon)
            }

            Section {
                Button("Check for Updates…") {
                    updaterViewModel.checkForUpdates()
                }
                .disabled(!updaterViewModel.canCheckForUpdates)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - VPN Tab

private struct VPNSettingsTab: View {
    @ObservedObject var settingsViewModel: SettingsViewModel

    var body: some View {
        Form {
            Section("DNS") {
                Picker("DNS Server", selection: $settingsViewModel.dnsOption) {
                    ForEach(DNSOption.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }

                if settingsViewModel.dnsOption == .custom {
                    TextField("DNS Address", text: $settingsViewModel.customDNS)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityHint(String(localized: "Enter the IP address of your custom DNS server"))
                }
            }

            Section("WireGuard Port") {
                Picker("Port", selection: $settingsViewModel.wireGuardPort) {
                    ForEach(WireGuardPort.allCases) { port in
                        Text(port.displayName).tag(port)
                    }
                }
            }

            Section("MTU") {
                TextField("MTU", value: $settingsViewModel.mtu, formatter: NumberFormatter())
                    .textFieldStyle(.roundedBorder)
                    .accessibilityHint(String(localized: "Maximum transmission unit size. Valid range: 1280 to 9000"))
                Text("Default: \(TunnelDefaults.mtu). Valid range: 1280–9000.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Devices Tab

private struct DevicesSettingsTab: View {
    @ObservedObject var settingsViewModel: SettingsViewModel
    @ObservedObject var accountViewModel: AccountViewModel
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        VStack(spacing: 0) {
            if settingsViewModel.isLoadingDevices {
                Spacer()
                ProgressView("Loading devices…")
                Spacer()
            } else if let error = settingsViewModel.deviceError {
                Spacer()
                Text(error)
                    .foregroundStyle(.secondary)
                if settingsViewModel.isDeviceErrorSessionExpired {
                    Button(String(localized: "Log Out")) {
                        accountViewModel.logout()
                        openWindow(id: "main")
                        NSApplication.shared.activate()
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button(String(localized: "Retry")) {
                        Task { await settingsViewModel.loadDevices() }
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
            } else if settingsViewModel.devices.isEmpty {
                Spacer()
                Text("No devices registered.")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List {
                    if let expiry = settingsViewModel.accountExpiry {
                        Section {
                            HStack {
                                Text("Subscription")
                                Spacer()
                                if expiry > Date() {
                                    Text("Expires \(expiry, style: .relative)")
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("Expired")
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }

                    Section("Devices") {
                        ForEach(settingsViewModel.devices) { device in
                            DeviceRow(
                                device: device,
                                isCurrentDevice: device.id == accountViewModel.device?.id,
                                onRemove: {
                                    Task { await settingsViewModel.removeDevice(device) }
                                }
                            )
                        }
                    }
                }
            }
        }
        .task {
            await settingsViewModel.loadDevices()
        }
    }
}

// MARK: - Device Row

#if DEBUG
#Preview {
    let accountVM = AccountViewModel()

    SettingsView(
        settingsViewModel: SettingsViewModel(accountViewModel: accountVM),
        accountViewModel: accountVM,
        updaterViewModel: UpdaterViewModel()
    )
}
#endif

// MARK: - Device Row

private struct DeviceRow: View {
    let device: Device
    let isCurrentDevice: Bool
    let onRemove: () -> Void

    @State private var showConfirmation = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(device.name)
                        .fontWeight(.medium)
                    if isCurrentDevice {
                        Text("This device")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.fill.tertiary, in: Capsule())
                    }
                }
                Text(device.ipv4Address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !isCurrentDevice {
                Button(role: .destructive) {
                    showConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(String(localized: "Remove \(device.name)"))
                .confirmationDialog(
                    "Remove \(device.name)?",
                    isPresented: $showConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Remove", role: .destructive, action: onRemove)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
