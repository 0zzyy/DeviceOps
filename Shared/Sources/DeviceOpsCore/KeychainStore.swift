import Foundation

#if canImport(Security)
import Security
#endif

public protocol SecretStoring {
    func store(token: String, account: String) throws
    func readToken(account: String) throws -> String?
}

public struct KeychainStore: SecretStoring {
    public init() {}

    public func store(token: String, account: String) throws {
        #if canImport(Security)
        let data = token.data(using: .utf8) ?? Data()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            throw DeviceOpsError.unknown("Keychain write failed")
        }
        #else
        throw DeviceOpsError.unknown("Keychain unavailable on this platform")
        #endif
    }

    public func readToken(account: String) throws -> String? {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw DeviceOpsError.unknown("Keychain read failed")
        }
        return String(data: data, encoding: .utf8)
        #else
        return nil
        #endif
    }
}
