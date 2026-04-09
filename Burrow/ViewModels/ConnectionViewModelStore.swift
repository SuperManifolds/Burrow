import Combine
import Foundation

/// Holds a lazily-created ConnectionViewModel so it can be a @StateObject.
@MainActor
final class ConnectionViewModelStore: ObservableObject {
    private var viewModel: ConnectionViewModel?

    func resolve(
        tunnelManager: any TunnelManaging,
        accountViewModel: AccountViewModel
    ) -> ConnectionViewModel {
        if let existing = viewModel { return existing }
        let vm = ConnectionViewModel(
            tunnelManager: tunnelManager,
            accountViewModel: accountViewModel
        )
        viewModel = vm
        return vm
    }
}
