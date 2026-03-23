import Foundation
import Security

public final class KeychainHelper: @unchecked Sendable {
    public static let shared = KeychainHelper(service: "com.amon.app")

    private let service: String

    public init(service: String) {
        self.service = service
    }

    public func saveSessionToken(_ token: String) throws {
        try save(value: Data(token.utf8), account: "session_token")
    }

    public func readSessionToken() throws -> String? {
        guard let data = try read(account: "session_token") else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func deleteSessionToken() throws {
        try delete(account: "session_token")
    }

    public func saveLocalEncryptionKey(_ data: Data) throws {
        try save(value: data, account: "local_store_key")
    }

    public func readLocalEncryptionKey() throws -> Data? {
        try read(account: "local_store_key")
    }

    public func deleteLocalEncryptionKey() throws {
        try delete(account: "local_store_key")
    }

    private func save(value: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = value
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    private func read(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
        return item as? Data
    }

    private func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }
}
