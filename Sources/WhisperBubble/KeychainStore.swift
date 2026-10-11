import Foundation
import Security
import LocalAuthentication
import WhisperCore

@MainActor enum KeychainStore {
    private static let cache = CredentialCache()
    private static let service = "local.whisperbubble.api-key"
    private static let account = "openai"
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    static func read() throws -> String? {
        try cache.read(using: readStoredKey)
    }

    static func isSaved() throws -> Bool {
        // Status needs only unencrypted metadata, never the secret. Forbid UI
        // during this check so startup and Settings cannot request key approval.
        var request = query
        let context = LAContext()
        context.interactionNotAllowed = true
        request[kSecUseAuthenticationContext as String] = context
        request[kSecReturnAttributes as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var attributes: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &attributes)
        if status == errSecItemNotFound { return false }
        guard status == errSecSuccess else { throw KeychainError(status) }
        return true
    }

    private static func readStoredKey() throws -> String? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else { throw KeychainError(status) }
        return key
    }

    static func save(_ key: String) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: Data(key.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item.merge(attributes) { _, new in new }
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError(addStatus) }
        } else if status != errSecSuccess { throw KeychainError(status) }
        cache.store(key)
    }

    static func delete() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status) }
        cache.store(nil)
    }

    static func clearCache() { cache.clear() }
}

private struct KeychainError: LocalizedError {
    let status: OSStatus
    init(_ status: OSStatus) { self.status = status }
    var errorDescription: String? { "The macOS Keychain could not be accessed (\(status)). Unlock your login Keychain and try again." }
}
