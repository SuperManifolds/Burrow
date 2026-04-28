import Foundation

/// Shared reference to app-level view models for App Intents access.
/// Populated by BurrowApp on launch. Since Burrow is an always-running
/// menu bar app, intents execute in-process and can safely read these.
@MainActor
final class AppState {
    static let shared = AppState()

    var connectionViewModel: ConnectionViewModel?
    var serverListViewModel: ServerListViewModel?
    var accountViewModel: AccountViewModel?

    private init() {}
}
