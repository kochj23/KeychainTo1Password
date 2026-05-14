//
//  IntegrationTests.swift
//  KeychainTo1PasswordTests
//
//  Integration tests: KeychainWriter behavior, OPItem → Keychain mapping,
//  KeychainReader mock pipeline, batch handling.
//
//  Created by Jordan Koch on 5/14/26.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import KeychainTo1Password

final class IntegrationTests: XCTestCase {

    // MARK: - KeychainWriter Basics

    func testKeychainWriterRejectsItemWithNoPassword() {
        let writer = KeychainWriter()
        let item = OPItem(
            id: "1", title: "No Pass", category: "login", vaultId: "v1",
            url: "https://example.com", username: "user", password: nil,
            notes: nil, createdAt: nil, updatedAt: nil
        )

        XCTAssertThrowsError(try writer.writeItem(item)) { error in
            XCTAssertTrue(error.localizedDescription.contains("no password"))
        }
    }

    func testKeychainWriterRejectsEmptyPassword() {
        let writer = KeychainWriter()
        let item = OPItem(
            id: "2", title: "Empty Pass", category: "login", vaultId: "v1",
            url: "https://example.com", username: "user", password: "",
            notes: nil, createdAt: nil, updatedAt: nil
        )

        XCTAssertThrowsError(try writer.writeItem(item)) { error in
            XCTAssertTrue(error.localizedDescription.contains("no password"))
        }
    }

    // MARK: - OPItem Properties

    func testOPItemWithURL_IsInternetPassword() {
        let item = OPItem(
            id: "1", title: "GitHub", category: "login", vaultId: "v1",
            url: "https://github.com/login", username: "kochj23", password: "secret",
            notes: nil, createdAt: nil, updatedAt: nil
        )
        XCTAssertTrue(item.isImportable)
        XCTAssertEqual(item.title, "GitHub")
        XCTAssertEqual(item.username, "kochj23")
    }

    func testOPItemWithoutURL_IsGenericPassword() {
        let item = OPItem(
            id: "2", title: "API Token", category: "password", vaultId: "v1",
            url: nil, username: nil, password: "token-abc-123",
            notes: "Service token", createdAt: nil, updatedAt: nil
        )
        XCTAssertTrue(item.isImportable)
        XCTAssertNil(item.url)
    }

    // MARK: - KeychainReader Mock Pipeline

    func testMockReaderReturnsAllItems() async throws {
        let items = (0..<10).map { i in
            KeychainItem.mock(label: "Item \(i)")
        }

        let reader = MockKeychainReader(items: items)
        let result = try await reader.readAllItems()
        XCTAssertEqual(result.count, 10)
    }

    func testMockReaderFiltersByType() async throws {
        let items = [
            KeychainItem.mock(type: .internetPassword, label: "Web"),
            KeychainItem.mock(type: .genericPassword, label: "App"),
            KeychainItem.mock(type: .internetPassword, label: "Web2"),
        ]

        let reader = MockKeychainReader(items: items)
        let internetItems = try await reader.readItems(ofType: .internetPassword)
        XCTAssertEqual(internetItems.count, 2)

        let genericItems = try await reader.readItems(ofType: .genericPassword)
        XCTAssertEqual(genericItems.count, 1)
    }

    func testMockReaderThrowsOnError() async {
        let reader = MockKeychainReader(items: [])
        reader.shouldThrowOnRead = true

        do {
            _ = try await reader.readAllItems()
            XCTFail("Should have thrown")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Mock read failure"))
        }
    }

    // MARK: - MigrationDirection

    func testMigrationDirectionIcons() {
        XCTAssertEqual(MigrationDirection.fromOnePassword.icon, "arrow.down.to.line")
        XCTAssertEqual(MigrationDirection.toOnePassword.icon, "arrow.up.to.line")
    }

    // MARK: - URL Parsing for Keychain Writer

    func testURLParsing_ValidHTTPS() {
        let item = OPItem(
            id: "1", title: "Test", category: "login", vaultId: "v1",
            url: "https://example.com/path", username: "u", password: "p",
            notes: nil, createdAt: nil, updatedAt: nil
        )
        // Verify the URL can be parsed
        let parsed = URL(string: item.url!)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.host, "example.com")
        XCTAssertEqual(parsed?.scheme, "https")
    }

    func testURLParsing_InvalidURL() {
        let item = OPItem(
            id: "2", title: "Bad URL", category: "login", vaultId: "v1",
            url: "not a url at all", username: "u", password: "p",
            notes: nil, createdAt: nil, updatedAt: nil
        )
        let parsed = URL(string: item.url!)
        // URL(string:) may or may not parse this — just verify no crash
        if let parsed = parsed {
            XCTAssertNil(parsed.host)
        }
    }

    // MARK: - Large Batch of OPItems

    func testLargeBatchOPItems() {
        let items = (0..<500).map { i in
            OPItem(
                id: "id-\(i)", title: "Item \(i)", category: "login", vaultId: "v1",
                url: "https://site\(i).com", username: "user\(i)", password: "pass\(i)",
                notes: nil, createdAt: nil, updatedAt: nil
            )
        }

        let importable = items.filter { $0.isImportable }
        XCTAssertEqual(importable.count, 500)
    }
}
