//
//  KeychainManager.swift
//  Secure storage for sensitive credentials using iOS Keychain.
//
//  Provides encrypted storage for API keys, tokens, and backend configurations.
//  Uses Keychain Services API for maximum security on iOS devices.
//

import Foundation
import Security

// MARK: - Keychain Error

enum KeychainError: LocalizedError {
    case itemNotFound
    case duplicateItem
    case invalidData
    case unhandledError(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Item not found in keychain"
        case .duplicateItem:
            return "Item already exists in keychain"
        case .invalidData:
            return "Invalid data format"
        case .unhandledError(let status):
            return "Keychain error: \(status)"
        }
    }
}

// MARK: - Keychain Manager

@MainActor
class KeychainManager {
    static let shared = KeychainManager()

    // Keychain identifiers
    private let serviceIdentifier = "com.visionforge.claudecode"
    private let accessGroup: String? = nil  // Use default access group

    // Known keys for stored items
    enum KeychainKey: String, CaseIterable {
        case apiKey = "claude_api_key"
        case backendURL = "backend_url"
        case backendToken = "backend_auth_token"
        case userId = "user_id"
        case sessionToken = "session_token"
        case activeConfigId = "active_config_id"
    }

    private init() {}

    // MARK: - Generic Storage Methods

    func save(_ data: Data, for key: KeychainKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        // Try to update first
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key.rawValue
        ]

        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        var status = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)

        if status == errSecItemNotFound {
            // Item doesn't exist, add it
            status = SecItemAdd(query as CFDictionary, nil)
        }

        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    func load(key: KeychainKey) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unhandledError(status: status)
        }

        guard let data = result as? Data else {
            throw KeychainError.invalidData
        }

        return data
    }

    func delete(key: KeychainKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    func exists(key: KeychainKey) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceIdentifier,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Convenience Methods for Strings

    func saveString(_ string: String, for key: KeychainKey) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try save(data, for: key)
    }

    func loadString(key: KeychainKey) throws -> String {
        let data = try load(key: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return string
    }

    // MARK: - Convenience Methods for Codable

    func saveCodable<T: Codable>(_ object: T, for key: KeychainKey) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(object)
        try save(data, for: key)
    }

    func loadCodable<T: Codable>(_ type: T.Type, key: KeychainKey) throws -> T {
        let data = try load(key: key)
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }

    // MARK: - Specific Credential Management

    func saveAPIKey(_ apiKey: String) throws {
        try saveString(apiKey, for: .apiKey)
    }

    func loadAPIKey() -> String? {
        try? loadString(key: .apiKey)
    }

    func saveBackendURL(_ url: URL) throws {
        try saveString(url.absoluteString, for: .backendURL)
    }

    func loadBackendURL() -> URL? {
        guard let urlString = try? loadString(key: .backendURL) else {
            return nil
        }
        return URL(string: urlString)
    }

    func saveBackendConfig(_ config: BackendConfig) throws {
        try saveCodable(config, for: .activeConfigId)
    }

    func loadBackendConfig() -> BackendConfig? {
        try? loadCodable(BackendConfig.self, key: .activeConfigId)
    }

    func saveUserId(_ userId: String) throws {
        try saveString(userId, for: .userId)
    }

    func loadUserId() -> String? {
        try? loadString(key: .userId)
    }

    // MARK: - Secure Token Management

    func saveSessionToken(_ token: String) throws {
        try saveString(token, for: .sessionToken)
    }

    func loadSessionToken() -> String? {
        try? loadString(key: .sessionToken)
    }

    func clearSessionToken() {
        try? delete(key: .sessionToken)
    }

    // MARK: - Bulk Operations

    func clearAllCredentials() {
        for key in KeychainKey.allCases {
            try? delete(key: key)
        }
    }

    func hasStoredCredentials() -> Bool {
        // Check if we have the minimum required credentials
        return exists(key: .backendURL) || exists(key: .activeConfigId)
    }

    // MARK: - Migration Support

    func migrateFromUserDefaults() {
        // Migrate any credentials stored in UserDefaults to Keychain
        let userDefaults = UserDefaults.standard

        // Example migration (adjust based on actual UserDefaults keys)
        if let apiKey = userDefaults.string(forKey: "stored_api_key") {
            try? saveAPIKey(apiKey)
            userDefaults.removeObject(forKey: "stored_api_key")
        }

        if let backendURL = userDefaults.string(forKey: "backend_url"),
           let url = URL(string: backendURL) {
            try? saveBackendURL(url)
            userDefaults.removeObject(forKey: "backend_url")
        }

        userDefaults.synchronize()
    }
}

// MARK: - Keychain Wrapper for Backend Configuration

extension BackendConfig {
    // Save this configuration securely
    func saveToKeychain() throws {
        try KeychainManager.shared.saveBackendConfig(self)
    }

    // Load configuration from keychain
    static func loadFromKeychain() -> BackendConfig? {
        return KeychainManager.shared.loadBackendConfig()
    }

    // Check if a configuration exists in keychain
    static var hasStoredConfiguration: Bool {
        return KeychainManager.shared.hasStoredCredentials()
    }
}