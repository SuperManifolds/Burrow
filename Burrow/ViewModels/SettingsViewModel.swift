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

    // MARK: - Device Management

    @Published private(set) var devices: [Device] = []
    @Published private(set) var isLoadingDevices: Bool = false
    @Published private(set) var deviceError: String?

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
    }

    // MARK: - Public API

    /// The DNS server address to use for tunnel connections.
    var effectiveDNS: String {
        switch dnsOption {
            case .mullvad:
                return "10.64.0.1"
            case .custom:
                return customDNS.isEmpty ? "10.64.0.1" : customDNS
        }
    }

    /// The port number to use for WireGuard connections.
    var effectivePort: Int {
        wireGuardPort.portNumber
    }

    func loadDevices() async {
        guard let token = accountViewModel.credential?.accessToken else { return }

        isLoadingDevices = true
        deviceError = nil

        do {
            devices = try await provider.listDevices(token: token)
        } catch {
            deviceError = error.localizedDescription
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
            case .automatic: return 51820
            case .port51820: return 51820
            case .port53: return 53
        }
    }
}
