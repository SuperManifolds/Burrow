import Foundation

/// Concrete implementation of `APIClientProtocol` for Mullvad's REST API.
final class MullvadAPIClient: APIClientProtocol, Sendable {

    // MARK: - Properties

    // swiftlint:disable:next force_unwrapping
    private let baseURL = URL(string: "https://api.mullvad.net")!
    private let session: URLSession
    private let decoder: JSONDecoder

    // MARK: - Initialization

    nonisolated init(session: URLSession = URLSession(configuration: .default)) {
        self.session = session

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    // MARK: - APIClientProtocol

    func authenticate(accountNumber: String) async throws -> AccountCredential {
        let url = baseURL.appendingPathComponent("auth/v1/token")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["account_number": accountNumber]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MullvadAPIError.networkError(
                underlying: URLError(.badServerResponse)
            )
        }

        switch httpResponse.statusCode {
            case 200:
                let tokenResponse = try decodeResponse(AuthTokenResponse.self, from: data)

                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                // Try with fractional seconds first, then without
                let expiry = isoFormatter.date(from: tokenResponse.expiry) ?? {
                    let fallback = ISO8601DateFormatter()
                    fallback.formatOptions = [.withInternetDateTime]
                    return fallback.date(from: tokenResponse.expiry)
                }()
                guard let expiry else {
                    throw MullvadAPIError.decodingError(
                        underlying: DecodingError.dataCorrupted(
                            .init(codingPath: [], debugDescription: "Invalid expiry date format")
                        )
                    )
                }

                return AccountCredential(
                    accountNumber: accountNumber,
                    accessToken: tokenResponse.accessToken,
                    expiry: expiry
                )
            case 400, 401:
                throw MullvadAPIError.invalidAccount
            default:
                throw MullvadAPIError.unexpectedStatus(
                    code: httpResponse.statusCode,
                    body: String(data: data, encoding: .utf8)
                )
        }
    }

    func registerDevice(token: String, publicKey: String) async throws -> Device {
        let url = baseURL.appendingPathComponent("accounts/v1/devices")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "pubkey": publicKey,
            "hijack_dns": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MullvadAPIError.networkError(
                underlying: URLError(.badServerResponse)
            )
        }

        let bodyString = String(data: data, encoding: .utf8)
        print("[Burrow API] registerDevice response \(httpResponse.statusCode): \(bodyString ?? "nil")")

        switch httpResponse.statusCode {
            case 200, 201:
                return try decodeResponse(Device.self, from: data)
            case 401:
                throw MullvadAPIError.unauthorized
            case 400, 409:
                if bodyString?.contains("MAX_DEVICES_REACHED") == true {
                    throw MullvadAPIError.deviceLimitReached
                }
                throw MullvadAPIError.unexpectedStatus(
                    code: httpResponse.statusCode,
                    body: bodyString
                )
            default:
                throw MullvadAPIError.unexpectedStatus(
                    code: httpResponse.statusCode,
                    body: bodyString
                )
        }
    }

    func fetchRelayList() async throws -> RelayList {
        let url = baseURL.appendingPathComponent("app/v1/relays")
        let request = URLRequest(url: url)

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MullvadAPIError.networkError(
                underlying: URLError(.badServerResponse)
            )
        }

        guard httpResponse.statusCode == 200 else {
            throw MullvadAPIError.unexpectedStatus(
                code: httpResponse.statusCode,
                body: String(data: data, encoding: .utf8)
            )
        }

        return try decodeResponse(RelayList.self, from: data)
    }

    func listDevices(token: String) async throws -> [Device] {
        let url = baseURL.appendingPathComponent("accounts/v1/devices")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MullvadAPIError.networkError(underlying: URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
            case 200:
                return try decodeResponse([Device].self, from: data)
            case 401:
                throw MullvadAPIError.unauthorized
            default:
                throw MullvadAPIError.unexpectedStatus(
                    code: httpResponse.statusCode,
                    body: String(data: data, encoding: .utf8)
                )
        }
    }

    func removeDevice(token: String, deviceID: String) async throws {
        let url = baseURL.appendingPathComponent("accounts/v1/devices/\(deviceID)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await performRequest(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MullvadAPIError.networkError(underlying: URLError(.badServerResponse))
        }

        switch httpResponse.statusCode {
            case 200, 204:
                return
            case 401:
                throw MullvadAPIError.unauthorized
            default:
                throw MullvadAPIError.unexpectedStatus(
                    code: httpResponse.statusCode,
                    body: String(data: data, encoding: .utf8)
                )
        }
    }

    // MARK: - Private Helpers

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw MullvadAPIError.networkError(underlying: error)
        }
    }

    private func decodeResponse<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw MullvadAPIError.decodingError(underlying: error)
        }
    }
}
