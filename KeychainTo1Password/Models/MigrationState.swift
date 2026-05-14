//
//  MigrationState.swift
//  KeychainTo1Password
//
//  Created by Jordan Koch on 5/14/26.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

/// Represents the overall state of the migration process
enum MigrationPhase: Sendable {
    case idle
    case readingKeychain
    case migrating
    case completed
    case failed(String)

    var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }

    var failureMessage: String? {
        if case .failed(let msg) = self { return msg }
        return nil
    }
}

/// Progress tracking for the migration
@Observable
final class MigrationState {
    var phase: MigrationPhase = .idle
    var totalItems: Int = 0
    var processedItems: Int = 0
    var successCount: Int = 0
    var failureCount: Int = 0
    var skippedCount: Int = 0
    var currentItemName: String = ""
    var errors: [MigrationError] = []
    var keychainItems: [KeychainItem] = []

    var progress: Double {
        guard totalItems > 0 else { return 0 }
        return Double(processedItems) / Double(totalItems)
    }

    var isRunning: Bool {
        switch phase {
        case .readingKeychain, .migrating:
            return true
        default:
            return false
        }
    }

    func reset() {
        phase = .idle
        totalItems = 0
        processedItems = 0
        successCount = 0
        failureCount = 0
        skippedCount = 0
        currentItemName = ""
        errors = []
        keychainItems = []
    }
}

/// An individual migration error
struct MigrationError: Identifiable, Sendable {
    let id = UUID()
    let itemName: String
    let message: String
    let timestamp: Date = Date()
}
