import Combine
import Foundation
import ServiceManagement

/// Manages user preferences and device management for the Settings window.
@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - General Settings

    @Published var launchAtLogin: Bool {
        didSet { updateLaunchAtLogin() }
    }

    @Published var autoConnect: Bool {
        didSet { UserDefaults.standard.set(autoConnect, forKey: "auto_connect") }
    }

    @Published var menuBarDisplay: MenuBarDisplayMode {
        didSet { UserDefaults.standard.set(menuBarDisplay.rawValue, forKey: "menu_bar_display") }
    }

    @Published var coloredMenuBarIcon: Bool {
        didSet { UserDefaults.standard.set(coloredMenuBarIcon, forKey: "colored_menu_bar_icon") }
    }

    @Published var showConnectionNotifications: Bool {
        didSet { UserDefaults.standard.set(showConnectionNotifications, forKey: "show_connection_notifications") }
    }

    // MARK: - VPN Settings

    @Published var dnsOption: DNSOption {
        didSet { UserDefaults.standard.set(dnsOption.rawValue, forKey: "dns_option") }
    }

    @Published var customDNS: String {
        didSet { UserDefaults.standard.set(customDNS, forKey: "custom_dns") }
    }

    @Published var wireGuardPort: WireGuardPort {
        didSet { UserDefaults.standard.set(wireGuardPort.rawValue, forKey: "wireguard_port") }
    }

    @Published var mtu: Int {
        didSet { UserDefaults.standard.set(mtu, forKey: "mtu_value") }
    }

    // MARK: - Device Management

    @Published private(set) var devices: [Device] = []
    @Published private(set) var isLoadingDevices: Bool = false
    @Published private(set) var deviceError: String?
    @Published private(set) var isDeviceErrorSessionExpired: Bool = false
    @Published private(set) var accountExpiry: Date?

    // MARK: - Dependencies

    private let provider: VPNProvider
    private let accountViewModel: AccountViewModel

    // MARK: - Initialization

    init(provider: VPNProvider = MullvadAPIClient(), accountViewModel: AccountViewModel) {
        self.provider = provider
        self.accountViewModel = accountViewModel

        // Load persisted settings
        let dnsRaw = UserDefaults.standard.string(forKey: "dns_option") ?? DNSOption.mullvad.rawValue
        self.dnsOption = DNSOption(rawValue: dnsRaw) ?? .mullvad

        self.customDNS = UserDefaults.standard.string(forKey: "custom_dns") ?? ""

        let portRaw = UserDefaults.standard.integer(forKey: "wireguard_port")
        self.wireGuardPort = WireGuardPort(rawValue: portRaw) ?? .automatic

        self.launchAtLogin = SMAppService.mainApp.status == .enabled
        self.autoConnect = UserDefaults.standard.bool(forKey: "auto_connect")

        let displayRaw = UserDefaults.standard.string(forKey: "menu_bar_display")
            ?? MenuBarDisplayMode.iconOnly.rawValue
        self.menuBarDisplay = MenuBarDisplayMode(rawValue: displayRaw) ?? .iconOnly
        self.coloredMenuBarIcon = UserDefaults.standard.bool(forKey: "colored_menu_bar_icon")

        if UserDefaults.standard.object(forKey: "show_connection_notifications") == nil {
            self.showConnectionNotifications = true
        } else {
            self.showConnectionNotifications = UserDefaults.standard.bool(forKey: "show_connection_notifications")
        }

        let savedMTU = UserDefaults.standard.integer(forKey: "mtu_value")
        self.mtu = savedMTU > 0 ? savedMTU : TunnelDefaults.mtu
    }

    // MARK: - Public API

    /// The DNS server address to use for tunnel connections.
    var effectiveDNS: String {
        switch dnsOption {
            case .mullvad:
                return TunnelDefaults.dns
            case .custom:
                return customDNS.isEmpty ? TunnelDefaults.dns : customDNS
        }
    }

    /// The port number to use for WireGuard connections.
    var effectivePort: Int {
        wireGuardPort.portNumber
    }

    /// The MTU value to use for tunnel connections.
    var effectiveMTU: Int { mtu }

    func loadDevices() async {
        guard let token = accountViewModel.credential?.accessToken else { return }

        isLoadingDevices = true
        deviceError = nil
        isDeviceErrorSessionExpired = false

        do {
            async let devicesFetch = provider.listDevices(token: token)
            async let expiryFetch = provider.fetchAccountExpiry(token: token)
            devices = try await devicesFetch
            accountExpiry = try? await expiryFetch
        } catch {
            deviceError = error.localizedDescription
            if case VPNProviderError.unauthorized = error {
                isDeviceErrorSessionExpired = true
            }
        }

        isLoadingDevices = false
    }

    func removeDevice(_ device: Device) async {
        guard let token = accountViewModel.credential?.accessToken else { return }

        do {
            try await provider.removeDevice(token: token, deviceID: device.id)
            devices.removeAll { $0.id == device.id }
        } catch {
            deviceError = error.localizedDescription
        }
    }

    // MARK: - Private

    private func updateLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Revert on failure
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

// MARK: - Settings Types

enum DNSOption: String, CaseIterable, Identifiable {
    case mullvad
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
            case .mullvad: return String(localized: "Mullvad DNS (10.64.0.1)")
            case .custom: return String(localized: "Custom")
        }
    }
}

enum MenuBarDisplayMode: String, CaseIterable, Identifiable {
    case iconOnly = "icon_only"
    case iconAndTime = "icon_and_time"
    case iconAndLocation = "icon_and_location"
    case iconAndBoth = "icon_and_both"

    var id: String { rawValue }

    var displayName: String {
        switch self {
            case .iconOnly: return String(localized: "Icon only")
            case .iconAndTime: return String(localized: "Icon + connected time")
            case .iconAndLocation: return String(localized: "Icon + server location")
            case .iconAndBoth: return String(localized: "Icon + location & time")
        }
    }
}

enum WireGuardPort: Int, CaseIterable, Identifiable {
    case automatic = 0
    case port51820 = 51820
    case port53 = 53

    var id: Int { rawValue }

    var displayName: String {
        switch self {
            case .automatic: return String(localized: "Automatic")
            case .port51820: return "51820"
            case .port53: return "53"
        }
    }

    var portNumber: Int {
        switch self {
            case .automatic: return TunnelDefaults.port
            case .port51820: return TunnelDefaults.port
            case .port53: return 53
        }
    }
}
