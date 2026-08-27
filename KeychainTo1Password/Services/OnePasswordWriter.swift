//
//  OnePasswordWriter.swift
//  KeychainTo1Password
//
//  Writes Keychain items to 1Password via the `op` CLI.
//  Uses 1Password desktop app integration for auth.
//
//  Created by Jordan Koch on 5/14/26.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

final class OnePasswordWriter: @unchecked Sendable {

    enum WriterError: LocalizedError {
        case itemCreateFailed(String, String)

        var errorDescription: String? {
            switch self {
            case .itemCreateFailed(let item, let msg):
                return "Failed to create item '\(item)': \(msg)"
            }
        }
    }

    /// Minimal `op` item-create template. Field *values* (passwords, notes
    /// containing base64 key/cert material) are carried here and piped to the
    /// CLI on stdin, never placed in argv (argv is world-readable via `ps`).
    private struct OPItemTemplate: Encodable {
        struct Field: Encodable {
            let id: String
            let label: String?
            let type: String
            let purpose: String?
            let value: String
        }
        let fields: [Field]

        static func username(_ value: String) -> Field {
            Field(id: "username", label: "username", type: "STRING", purpose: "USERNAME", value: value)
        }
        static func password(_ value: String) -> Field {
            Field(id: "password", label: "password", type: "CONCEALED", purpose: "PASSWORD", value: value)
        }
        static func notes(_ value: String) -> Field {
            Field(id: "notesPlain", label: "notesPlain", type: "STRING", purpose: "NOTES", value: value)
        }
    }

    private let cli: OPCLIRunner

    init(cli: OPCLIRunner) {
        self.cli = cli
    }

    func createItem(from keychainItem: KeychainItem, inVault vaultId: String) async throws {
        let (args, stdin) = buildCreateRequest(from: keychainItem, vaultId: vaultId)
        let (_, stderr, status) = await cli.run(args, stdin: stdin)
        guard status == 0 else {
            throw WriterError.itemCreateFailed(keychainItem.displayTitle, stderr)
        }
    }

    private func buildCreateRequest(from item: KeychainItem, vaultId: String) -> (args: [String], stdin: Data?) {
        switch item.type {
        case .internetPassword:
            return buildLoginRequest(from: item, vaultId: vaultId)
        case .genericPassword:
            if item.isWiFiPassword {
                return buildWiFiRequest(from: item, vaultId: vaultId)
            }
            return buildPasswordRequest(from: item, vaultId: vaultId)
        case .certificate, .key, .identity:
            return buildSecureNoteRequest(from: item, vaultId: vaultId)
        }
    }

    /// Encodes the field template as JSON and appends the stdin sentinel `-`
    /// so `op item create` reads the item body (including all secrets) from
    /// stdin instead of the command line.
    private func finalize(args: [String], fields: [OPItemTemplate.Field]) -> (args: [String], stdin: Data?) {
        var args = args
        let data = try? JSONEncoder().encode(OPItemTemplate(fields: fields))
        args.append("-")
        return (args, data)
    }

    private func buildLoginRequest(from item: KeychainItem, vaultId: String) -> (args: [String], stdin: Data?) {
        var args = ["item", "create",
                    "--category=login",
                    "--vault=\(vaultId)",
                    "--title=\(item.displayTitle)"]

        var fields: [OPItemTemplate.Field] = []
        if let account = item.account, !account.isEmpty {
            fields.append(OPItemTemplate.username(account))
        }
        if let password = item.passwordString {
            fields.append(OPItemTemplate.password(password))
        }
        if let url = item.url {
            args.append("--url=\(url)")
        }
        fields.append(OPItemTemplate.notes("Migrated from \(item.keychainSource) Keychain"))
        return finalize(args: args, fields: fields)
    }

    private func buildPasswordRequest(from item: KeychainItem, vaultId: String) -> (args: [String], stdin: Data?) {
        var args = ["item", "create",
                    "--category=login",
                    "--vault=\(vaultId)",
                    "--title=\(item.displayTitle)"]

        var fields: [OPItemTemplate.Field] = []
        if let account = item.account, !account.isEmpty {
            fields.append(OPItemTemplate.username(account))
        }
        if let password = item.passwordString {
            fields.append(OPItemTemplate.password(password))
        }
        var notes = "Migrated from \(item.keychainSource) Keychain"
        if let service = item.service {
            notes += "\nService: \(service)"
        }
        fields.append(OPItemTemplate.notes(notes))
        return finalize(args: args, fields: fields)
    }

    private func buildWiFiRequest(from item: KeychainItem, vaultId: String) -> (args: [String], stdin: Data?) {
        let title = "WiFi: \(item.wifiSSID ?? item.displayTitle)"
        let args = ["item", "create",
                    "--category=password",
                    "--vault=\(vaultId)",
                    "--title=\(title)"]

        var fields: [OPItemTemplate.Field] = []
        if let password = item.passwordString {
            fields.append(OPItemTemplate.password(password))
        }
        fields.append(OPItemTemplate.notes("WiFi Network: \(item.wifiSSID ?? "Unknown")\nMigrated from \(item.keychainSource) Keychain"))
        return finalize(args: args, fields: fields)
    }

    private func buildSecureNoteRequest(from item: KeychainItem, vaultId: String) -> (args: [String], stdin: Data?) {
        var notes = "Type: \(item.type.rawValue)\n"
        notes += "Keychain: \(item.keychainSource)\n"
        if let account = item.account { notes += "Account: \(account)\n" }
        if let service = item.service { notes += "Service: \(service)\n" }
        if let data = item.data {
            notes += "Data size: \(data.count) bytes\n"
            notes += "Data (Base64): \(data.base64EncodedString())\n"
        }
        let args = ["item", "create",
                    "--category=secure note",
                    "--vault=\(vaultId)",
                    "--title=\(item.type.rawValue): \(item.displayTitle)"]
        return finalize(args: args, fields: [OPItemTemplate.notes(notes)])
    }
}
