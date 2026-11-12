import Foundation
import Security

enum GitHubCredentialError: LocalizedError {
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .keychain(let status):
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return "Couldn't secure the token in Keychain: \(message)"
            }
            return "Couldn't secure the token in Keychain (error \(status))."
        }
    }
}

/// Tokens never touch disk in the app's JSON state. They live in the user's login Keychain.
enum GitHubCredentialStore {
    private static let service = "studio.intraditional.pilcrow.github"
    /// Tokens saved before the Pilcrow rebrand are migrated forward on first read.
    private static let legacyService = "studio.intraditional.gitflowswift.github"
    private static let account = "personal-access-token"

    static func save(_ token: String) throws {
        delete()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(token.utf8)
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw GitHubCredentialError.keychain(status) }
    }

    static func load() -> String? {
        if let token = load(service: service) { return token }
        guard let legacy = load(service: legacyService) else { return nil }
        // Bring the pre-rebrand credential forward once, then retire the old item.
        try? save(legacy)
        delete(service: legacyService)
        return legacy
    }

    static func delete() {
        delete(service: service)
        delete(service: legacyService)
    }

    // MARK: - Keychain primitives

    private static func load(service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func delete(service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
