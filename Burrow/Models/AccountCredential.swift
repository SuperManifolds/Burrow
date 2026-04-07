import Foundation

/// Mullvad account credentials including the account number and API access token.
struct AccountCredential: Sendable, Codable, Equatable {
    /// The 16-digit Mullvad account number.
    let accountNumber: String

    /// OAuth-style access token returned by `/auth/v1/token`.
    let accessToken: String

    /// When the access token expires.
    let expiry: Date
}

// MARK: - API Response

/// Raw token response from `POST /auth/v1/token`.
struct AuthTokenResponse: Sendable, Codable {
    let accessToken: String
    let expiry: String
}
