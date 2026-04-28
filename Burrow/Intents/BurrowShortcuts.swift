import AppIntents

struct BurrowShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ConnectVPN(),
            phrases: [
                "Connect \(.applicationName)",
                "Connect VPN in \(.applicationName)",
                "Start \(.applicationName)"
            ],
            shortTitle: "Connect VPN",
            systemImageName: "checkmark.shield.fill"
        )
        AppShortcut(
            intent: DisconnectVPN(),
            phrases: [
                "Disconnect \(.applicationName)",
                "Disconnect VPN in \(.applicationName)",
                "Stop \(.applicationName)"
            ],
            shortTitle: "Disconnect VPN",
            systemImageName: "shield.slash"
        )
        AppShortcut(
            intent: ToggleVPN(),
            phrases: [
                "Toggle \(.applicationName)",
                "Toggle VPN in \(.applicationName)"
            ],
            shortTitle: "Toggle VPN",
            systemImageName: "antenna.radiowaves.left.and.right"
        )
        AppShortcut(
            intent: GetVPNStatus(),
            phrases: [
                "VPN status in \(.applicationName)",
                "\(.applicationName) status"
            ],
            shortTitle: "VPN Status",
            systemImageName: "info.circle"
        )
    }
}
