import Combine
import Foundation

/// Manages account authentication, device registration, and credential storage.
@MainActor
final class AccountViewModel: ObservableObject {

    // MARK: - Published State

    enum LoginStep: Equatable {
        case idle
        case authenticating
        case generatingKeys
        case registeringDevice
        case ready
    }

    @Published var accountNumber: String = ""
    @Published private(set) var isLoggedIn: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var loginStep: LoginStep = .idle
    @Published private(set) var error: String?
    @Published private(set) var isDeviceLimitError: Bool = false
    @Published private(set) var credential: AccountCredential?
    @Published private(set) var device: Device?

    // MARK: - Dependencies

    private let apiClient: APIClientProtocol
    private let keychain: KeychainStoring

    // MARK: - Initialization

    init(
        apiClient: APIClientProtocol = MullvadAPIClient(),
        keychain: KeychainStoring = KeychainService()
    ) {
        self.apiClient = apiClient
        self.keychain = keychain
        loadSavedSession()
    }

    // MARK: - Public API

    /// Log in with a 16-digit Mullvad account number.
    func login() async {
        let cleaned = accountNumber.replacingOccurrences(of: " ", with: "")
        guard cleaned.count == 16, cleaned.allSatisfy(\.isNumber) else {
            error = String(localized: "Account number must be 16 digits.")
            return
        }

        isLoading = true
        error = nil
        isDeviceLimitError = false
        loginStep = .authenticating
        print("[Burrow Login] Starting login for account \(cleaned.prefix(4))****")

        do {
            // Authenticate
            print("[Burrow Login] Authenticating...")
            let cred = try await apiClient.authenticate(accountNumber: cleaned)
            credential = cred
            print("[Burrow Login] Authenticated, token expires \(cred.expiry)")

            // Save account number and token
            try keychain.save(Data(cleaned.utf8), forKey: KeychainService.Key.accountNumber)
            try keychain.save(Data(cred.accessToken.utf8), forKey: KeychainService.Key.accessToken)

            // Generate keypair
            loginStep = .generatingKeys
            print("[Burrow Login] Generating keypair...")
            let keyPair = KeyPairGenerator.generateKeyPair()
            try keychain.save(keyPair.privateKey, forKey: KeychainService.Key.privateKey)
            print("[Burrow Login] Keypair generated, public key: \(keyPair.publicKeyBase64.prefix(8))...")

            // Register device
            loginStep = .registeringDevice
            print("[Burrow Login] Registering device...")
            let dev = try await apiClient.registerDevice(
                token: cred.accessToken,
                publicKey: keyPair.publicKeyBase64
            )
            device = dev
            print("[Burrow Login] Device registered: \(dev.name) (\(dev.id))")

            // Save device info
            let deviceData = try JSONEncoder().encode(dev)
            try keychain.save(deviceData, forKey: KeychainService.Key.deviceInfo)

            // Brief pause on "Ready!" before transitioning
            loginStep = .ready
            print("[Burrow Login] Ready!")
            try? await Task.sleep(for: .seconds(1))

            isLoggedIn = true
        } catch let apiError as MullvadAPIError {
            print("[Burrow Login] API error: \(apiError.errorDescription ?? "unknown")")
            loginStep = .idle
            error = apiError.errorDescription
            if case .deviceLimitReached = apiError {
                isDeviceLimitError = true
            }
        } catch {
            print("[Burrow Login] Error: \(error)")
            loginStep = .idle
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// Log out, unregister the device, and clear all stored credentials.
    func logout() {
        // Remove device from Mullvad in the background
        if let token = credential?.accessToken, let deviceID = device?.id {
            Task {
                do {
                    try await apiClient.removeDevice(token: token, deviceID: deviceID)
                    print("[Burrow Logout] Device \(deviceID) removed")
                } catch {
                    print("[Burrow Logout] Failed to remove device: \(error)")
                }
            }
        }

        try? keychain.delete(forKey: KeychainService.Key.accountNumber)
        try? keychain.delete(forKey: KeychainService.Key.accessToken)
        try? keychain.delete(forKey: KeychainService.Key.privateKey)
        try? keychain.delete(forKey: KeychainService.Key.deviceInfo)

        credential = nil
        device = nil
        isLoggedIn = false
        accountNumber = ""
    }

    /// Get the stored private key for tunnel connections.
    func privateKey() -> Data? {
        try? keychain.load(forKey: KeychainService.Key.privateKey)
    }

    // MARK: - Private

    #if DEBUG
    /// Create a view model with a faked logged-in state for SwiftUI previews.
    static func preview(loggedIn: Bool = true, loginStep: LoginStep = .idle) -> AccountViewModel {
        let vm = AccountViewModel()
        vm.isLoggedIn = loggedIn
        vm.loginStep = loginStep
        return vm
    }
    #endif

    private func loadSavedSession() {
        guard let accountData = try? keychain.load(forKey: KeychainService.Key.accountNumber),
              let tokenData = try? keychain.load(forKey: KeychainService.Key.accessToken),
              let deviceData = try? keychain.load(forKey: KeychainService.Key.deviceInfo),
              let savedDevice = try? JSONDecoder().decode(Device.self, from: deviceData) else {
            return
        }

        accountNumber = String(data: accountData, encoding: .utf8) ?? ""
        credential = AccountCredential(
            accountNumber: accountNumber,
            accessToken: String(data: tokenData, encoding: .utf8) ?? "",
            expiry: .distantFuture
        )
        device = savedDevice
        isLoggedIn = true
    }
}
