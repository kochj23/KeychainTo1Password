//
//  OnePasswordReader.swift
//  KeychainTo1Password
//
//  Reads items from 1Password vaults via the `op` CLI and converts them
//  into a form that can be written to macOS Keychain/Passwords.
//
//  Created by Jordan Koch on 5/14/26.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

struct OPItem: Identifiable, Sendable {
    let id: String
    let title: String
    let category: String
    let vaultId: String
    let url: String?
    let username: String?
    let password: String?
    let notes: String?
    let createdAt: Date?
    let updatedAt: Date?

    var categoryIcon: String {
        switch category.lowercased() {
        case "login": return "globe"
        case "password": return "key.fill"
        case "secure note": return "note.text"
        case "credit card": return "creditcard.fill"
        case "identity": return "person.fill"
        case "ssh key": return "terminal.fill"
        case "api credential": return "server.rack"
        default: return "lock.fill"
        }
    }

    var isImportable: Bool {
        password != nil && !password!.isEmpty
    }
}

final class OnePasswordReader: @unchecked Sendable {

    private let cli: OPCLIRunner

    init(cli: OPCLIRunner) {
        self.cli = cli
    }

    func fetchVaults() async throws -> [OPVault] {
        struct VaultDTO: Decodable {
            let id: String
            let name: String
        }
        let vaults: [VaultDTO] = try await cli.runJSON(["vault", "list", "--format=json"], as: [VaultDTO].self)
        return vaults.map { OPVault(id: $0.id, name: $0.name) }
    }

    func fetchItems(inVault vaultId: String) async throws -> [OPItem] {
        struct ItemListDTO: Decodable {
            let id: String
            let title: String
            let category: String
            let vault: VaultRef?
            let urls: [URLEntry]?
            let created_at: String?
            let updated_at: String?

            struct VaultRef: Decodable { let id: String }
            struct URLEntry: Decodable { let href: String }
        }

        let listItems: [ItemListDTO] = try await cli.runJSON(
            ["item", "list", "--vault=\(vaultId)", "--format=json"],
            as: [ItemListDTO].self
        )

        var results: [OPItem] = []

        for listItem in listItems {
            let detail = await fetchItemDetail(id: listItem.id, vaultId: vaultId)
            results.append(OPItem(
                id: listItem.id,
                title: listItem.title,
                category: listItem.category,
                vaultId: vaultId,
                url: detail?.url ?? listItem.urls?.first?.href,
                username: detail?.username,
                password: detail?.password,
                notes: detail?.notes,
                createdAt: ISO8601DateFormatter().date(from: listItem.created_at ?? ""),
                updatedAt: ISO8601DateFormatter().date(from: listItem.updated_at ?? "")
            ))
        }

        return results
    }

    private struct ItemDetail {
        let url: String?
        let username: String?
        let password: String?
        let notes: String?
    }

    private func fetchItemDetail(id: String, vaultId: String) async -> ItemDetail? {
        struct DetailDTO: Decodable {
            let fields: [Field]?
            let urls: [URLEntry]?

            struct Field: Decodable {
                let id: String?
                let label: String?
                let value: String?
                let purpose: String?
            }
            struct URLEntry: Decodable { let href: String }
        }

        guard let detail: DetailDTO = try? await cli.runJSON(
            ["item", "get", id, "--vault=\(vaultId)", "--format=json"],
            as: DetailDTO.self
        ) else {
            return nil
        }

        let fields = detail.fields ?? []
        let username = fields.first(where: { $0.purpose == "USERNAME" || $0.id == "username" })?.value
        let password = fields.first(where: { $0.purpose == "PASSWORD" || $0.id == "password" })?.value
        let notes = fields.first(where: { $0.id == "notesPlain" || $0.label == "notesPlain" })?.value
        let url = detail.urls?.first?.href

        return ItemDetail(url: url, username: username, password: password, notes: notes)
    }
}
