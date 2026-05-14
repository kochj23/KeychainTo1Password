//
//  KeychainWriter.swift
//  KeychainTo1Password
//
//  Writes OPItems into the macOS Keychain (Passwords app).
//  Creates internet or generic password entries.
//
//  Created by Jordan Koch on 5/14/26.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Security

final class KeychainWriter {

    enum WriterError: LocalizedError {
        case noPassword
        case addFailed(String, OSStatus)
        case duplicateItem(String)

        var errorDescription: String? {
            switch self {
            case .noPassword:
                return "Item has no password to store"
            case .addFailed(let title, let status):
                let msg = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown"
                return "Failed to add '\(title)': \(msg) (status \(status))"
            case .duplicateItem(let title):
                return "'\(title)' already exists in Keychain"
            }
        }
    }

    func writeItem(_ item: OPItem, overwriteDuplicates: Bool = false) throws {
        guard let password = item.password, !password.isEmpty else {
            throw WriterError.noPassword
        }

        guard let passwordData = password.data(using: .utf8) else {
            throw WriterError.noPassword
        }

        if let url = item.url, !url.isEmpty, let parsed = URL(string: url), let host = parsed.host {
            try writeInternetPassword(item: item, host: host, url: parsed, passwordData: passwordData, overwrite: overwriteDuplicates)
        } else {
            try writeGenericPassword(item: item, passwordData: passwordData, overwrite: overwriteDuplicates)
        }
    }

    private func writeInternetPassword(item: OPItem, host: String, url: URL, passwordData: Data, overwrite: Bool) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: host,
            kSecAttrLabel as String: item.title,
            kSecValueData as String: passwordData
        ]

        if let username = item.username, !username.isEmpty {
            query[kSecAttrAccount as String] = username
        }

        let port = url.port ?? 0
        if port != 0 {
            query[kSecAttrPort as String] = port
        }

        let scheme = url.scheme?.lowercased() ?? "https"
        if scheme == "https" {
            query[kSecAttrProtocol as String] = kSecAttrProtocolHTTPS
        } else if scheme == "http" {
            query[kSecAttrProtocol as String] = kSecAttrProtocolHTTP
        } else if scheme == "ftp" {
            query[kSecAttrProtocol as String] = kSecAttrProtocolFTP
        }

        let path = url.path
        if !path.isEmpty && path != "/" {
            query[kSecAttrPath as String] = path
        }

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            if overwrite {
                try updateInternetPassword(item: item, host: host, passwordData: passwordData)
            } else {
                throw WriterError.duplicateItem(item.title)
            }
        } else if status != errSecSuccess {
            throw WriterError.addFailed(item.title, status)
        }
    }

    private func updateInternetPassword(item: OPItem, host: String, passwordData: Data) throws {
        var searchQuery: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: host
        ]
        if let username = item.username, !username.isEmpty {
            searchQuery[kSecAttrAccount as String] = username
        }

        let updateAttrs: [String: Any] = [
            kSecValueData as String: passwordData,
            kSecAttrLabel as String: item.title
        ]

        let status = SecItemUpdate(searchQuery as CFDictionary, updateAttrs as CFDictionary)
        if status != errSecSuccess {
            throw WriterError.addFailed(item.title, status)
        }
    }

    private func writeGenericPassword(item: OPItem, passwordData: Data, overwrite: Bool) throws {
        let service = "1Password Import: \(item.title)"

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrLabel as String: item.title,
            kSecValueData as String: passwordData
        ]

        if let username = item.username, !username.isEmpty {
            query[kSecAttrAccount as String] = username
        }

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            if overwrite {
                try updateGenericPassword(service: service, item: item, passwordData: passwordData)
            } else {
                throw WriterError.duplicateItem(item.title)
            }
        } else if status != errSecSuccess {
            throw WriterError.addFailed(item.title, status)
        }
    }

    private func updateGenericPassword(service: String, item: OPItem, passwordData: Data) throws {
        var searchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        if let username = item.username, !username.isEmpty {
            searchQuery[kSecAttrAccount as String] = username
        }

        let updateAttrs: [String: Any] = [
            kSecValueData as String: passwordData,
            kSecAttrLabel as String: item.title
        ]

        let status = SecItemUpdate(searchQuery as CFDictionary, updateAttrs as CFDictionary)
        if status != errSecSuccess {
            throw WriterError.addFailed(item.title, status)
        }
    }
}
