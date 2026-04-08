import Foundation

/// Errors returned by the Mullvad API client.
enum MullvadAPIError: LocalizedError, Sendable {
    /// The account number is invalid or not found.
    case invalidAccount

    /// The access token is expired or invalid.
    case unauthorized

    /// The device limit (5) has been reached for this account.
    case deviceLimitReached

    /// A network-level error occurred.
    case networkError(underlying: Error)

    /// The API response could not be decoded.
    case decodingError(underlying: Error)

    /// The server returned an unexpected HTTP status code.
    case unexpectedStatus(code: Int, body: String?)

    var errorDescription: String? {
        switch self {
            case .invalidAccount:
                return String(localized: "Invalid account number. Please check and try again.")
            case .unauthorized:
                return String(localized: "Session expired. Please log in again.")
            case .deviceLimitReached:
                return String(localized: "Device limit reached (maximum 5). Remove an existing device to continue.")
            case .networkError(let error):
                return String(localized: "Network error: \(error.localizedDescription)")
            case .decodingError:
                return String(localized: "Unexpected response from server.")
            case .unexpectedStatus(let code, _):
                return String(localized: "Server returned an unexpected response (HTTP \(code)).")
        }
    }
}
