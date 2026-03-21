import CryptoKit
import Foundation

public final class LocalFieldCipher: @unchecked Sendable {
    private let keychain: KeychainHelper

    public init(keychain: KeychainHelper = .shared) {
        self.keychain = keychain
    }

    public func encrypt(_ value: String?) throws -> String? {
        guard let value, !value.isEmpty else { return value }
        let key = try loadOrCreateKey()
        let sealed = try AES.GCM.seal(Data(value.utf8), using: key)
        guard let combined = sealed.combined else {
            throw NSError(domain: "AmonKit.LocalFieldCipher", code: -1)
        }
        return combined.base64EncodedString()
    }

    public func decrypt(_ value: String?) throws -> String? {
        guard let value, !value.isEmpty else { return value }
        guard let combined = Data(base64Encoded: value) else { return value }
        let key = try loadOrCreateKey()
        let sealed = try AES.GCM.SealedBox(combined: combined)
        let decrypted = try AES.GCM.open(sealed, using: key)
        return String(data: decrypted, encoding: .utf8)
    }

    private func loadOrCreateKey() throws -> SymmetricKey {
        if let existing = try keychain.readLocalEncryptionKey() {
            return SymmetricKey(data: existing)
        }
        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }
        try keychain.saveLocalEncryptionKey(data)
        return key
    }
}
