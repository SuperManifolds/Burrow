import AppKit
import Combine
import Sparkle

/// Brings the app to front when Sparkle shows an update dialog,
/// required for menu bar apps without a dock presence.
private class UpdaterDelegate: NSObject, SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        NSApplication.shared.activate()
    }
}

/// Manages Sparkle auto-update checks.
final class UpdaterViewModel: ObservableObject {
    private let delegate = UpdaterDelegate()
    let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: delegate
        )
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    var canCheckForUpdates: Bool {
        updaterController.updater.canCheckForUpdates
    }
}
