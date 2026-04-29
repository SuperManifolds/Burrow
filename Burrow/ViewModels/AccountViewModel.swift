import Combine
import Foundation
import OSLog

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

    let provider: VPNProvider
    private let keychain: KeychainStoring

    // MARK: - Initialization

    init(
        provider: VPNProvider = MullvadAPIClient(),
        keychain: KeychainStoring = KeychainService()
    ) {
        self.provider = provider
        self.keychain = keychain
        loadSavedSession()
    }

    // MARK: - Public API

    /// Log in with the provider's account credentials.
    func login() async {
        let cleaned = accountNumber.replacingOccurrences(of: " ", with: "")
        guard provider.validateAccountInput(cleaned) else {
            error = String(localized: "Invalid account input. Please check and try again.")
            return
        }

        isLoading = true
        error = nil
        isDeviceLimitError = false
        loginStep = .authenticating
        Log.account.info("Starting login for account \(cleaned.prefix(4))****")

        do {
            // Authenticate
            Log.account.info("Authenticating...")
            let cred = try await provider.authenticate(accountNumber: cleaned)
            credential = cred
            Log.account.info("Authenticated, token expires \(cred.expiry)")

            // Save account number and token
            try keychain.save(Data(cleaned.utf8), forKey: KeychainService.Key.accountNumber)
            try keychain.save(Data(cred.accessToken.utf8), forKey: KeychainService.Key.accessToken)

            // Generate keypair
            loginStep = .generatingKeys
            Log.account.info("Generating keypair...")
            let keyPair = KeyPairGenerator.generateKeyPair()
            try keychain.save(keyPair.privateKey, forKey: KeychainService.Key.privateKey)
            Log.account.info("Keypair generated, public key: \(keyPair.publicKeyBase64.prefix(8))...")

            // Register device
            loginStep = .registeringDevice
            Log.account.info("Registering device...")
            let dev = try await provider.registerDevice(
                token: cred.accessToken,
                publicKey: keyPair.publicKeyBase64
            )
            device = dev
            Log.account.info("Device registered: \(dev.name) (\(dev.id))")

            // Save device info
            let deviceData = try JSONEncoder().encode(dev)
            try keychain.save(deviceData, forKey: KeychainService.Key.deviceInfo)

            // Brief pause on "Ready!" before transitioning
            loginStep = .ready
            Log.account.info("Ready!")
            try? await Task.sleep(for: .seconds(1))

            isLoggedIn = true
        } catch let providerError as VPNProviderError {
            Log.account.error("Provider error: \(providerError.errorDescription ?? "unknown")")
            loginStep = .idle
            error = providerError.errorDescription
            if case .deviceLimitReached = providerError {
                isDeviceLimitError = true
            }
        } catch {
            Log.account.error("Error: \(error)")
            loginStep = .idle
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// Log out, unregister the device, and clear all stored credentials.
    func logout() {
        if let token = credential?.accessToken, let deviceID = device?.id {
            Task {
                do {
                    try await provider.removeDevice(token: token, deviceID: deviceID)
                    Log.account.info("Device \(deviceID) removed")
                } catch {
                    Log.account.error("Failed to remove device: \(error)")
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
