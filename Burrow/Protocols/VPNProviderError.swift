import Foundation

/// Generic errors from a VPN provider, independent of any specific service.
enum VPNProviderError: LocalizedError {
    /// The account credentials are invalid or not found.
    case invalidCredentials

    /// The access token is expired or invalid.
    case unauthorized

    /// The device limit has been reached for this account.
    case deviceLimitReached(limit: Int)

    /// A network-level error occurred.
    case networkError(underlying: Error)

    /// The API response could not be decoded.
    case decodingError(underlying: Error)

    /// A provider-specific error with a human-readable message.
    case providerError(message: String)

    var errorDescription: String? {
        switch self {
            case .invalidCredentials:
                return String(localized: "Invalid credentials. Please check and try again.")
            case .unauthorized:
                return String(localized: "Session expired. Please log in again.")
            case .deviceLimitReached(let limit):
                return String(localized: "Device limit reached (maximum \(limit)). Remove an existing device to continue.")
            case .networkError(let error):
                return String(localized: "Network error: \(error.localizedDescription)")
            case .decodingError:
                return String(localized: "Unexpected response from server.")
            case .providerError(let message):
                return message
        }
    }
}
