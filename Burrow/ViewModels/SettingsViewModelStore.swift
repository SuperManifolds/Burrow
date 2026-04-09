import Combine
import Foundation

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
