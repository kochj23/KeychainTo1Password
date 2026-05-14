//
//  Mocks.swift
//  KeychainTo1PasswordTests
//
//  Mock implementations for testing.
//
//  Created by Jordan Koch on 5/14/26.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
@testable import KeychainTo1Password

// MARK: - Mock Keychain Reader

final class MockKeychainReader: KeychainReading {
    private let items: [KeychainItem]
    var shouldThrowOnRead: Bool = false

    init(items: [KeychainItem]) {
        self.items = items
    }

    func readAllItems() async throws -> [KeychainItem] {
        if shouldThrowOnRead {
            throw MockError.simulatedReadFailure
        }
        return items
    }

    func readItems(ofType type: KeychainItemType) async throws -> [KeychainItem] {
        if shouldThrowOnRead {
            throw MockError.simulatedReadFailure
        }
        return items.filter { $0.type == type }
    }
}

// MARK: - Mock Errors

enum MockError: LocalizedError {
    case simulatedReadFailure
    case simulatedInitFailure
    case simulatedWriteFailure

    var errorDescription: String? {
        switch self {
        case .simulatedReadFailure:
            return "Mock read failure: simulated keychain access error"
        case .simulatedInitFailure:
            return "Mock init failure: simulated 1Password connection error"
        case .simulatedWriteFailure:
            return "Mock write failure: simulated item creation error"
        }
    }
}

// MARK: - Test Helpers

extension KeychainItem {
    static func mock(
        type: KeychainItemType = .internetPassword,
        label: String = "Test Item",
        account: String? = "user@example.com",
        service: String? = nil,
        server: String? = "example.com",
        password: String? = "secret123"
    ) -> KeychainItem {
        KeychainItem(
            type: type,
            label: label,
            account: account,
            service: service,
            server: server,
            port: nil,
            protocol: "https",
            path: nil,
            data: password?.data(using: .utf8),
            creationDate: Date(),
            modificationDate: Date(),
            keychainSource: "Login"
        )
    }
}
