import AppIntents

// MARK: - Connect

struct ConnectVPN: AppIntent {
    static var title: LocalizedStringResource = "Connect VPN"
    static var description = IntentDescription("Connect to a VPN server.")
    static var openAppWhenRun = false

    @Parameter(title: "Server", optionsProvider: ServerOptionsProvider())
    var server: ServerEntity?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let state = AppState.shared
        guard let connection = state.connectionViewModel,
              let serverList = state.serverListViewModel,
              let account = state.accountViewModel else {
            throw AppIntentError.appNotRunning
        }

        guard account.isLoggedIn else {
            throw AppIntentError.notLoggedIn
        }

        if case .connected = connection.status {
            return .result(dialog: "Already connected.")
        }

        guard connection.status != .connecting else {
            return .result(dialog: "Already connecting.")
        }

        let relay: Relay? = if let server {
            findRelay(for: server, in: serverList)
        } else {
            serverList.bestAvailableRelay
        }

        guard let relay else {
            throw AppIntentError.noServerSelected
        }

        await connection.connect(to: relay)

        if let info = serverList.relayIndex[relay.hostname] {
            let flag = info.countryCode.countryFlag
            return .result(dialog: "Connected to \(flag) \(info.cityName).")
        }
        return .result(dialog: "Connected.")
    }

    private struct ServerOptionsProvider: DynamicOptionsProvider {
        @MainActor
        func results() async throws -> [ServerEntity] {
            guard let serverList = AppState.shared.serverListViewModel else { return [] }
            return serverList.countries.flatMap { country in
                country.cities.map { ServerEntity(city: $0, country: country) }
            }
        }
    }
}

// MARK: - Disconnect

struct DisconnectVPN: AppIntent {
    static var title: LocalizedStringResource = "Disconnect VPN"
    static var description = IntentDescription("Disconnect from the VPN.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let state = AppState.shared
        guard let connection = state.connectionViewModel else {
            throw AppIntentError.appNotRunning
        }

        guard connection.status.isActive else {
            return .result(dialog: "Already disconnected.")
        }

        await connection.disconnect()
        return .result(dialog: "VPN disconnected.")
    }
}

// MARK: - Toggle

struct ToggleVPN: AppIntent {
    static var title: LocalizedStringResource = "Toggle VPN"
    static var description = IntentDescription("Toggle the VPN connection on or off.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let state = AppState.shared
        guard let connection = state.connectionViewModel,
              let serverList = state.serverListViewModel,
              let account = state.accountViewModel else {
            throw AppIntentError.appNotRunning
        }

        guard account.isLoggedIn else {
            throw AppIntentError.notLoggedIn
        }

        guard connection.status != .connecting,
              connection.status != .disconnecting else {
            return .result(dialog: "Please wait, connection state is changing.")
        }

        if connection.status.isActive {
            await connection.disconnect()
            return .result(dialog: "VPN disconnected.")
        }

        let relay = serverList.bestAvailableRelay

        guard let relay else {
            throw AppIntentError.noServerSelected
        }

        await connection.connect(to: relay)
        return .result(dialog: "VPN connected.")
    }
}

// MARK: - Get Status

struct GetVPNStatus: AppIntent {
    static var title: LocalizedStringResource = "Get VPN Status"
    static var description = IntentDescription("Get the current VPN connection status.")
    static var openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let state = AppState.shared
        guard let connection = state.connectionViewModel,
              let serverList = state.serverListViewModel else {
            throw AppIntentError.appNotRunning
        }

        switch connection.status {
            case .disconnected:
                return .result(dialog: "VPN is disconnected.")
            case .connecting:
                return .result(dialog: "VPN is connecting...")
            case .disconnecting:
                return .result(dialog: "VPN is disconnecting...")
            case .connected:
                let duration = connection.formattedDuration
                if let relay = connection.connectedRelay,
                   let info = serverList.relayIndex[relay.hostname] {
                    let flag = info.countryCode.countryFlag
                    return .result(
                        dialog: "Connected to \(flag) \(info.cityName) for \(duration)."
                    )
                }
                return .result(dialog: "Connected for \(duration).")
        }
    }
}

// MARK: - Helpers

private func findRelay(for server: ServerEntity, in serverList: ServerListViewModel) -> Relay? {
    for country in serverList.countries {
        for city in country.cities where city.id == server.id {
            return serverList.selectRelay(in: city)
        }
    }
    return nil
}

enum AppIntentError: Error, CustomLocalizedStringResourceConvertible {
    case appNotRunning
    case notLoggedIn
    case noServerSelected

    var localizedStringResource: LocalizedStringResource {
        switch self {
            case .appNotRunning:
                "Burrow is not running."
            case .notLoggedIn:
                "Please log in to Burrow first."
            case .noServerSelected:
                "No server selected. Choose a server in Burrow first."
        }
    }
}
