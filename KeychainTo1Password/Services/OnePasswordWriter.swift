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

    private let cli: OPCLIRunner

    init(cli: OPCLIRunner) {
        self.cli = cli
    }

    func createItem(from keychainItem: KeychainItem, inVault vaultId: String) async throws {
        let args = buildCreateArgs(from: keychainItem, vaultId: vaultId)
        let (_, stderr, status) = await cli.run(args)
        guard status == 0 else {
            throw WriterError.itemCreateFailed(keychainItem.displayTitle, stderr)
        }
    }

    private func buildCreateArgs(from item: KeychainItem, vaultId: String) -> [String] {
        switch item.type {
        case .internetPassword:
            return buildLoginArgs(from: item, vaultId: vaultId)
        case .genericPassword:
            if item.isWiFiPassword {
                return buildWiFiArgs(from: item, vaultId: vaultId)
            }
            return buildPasswordArgs(from: item, vaultId: vaultId)
        case .certificate, .key, .identity:
            return buildSecureNoteArgs(from: item, vaultId: vaultId)
        }
    }

    private func buildLoginArgs(from item: KeychainItem, vaultId: String) -> [String] {
        var args = ["item", "create",
                    "--category=login",
                    "--vault=\(vaultId)",
                    "--title=\(item.displayTitle)"]

        if let account = item.account, !account.isEmpty {
            args.append("username=\(account)")
        }
        if let password = item.passwordString {
            args.append("password=\(password)")
        }
        if let url = item.url {
            args.append("--url=\(url)")
        }
        args.append("notesPlain=Migrated from \(item.keychainSource) Keychain")
        return args
    }

    private func buildPasswordArgs(from item: KeychainItem, vaultId: String) -> [String] {
        var args = ["item", "create",
                    "--category=login",
                    "--vault=\(vaultId)",
                    "--title=\(item.displayTitle)"]

        if let account = item.account, !account.isEmpty {
            args.append("username=\(account)")
        }
        if let password = item.passwordString {
            args.append("password=\(password)")
        }
        var notes = "Migrated from \(item.keychainSource) Keychain"
        if let service = item.service {
            notes += "\nService: \(service)"
        }
        args.append("notesPlain=\(notes)")
        return args
    }

    private func buildWiFiArgs(from item: KeychainItem, vaultId: String) -> [String] {
        let title = "WiFi: \(item.wifiSSID ?? item.displayTitle)"
        var args = ["item", "create",
                    "--category=password",
                    "--vault=\(vaultId)",
                    "--title=\(title)"]

        if let password = item.passwordString {
            args.append("password=\(password)")
        }
        args.append("notesPlain=WiFi Network: \(item.wifiSSID ?? "Unknown")\nMigrated from \(item.keychainSource) Keychain")
        return args
    }

    private func buildSecureNoteArgs(from item: KeychainItem, vaultId: String) -> [String] {
        var notes = "Type: \(item.type.rawValue)\n"
        notes += "Keychain: \(item.keychainSource)\n"
        if let account = item.account { notes += "Account: \(account)\n" }
        if let service = item.service { notes += "Service: \(service)\n" }
        if let data = item.data {
            notes += "Data size: \(data.count) bytes\n"
            notes += "Data (Base64): \(data.base64EncodedString())\n"
        }
        return ["item", "create",
                "--category=secure note",
                "--vault=\(vaultId)",
                "--title=\(item.type.rawValue): \(item.displayTitle)",
                "notesPlain=\(notes)"]
    }
}
