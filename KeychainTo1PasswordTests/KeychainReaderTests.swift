//
//  KeychainReaderTests.swift
//  KeychainTo1PasswordTests
//
//  Tests for KeychainReader: item parsing, classification, WiFi detection,
//  date handling, and edge cases with nil/missing fields.
//
//  Created by Jordan Koch on 5/14/26.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import KeychainTo1Password

final class KeychainReaderTests: XCTestCase {

    // MARK: - Constants / Type Sanity

    func testKeychainItemTypeAllCasesAreDefined() {
        let allTypes = KeychainItemType.allCases
        XCTAssertEqual(allTypes.count, 5, "Should have 5 keychain item types")
        XCTAssertTrue(allTypes.contains(.internetPassword))
        XCTAssertTrue(allTypes.contains(.genericPassword))
        XCTAssertTrue(allTypes.contains(.certificate))
        XCTAssertTrue(allTypes.contains(.key))
        XCTAssertTrue(allTypes.contains(.identity))
    }

    func testKeychainItemTypeSecClassValues() {
        // Verify the SecClass constants map correctly
        XCTAssertEqual(KeychainItemType.internetPassword.secClass, kSecClassInternetPassword)
        XCTAssertEqual(KeychainItemType.genericPassword.secClass, kSecClassGenericPassword)
        XCTAssertEqual(KeychainItemType.certificate.secClass, kSecClassCertificate)
        XCTAssertEqual(KeychainItemType.key.secClass, kSecClassKey)
        XCTAssertEqual(KeychainItemType.identity.secClass, kSecClassIdentity)
    }

    func testKeychainItemTypeRawValues() {
        XCTAssertEqual(KeychainItemType.internetPassword.rawValue, "Internet Password")
        XCTAssertEqual(KeychainItemType.genericPassword.rawValue, "Generic Password")
        XCTAssertEqual(KeychainItemType.certificate.rawValue, "Certificate")
        XCTAssertEqual(KeychainItemType.key.rawValue, "Key")
        XCTAssertEqual(KeychainItemType.identity.rawValue, "Identity")
    }

    func testKeychainItemTypeIcons() {
        XCTAssertEqual(KeychainItemType.internetPassword.icon, "globe")
        XCTAssertEqual(KeychainItemType.genericPassword.icon, "key.fill")
        XCTAssertEqual(KeychainItemType.certificate.icon, "doc.badge.gearshape")
        XCTAssertEqual(KeychainItemType.key.icon, "lock.fill")
        XCTAssertEqual(KeychainItemType.identity.icon, "person.badge.key.fill")
    }

    // MARK: - Item Parsing from Mock Dictionaries

    func testParseBasicInternetPasswordItem() {
        let item = makeKeychainItem(
            type: .internetPassword,
            label: "example.com",
            account: "user@example.com",
            server: "example.com",
            port: 443,
            protocol: "https",
            path: "/login",
            data: "s3cret!".data(using: .utf8)
        )

        XCTAssertEqual(item.type, .internetPassword)
        XCTAssertEqual(item.label, "example.com")
        XCTAssertEqual(item.account, "user@example.com")
        XCTAssertEqual(item.server, "example.com")
        XCTAssertEqual(item.port, 443)
        XCTAssertEqual(item.protocol, "https")
        XCTAssertEqual(item.path, "/login")
        XCTAssertEqual(item.passwordString, "s3cret!")
    }

    func testParseGenericPasswordItem() {
        let item = makeKeychainItem(
            type: .genericPassword,
            label: "App Token",
            account: "admin",
            service: "com.myapp.token"
        )

        XCTAssertEqual(item.type, .genericPassword)
        XCTAssertEqual(item.displayTitle, "App Token")
        XCTAssertEqual(item.service, "com.myapp.token")
    }

    // MARK: - Handling Empty Keychain Results

    func testEmptyKeychainReturnsEmptyArray() async throws {
        let mockReader = MockKeychainReader(items: [])
        let items = try await mockReader.readAllItems()
        XCTAssertTrue(items.isEmpty)
    }

    func testEmptyKeychainForSpecificType() async throws {
        let mockReader = MockKeychainReader(items: [])
        let items = try await mockReader.readItems(ofType: .certificate)
        XCTAssertTrue(items.isEmpty)
    }

    // MARK: - Handling Nil/Missing Fields

    func testItemWithAllNilOptionalFields() {
        let item = KeychainItem(
            type: .genericPassword,
            label: "",
            account: nil,
            service: nil,
            server: nil,
            port: nil,
            protocol: nil,
            path: nil,
            data: nil,
            creationDate: nil,
            modificationDate: nil,
            keychainSource: "Login"
        )

        XCTAssertEqual(item.displayTitle, "Untitled Item")
        XCTAssertNil(item.passwordString)
        XCTAssertNil(item.url)
        XCTAssertNil(item.wifiSSID)
        XCTAssertFalse(item.isWiFiPassword)
    }

    func testItemWithEmptyLabel_FallsBackToService() {
        let item = makeKeychainItem(
            type: .genericPassword,
            label: "",
            service: "com.apple.mail"
        )

        XCTAssertEqual(item.displayTitle, "com.apple.mail")
    }

    func testItemWithEmptyLabelAndService_FallsBackToServer() {
        let item = makeKeychainItem(
            type: .internetPassword,
            label: "",
            service: nil,
            server: "api.github.com"
        )

        XCTAssertEqual(item.displayTitle, "api.github.com")
    }

    func testItemWithEmptyLabelServiceServer_ShowsUntitled() {
        let item = makeKeychainItem(
            type: .genericPassword,
            label: "",
            service: "",
            server: ""
        )

        XCTAssertEqual(item.displayTitle, "Untitled Item")
    }

    func testNilDataReturnsNilPassword() {
        let item = makeKeychainItem(type: .genericPassword, data: nil)
        XCTAssertNil(item.passwordString)
    }

    func testEmptyDataReturnsEmptyPassword() {
        let item = makeKeychainItem(type: .genericPassword, data: Data())
        XCTAssertEqual(item.passwordString, "")
    }

    // MARK: - WiFi SSID Extraction

    func testWiFiPasswordDetection_TrueForWLANService() {
        let item = makeKeychainItem(
            type: .genericPassword,
            label: "HomeNetwork",
            account: "HomeNetwork",
            service: "com.apple.network.wlan.ssid.HomeNetwork"
        )

        XCTAssertTrue(item.isWiFiPassword)
    }

    func testWiFiPasswordDetection_FalseForNonWLAN() {
        let item = makeKeychainItem(
            type: .genericPassword,
            label: "SomeApp",
            service: "com.someapp.password"
        )

        XCTAssertFalse(item.isWiFiPassword)
    }

    func testWiFiPasswordDetection_FalseForInternetPassword() {
        let item = makeKeychainItem(
            type: .internetPassword,
            service: "com.apple.network.wlan.ssid.Test"
        )

        // Must be genericPassword to be WiFi
        XCTAssertFalse(item.isWiFiPassword)
    }

    func testWiFiSSIDExtraction_FromAccount() {
        let item = makeKeychainItem(
            type: .genericPassword,
            label: "SomeLabel",
            account: "MyWiFiNetwork",
            service: "com.apple.network.wlan.ssid.MyWiFiNetwork"
        )

        XCTAssertEqual(item.wifiSSID, "MyWiFiNetwork")
    }

    func testWiFiSSIDExtraction_FallsBackToLabel() {
        let item = makeKeychainItem(
            type: .genericPassword,
            label: "OfficeWiFi",
            account: nil,
            service: "com.apple.network.wlan.ssid.OfficeWiFi"
        )

        XCTAssertEqual(item.wifiSSID, "OfficeWiFi")
    }

    func testWiFiSSIDExtraction_EmptyAccountFallsBackToLabel() {
        let item = makeKeychainItem(
            type: .genericPassword,
            label: "CafeNet",
            account: "",
            service: "com.apple.network.wlan.ssid.CafeNet"
        )

        XCTAssertEqual(item.wifiSSID, "CafeNet")
    }

    func testWiFiSSIDIsNilForNonWiFiItem() {
        let item = makeKeychainItem(
            type: .genericPassword,
            service: "com.app.service"
        )

        XCTAssertNil(item.wifiSSID)
    }

    // MARK: - Item Classification

    func testClassificationInternetPassword() {
        let item = makeKeychainItem(type: .internetPassword)
        XCTAssertEqual(item.type, .internetPassword)
    }

    func testClassificationGenericPassword() {
        let item = makeKeychainItem(type: .genericPassword)
        XCTAssertEqual(item.type, .genericPassword)
    }

    func testClassificationCertificate() {
        let item = makeKeychainItem(type: .certificate)
        XCTAssertEqual(item.type, .certificate)
    }

    func testClassificationKey() {
        let item = makeKeychainItem(type: .key)
        XCTAssertEqual(item.type, .key)
    }

    func testClassificationIdentity() {
        let item = makeKeychainItem(type: .identity)
        XCTAssertEqual(item.type, .identity)
    }

    // MARK: - Duplicate Items Are Not Filtered

    func testDuplicateItemsAreNotFiltered() async throws {
        let item1 = makeKeychainItem(type: .genericPassword, label: "Duplicate", account: "user")
        let item2 = makeKeychainItem(type: .genericPassword, label: "Duplicate", account: "user")
        let item3 = makeKeychainItem(type: .genericPassword, label: "Duplicate", account: "user")

        let mockReader = MockKeychainReader(items: [item1, item2, item3])
        let results = try await mockReader.readAllItems()

        XCTAssertEqual(results.count, 3, "All items should be returned, including duplicates")
    }

    func testDuplicateItemsHaveUniqueIDs() {
        let item1 = makeKeychainItem(type: .genericPassword, label: "Same")
        let item2 = makeKeychainItem(type: .genericPassword, label: "Same")

        XCTAssertNotEqual(item1.id, item2.id, "Each KeychainItem should have a unique UUID")
    }

    // MARK: - Date Parsing

    func testCreationDatePreserved() {
        let date = Date(timeIntervalSince1970: 1700000000) // 2023-11-14
        let item = makeKeychainItem(type: .genericPassword, creationDate: date)
        XCTAssertEqual(item.creationDate, date)
    }

    func testModificationDatePreserved() {
        let date = Date(timeIntervalSince1970: 1715000000) // 2024-05-06
        let item = makeKeychainItem(type: .genericPassword, modificationDate: date)
        XCTAssertEqual(item.modificationDate, date)
    }

    func testNilDatesAreHandled() {
        let item = makeKeychainItem(type: .genericPassword, creationDate: nil, modificationDate: nil)
        XCTAssertNil(item.creationDate)
        XCTAssertNil(item.modificationDate)
    }

    // MARK: - Keychain Source

    func testKeychainSourceIsPreserved() {
        let loginItem = KeychainItem(
            type: .genericPassword, label: "Test", account: nil, service: nil,
            server: nil, port: nil, protocol: nil, path: nil, data: nil,
            creationDate: nil, modificationDate: nil, keychainSource: "Login"
        )
        XCTAssertEqual(loginItem.keychainSource, "Login")

        let systemItem = KeychainItem(
            type: .genericPassword, label: "Test", account: nil, service: nil,
            server: nil, port: nil, protocol: nil, path: nil, data: nil,
            creationDate: nil, modificationDate: nil, keychainSource: "System"
        )
        XCTAssertEqual(systemItem.keychainSource, "System")

        let icloudItem = KeychainItem(
            type: .genericPassword, label: "Test", account: nil, service: nil,
            server: nil, port: nil, protocol: nil, path: nil, data: nil,
            creationDate: nil, modificationDate: nil, keychainSource: "iCloud"
        )
        XCTAssertEqual(icloudItem.keychainSource, "iCloud")
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
        return KeychainItem(
            type: type,
            label: label,
            account: account,
            service: service,
            server: server,
            port: port,
            protocol: proto,
            path: path,
            data: data,
            creationDate: creationDate,
            modificationDate: modificationDate,
            keychainSource: keychainSource
        )
    }
}
