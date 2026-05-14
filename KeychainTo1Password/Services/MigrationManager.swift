//
//  MigrationManager.swift
//  KeychainTo1Password
//
//  Orchestrates bidirectional migration:
//    - 1Password → Keychain (import to Passwords app)
//    - Keychain → 1Password (export to 1Password vault)
//
//  Created by Jordan Koch on 5/14/26.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

enum MigrationDirection: String, CaseIterable {
    case fromOnePassword = "1Password → Keychain"
    case toOnePassword = "Keychain → 1Password"

    var icon: String {
        switch self {
        case .fromOnePassword: return "arrow.down.to.line"
        case .toOnePassword: return "arrow.up.to.line"
        }
    }
}

@MainActor
@Observable
final class MigrationManager {

    let state = MigrationState()

    private var cli: OPCLIRunner?
    private var opReader: OnePasswordReader?
    private var opWriter: OnePasswordWriter?
    private let keychainReader = KeychainReader()
    private let keychainWriter = KeychainWriter()

    private(set) var availableVaults: [OPVault] = []
    var selectedVault: OPVault?
    var direction: MigrationDirection = .fromOnePassword

    var isInitialized: Bool = false
    var initError: String?

    // 1Password items for selection
    var opItems: [OPItem] = []
    var selectedOPItems: Set<String> = []
    var isLoadingItems: Bool = false

    // Keychain items for selection
    var keychainItems: [KeychainItem] = []
    var selectedKeychainItems: Set<UUID> = []

    // Options
    var overwriteDuplicates: Bool = false

    // MARK: - Initialization

    func initialize() async {
        do {
            let runner = try OPCLIRunner()
            try await runner.verifyAuth()

            cli = runner
            opReader = OnePasswordReader(cli: runner)
            opWriter = OnePasswordWriter(cli: runner)

            availableVaults = try await opReader!.fetchVaults()
            isInitialized = true
            initError = nil

            if availableVaults.count == 1 {
                selectedVault = availableVaults.first
            }
        } catch {
            initError = error.localizedDescription
            isInitialized = false
        }
    }

    // MARK: - Load Items

    func loadItems() async {
        guard let vault = selectedVault else { return }
        isLoadingItems = true

        switch direction {
        case .fromOnePassword:
            do {
                opItems = try await opReader!.fetchItems(inVault: vault.id)
                selectedOPItems = Set(opItems.filter { $0.isImportable }.map { $0.id })
            } catch {
                state.phase = .failed("Failed to load 1Password items: \(error.localizedDescription)")
            }

        case .toOnePassword:
            do {
                keychainItems = try await keychainReader.readAllItems()
                selectedKeychainItems = Set(keychainItems.map { $0.id })
            } catch {
                state.phase = .failed("Failed to read Keychain: \(error.localizedDescription)")
            }
        }

        isLoadingItems = false
    }

    // MARK: - Select All / None

    func selectAll() {
        switch direction {
        case .fromOnePassword:
            selectedOPItems = Set(opItems.filter { $0.isImportable }.map { $0.id })
        case .toOnePassword:
            selectedKeychainItems = Set(keychainItems.map { $0.id })
        }
    }

    func selectNone() {
        switch direction {
        case .fromOnePassword:
            selectedOPItems.removeAll()
        case .toOnePassword:
            selectedKeychainItems.removeAll()
        }
    }

    var selectedCount: Int {
        switch direction {
        case .fromOnePassword: return selectedOPItems.count
        case .toOnePassword: return selectedKeychainItems.count
        }
    }

    var totalCount: Int {
        switch direction {
        case .fromOnePassword: return opItems.count
        case .toOnePassword: return keychainItems.count
        }
    }

    // MARK: - Migration

    func migrate() async {
        guard let vault = selectedVault else {
            state.phase = .failed("No vault selected")
            return
        }

        state.reset()

        switch direction {
        case .fromOnePassword:
            await migrateFromOnePassword()
        case .toOnePassword:
            await migrateToOnePassword(vaultId: vault.id)
        }
    }

    private func migrateFromOnePassword() async {
        let itemsToMigrate = opItems.filter { selectedOPItems.contains($0.id) }

        if itemsToMigrate.isEmpty {
            state.phase = .failed("No items selected for import")
            return
        }

        state.totalItems = itemsToMigrate.count
        state.phase = .migrating

        for item in itemsToMigrate {
            state.currentItemName = item.title

            do {
                try keychainWriter.writeItem(item, overwriteDuplicates: overwriteDuplicates)
                state.successCount += 1
            } catch let error as KeychainWriter.WriterError {
                if case .duplicateItem = error {
                    state.skippedCount += 1
                } else {
                    state.failureCount += 1
                }
                state.errors.append(MigrationError(
                    itemName: item.title,
                    message: error.localizedDescription
                ))
            } catch {
                state.failureCount += 1
                state.errors.append(MigrationError(
                    itemName: item.title,
                    message: error.localizedDescription
                ))
            }

            state.processedItems += 1
        }

        state.phase = .completed
        state.currentItemName = ""
    }

    private func migrateToOnePassword(vaultId: String) async {
        let itemsToMigrate = keychainItems.filter { selectedKeychainItems.contains($0.id) }

        if itemsToMigrate.isEmpty {
            state.phase = .failed("No items selected for export")
            return
        }

        state.totalItems = itemsToMigrate.count
        state.phase = .migrating

        for item in itemsToMigrate {
            state.currentItemName = item.displayTitle

            do {
                try await opWriter!.createItem(from: item, inVault: vaultId)
                state.successCount += 1
            } catch {
                state.failureCount += 1
                state.errors.append(MigrationError(
                    itemName: item.displayTitle,
                    message: error.localizedDescription
                ))
            }

            state.processedItems += 1
        }

        state.phase = .completed
        state.currentItemName = ""
    }
}
