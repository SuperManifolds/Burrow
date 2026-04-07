import CryptoKit
import Foundation

/// Generates WireGuard-compatible Curve25519 keypairs using CryptoKit.
///
/// WireGuard uses Curve25519 for key exchange. The private key is 32 random bytes,
/// and the public key is derived from it. Both are typically base64-encoded for
/// transport and configuration.
enum KeyPairGenerator {

    /// A Curve25519 keypair for WireGuard tunnels.
    struct KeyPair: Sendable {
        /// Raw 32-byte private key.
        let privateKey: Data

        /// Raw 32-byte public key.
        let publicKey: Data

        /// Base64-encoded private key (for WireGuard config).
        var privateKeyBase64: String { privateKey.base64EncodedString() }

        /// Base64-encoded public key (for Mullvad API registration).
        var publicKeyBase64: String { publicKey.base64EncodedString() }
    }

    /// Generate a new Curve25519 keypair.
    /// - Returns: A `KeyPair` with raw private and public key data.
    static func generateKeyPair() -> KeyPair {
        let privateKey = Curve25519.KeyAgreement.PrivateKey()
        return KeyPair(
            privateKey: privateKey.rawRepresentation,
            publicKey: privateKey.publicKey.rawRepresentation
        )
    }

    /// Derive the public key from an existing private key.
    /// - Parameter privateKeyData: Raw 32-byte private key data.
    /// - Returns: Raw 32-byte public key data, or `nil` if the private key is invalid.
    static func publicKey(from privateKeyData: Data) -> Data? {
        guard let privateKey = try? Curve25519.KeyAgreement.PrivateKey(
            rawRepresentation: privateKeyData
        ) else {
            return nil
        }
        return privateKey.publicKey.rawRepresentation
    }
}
