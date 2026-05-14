//
//  KeychainReader.swift
//  KeychainTo1Password
//
//  Reads ALL items from ALL macOS keychains using the Security framework.
//
//  Created by Jordan Koch on 5/14/26.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Security

/// Reads items from all available macOS keychains
final class KeychainReader: @unchecked Sendable {

    /// Errors specific to Keychain reading
    enum ReaderError: LocalizedError {
        case queryFailed(OSStatus)
        case noItemsFound
        case accessDenied

        var errorDescription: String? {
            switch self {
            case .queryFailed(let status):
                return "Keychain query failed with status: \(status) (\(SecCopyErrorMessageString(status, nil) as String? ?? "Unknown"))"
            case .noItemsFound:
                return "No items found in keychain"
            case .accessDenied:
                return "Access denied — ensure the app has full keychain access"
            }
        }
    }

    // MARK: - Public API

    /// Reads all items from all keychains
    /// - Returns: Array of KeychainItem from all classes and all keychains
    func readAllItems() async throws -> [KeychainItem] {
        var allItems: [KeychainItem] = []

        for itemType in KeychainItemType.allCases {
            let items = try await readItems(ofType: itemType)
            allItems.append(contentsOf: items)
        }

        return allItems
    }

    /// Reads items of a specific class from all keychains
    /// - Parameter type: The KeychainItemType to query
    /// - Returns: Array of KeychainItem for that class
    func readItems(ofType type: KeychainItemType) async throws -> [KeychainItem] {
        let query = buildQuery(for: type)

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let items = result as? [[String: Any]] else {
                return []
            }
            return items.compactMap { dict in
                parseItem(from: dict, type: type)
            }

        case errSecItemNotFound:
            // No items of this type — not an error
            return []

        case errSecAuthFailed, errSecInteractionNotAllowed:
            throw ReaderError.accessDenied

        default:
            throw ReaderError.queryFailed(status)
        }
    }

    // MARK: - Private

    private func buildQuery(for type: KeychainItemType) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: type.secClass,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
            kSecReturnRef as String: true
        ]

        // Search all keychains (not just default)
        if let searchList = getKeychainSearchList() {
            query[kSecMatchSearchList as String] = searchList
        }

        return query
    }

    /// Attempts to get the full keychain search list.
    /// SecKeychainCopySearchList is deprecated but still functional — no replacement exists
    /// for enumerating all keychains. We suppress the warning intentionally.
    @available(macOS, deprecated: 10.10, message: "No replacement for keychain enumeration")
    private func getKeychainSearchList() -> [SecKeychain]? {
        var searchList: CFArray?
        let status = Security.SecKeychainCopySearchList(&searchList)
        guard status == errSecSuccess, let list = searchList as? [SecKeychain] else {
            return nil
        }
        return list
    }

    private func parseItem(from dict: [String: Any], type: KeychainItemType) -> KeychainItem? {
        let label = dict[kSecAttrLabel as String] as? String ?? ""
        let account = dict[kSecAttrAccount as String] as? String
        let service = dict[kSecAttrService as String] as? String
        let server = dict[kSecAttrServer as String] as? String
        let port = dict[kSecAttrPort as String] as? Int
        let path = dict[kSecAttrPath as String] as? String
        let creationDate = dict[kSecAttrCreationDate as String] as? Date
        let modificationDate = dict[kSecAttrModificationDate as String] as? Date

        // Extract protocol
        let protocolValue = parseProtocol(dict[kSecAttrProtocol as String])

        // Extract secret data
        let data: Data?
        if let valueData = dict[kSecValueData as String] as? Data {
            data = valueData
        } else {
            data = nil
        }

        // Determine keychain source
        let keychainSource = determineKeychainSource(from: dict)

        return KeychainItem(
            type: type,
            label: label,
            account: account,
            service: service,
            server: server,
            port: port,
            protocol: protocolValue,
            path: path,
            data: data,
            creationDate: creationDate,
            modificationDate: modificationDate,
            keychainSource: keychainSource
        )
    }

    private func parseProtocol(_ value: Any?) -> String? {
        guard let protoValue = value else { return nil }

        // SecProtocolType values are FourCharCode integers
        if let number = protoValue as? Int {
            switch number {
            case 1751474532: return "https"  // 'htps'
            case 1752462448: return "http"   // 'http'
            case 1718185072: return "ftp"    // 'ftp '
            case 1718185075: return "ftps"   // 'ftps'
            default: return "https"
            }
        }

        if let str = protoValue as? String {
            return str
        }

        return nil
    }

    private func determineKeychainSource(from dict: [String: Any]) -> String {
        // Try to determine which keychain this came from
        if let accessGroup = dict[kSecAttrAccessGroup as String] as? String {
            if accessGroup.contains("apple") {
                return "iCloud"
            }
            if accessGroup == "com.apple.wifi.known-networks" {
                return "System"
            }
        }

        // Default to Login keychain
        return "Login"
    }
}
