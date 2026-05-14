//
//  OnePasswordWriterTests.swift
//  KeychainTo1PasswordTests
//
//  Tests for KeychainItem model properties: URL construction, WiFi detection,
//  field preservation, and OPVault/OPItem models.
//
//  Created by Jordan Koch on 5/14/26.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import KeychainTo1Password

final class OnePasswordWriterTests: XCTestCase {

    // MARK: - Internet Password URL Construction

    func testInternetPasswordURLConstruction() {
        let item = makeKeychainItem(
            type: .internetPassword,
            server: "secure.example.com",
            port: 8443,
            protocol: "https",
            path: "/api/auth"
        )
        XCTAssertEqual(item.url, "https://secure.example.com:8443/api/auth")
    }

    func testInternetPasswordURL_DefaultsToHTTPS_WhenNoProtocol() {
        let item = makeKeychainItem(type: .internetPassword, server: "example.com", protocol: nil)
        XCTAssertEqual(item.url, "https://example.com")
    }

    func testInternetPasswordURL_OmitsPort80() {
        let item = makeKeychainItem(type: .internetPassword, server: "example.com", port: 80, protocol: "http")
        XCTAssertEqual(item.url, "http://example.com")
    }

    func testInternetPasswordURL_OmitsPort443() {
        let item = makeKeychainItem(type: .internetPassword, server: "example.com", port: 443, protocol: "https")
        XCTAssertEqual(item.url, "https://example.com")
    }

    func testInternetPasswordURL_IncludesNonStandardPort() {
        let item = makeKeychainItem(type: .internetPassword, server: "example.com", port: 9090, protocol: "https")
        XCTAssertEqual(item.url, "https://example.com:9090")
    }

    func testInternetPasswordURL_NilServerReturnsNilURL() {
        let item = makeKeychainItem(type: .internetPassword, server: nil)
        XCTAssertNil(item.url)
    }

    func testInternetPasswordURL_EmptyServerReturnsNilURL() {
        let item = makeKeychainItem(type: .internetPassword, server: "")
        XCTAssertNil(item.url)
    }

    // MARK: - Generic Password

    func testGenericPasswordURL_IsAlwaysNil() {
        let item = makeKeychainItem(type: .genericPassword, server: "some.server.com")
        XCTAssertNil(item.url)
    }

    // MARK: - WiFi Password

    func testWiFiPasswordUsesSSIDAsTitle() {
        let item = makeKeychainItem(
            type: .genericPassword,
            label: "OfficeWiFi",
            account: "OfficeWiFi",
            service: "com.apple.network.wlan.ssid.OfficeWiFi"
        )
        XCTAssertTrue(item.isWiFiPassword)
        XCTAssertEqual(item.wifiSSID, "OfficeWiFi")
    }

    // MARK: - Certificate Data

    func testCertificateBase64Encoding() {
        let certData = Data([0x30, 0x82, 0x01, 0x22])
        let item = makeKeychainItem(type: .certificate, data: certData)
        XCTAssertNotNil(item.data)
        XCTAssertFalse(item.data!.base64EncodedString().isEmpty)
    }

    // MARK: - Special Characters Preserved

    func testSpecialCharactersPreserved() {
        let passwords = [
            "p@$$w0rd!#%^&*()",
            "<script>alert('xss')</script>",
            "\"quoted\" 'single' `backtick`",
            String(repeating: "a", count: 1000),
        ]

        for password in passwords {
            guard let data = password.data(using: .utf8) else { continue }
            let item = makeKeychainItem(type: .genericPassword, data: data)
            XCTAssertEqual(item.passwordString, password)
        }
    }

    func testNonUTF8DataReturnsNilPassword() {
        let invalidUTF8 = Data([0xFE, 0xFF, 0x80, 0x81])
        let item = makeKeychainItem(type: .genericPassword, data: invalidUTF8)
        XCTAssertNil(item.passwordString)
    }

    // MARK: - OPVault Model

    func testOPVaultIdentity() {
        let vault1 = OPVault(id: "vault-001", name: "Personal")
        let vault2 = OPVault(id: "vault-002", name: "Work")
        let vault1Copy = OPVault(id: "vault-001", name: "Personal")

        XCTAssertNotEqual(vault1, vault2)
        XCTAssertEqual(vault1, vault1Copy)
    }

    // MARK: - OPItem Model

    func testOPItemIsImportable() {
        let importable = OPItem(id: "1", title: "Test", category: "login", vaultId: "v1",
                                url: nil, username: "u", password: "p", notes: nil,
                                createdAt: nil, updatedAt: nil)
        XCTAssertTrue(importable.isImportable)

        let notImportable = OPItem(id: "2", title: "Note", category: "secure note", vaultId: "v1",
                                   url: nil, username: nil, password: nil, notes: "text",
                                   createdAt: nil, updatedAt: nil)
        XCTAssertFalse(notImportable.isImportable)

        let emptyPassword = OPItem(id: "3", title: "Empty", category: "login", vaultId: "v1",
                                   url: nil, username: "u", password: "", notes: nil,
                                   createdAt: nil, updatedAt: nil)
        XCTAssertFalse(emptyPassword.isImportable)
    }

    func testOPItemCategoryIcon() {
        XCTAssertEqual(OPItem(id: "", title: "", category: "Login", vaultId: "", url: nil, username: nil, password: nil, notes: nil, createdAt: nil, updatedAt: nil).categoryIcon, "globe")
        XCTAssertEqual(OPItem(id: "", title: "", category: "Password", vaultId: "", url: nil, username: nil, password: nil, notes: nil, createdAt: nil, updatedAt: nil).categoryIcon, "key.fill")
        XCTAssertEqual(OPItem(id: "", title: "", category: "Secure Note", vaultId: "", url: nil, username: nil, password: nil, notes: nil, createdAt: nil, updatedAt: nil).categoryIcon, "note.text")
    }

    // MARK: - Helpers

    private func makeKeychainItem(
        type: KeychainItemType = .genericPassword,
        label: String = "Test Item",
        account: String? = "testuser",
        service: String? = nil,
        server: String? = nil,
        port: Int? = nil,
        protocol proto: String? = nil,
        path: String? = nil,
        data: Data? = "password123".data(using: .utf8),
        creationDate: Date? = Date(),
        modificationDate: Date? = Date(),
        keychainSource: String = "Login"
    ) -> KeychainItem {
        KeychainItem(
            type: type, label: label, account: account, service: service,
            server: server, port: port, protocol: proto, path: path,
            data: data, creationDate: creationDate, modificationDate: modificationDate,
            keychainSource: keychainSource
        )
    }
}
