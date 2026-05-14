//
//  MigrationManagerTests.swift
//  KeychainTo1PasswordTests
//
//  Tests for MigrationState, KeychainItem model, and MigrationDirection.
//
//  Created by Jordan Koch on 5/14/26.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import XCTest
@testable import KeychainTo1Password

final class MigrationManagerTests: XCTestCase {

    // MARK: - MigrationState Progress

    func testProgressCalculationWithZeroItems() {
        let state = MigrationState()
        state.totalItems = 0
        state.processedItems = 0
        XCTAssertEqual(state.progress, 0.0)
    }

    func testProgressCalculationMidway() {
        let state = MigrationState()
        state.totalItems = 10
        state.processedItems = 5
        XCTAssertEqual(state.progress, 0.5, accuracy: 0.001)
    }

    func testProgressCalculationComplete() {
        let state = MigrationState()
        state.totalItems = 20
        state.processedItems = 20
        XCTAssertEqual(state.progress, 1.0, accuracy: 0.001)
    }

    // MARK: - MigrationState Reset

    func testMigrationStateReset() {
        let state = MigrationState()
        state.phase = .completed
        state.totalItems = 50
        state.processedItems = 50
        state.successCount = 45
        state.failureCount = 5
        state.skippedCount = 2
        state.currentItemName = "Last Item"
        state.errors = [MigrationError(itemName: "x", message: "y")]

        state.reset()

        XCTAssertEqual(state.totalItems, 0)
        XCTAssertEqual(state.processedItems, 0)
        XCTAssertEqual(state.successCount, 0)
        XCTAssertEqual(state.failureCount, 0)
        XCTAssertEqual(state.skippedCount, 0)
        XCTAssertEqual(state.currentItemName, "")
        XCTAssertTrue(state.errors.isEmpty)
        if case .idle = state.phase {} else {
            XCTFail("Phase should reset to .idle")
        }
    }

    // MARK: - MigrationState IsRunning

    func testMigrationStateIsRunning() {
        let state = MigrationState()

        state.phase = .idle
        XCTAssertFalse(state.isRunning)

        state.phase = .readingKeychain
        XCTAssertTrue(state.isRunning)

        state.phase = .migrating
        XCTAssertTrue(state.isRunning)

        state.phase = .completed
        XCTAssertFalse(state.isRunning)

        state.phase = .failed("error")
        XCTAssertFalse(state.isRunning)
    }

    // MARK: - MigrationPhase

    func testMigrationPhaseIsCompleted() {
        XCTAssertFalse(MigrationPhase.idle.isCompleted)
        XCTAssertFalse(MigrationPhase.migrating.isCompleted)
        XCTAssertTrue(MigrationPhase.completed.isCompleted)
        XCTAssertFalse(MigrationPhase.failed("x").isCompleted)
    }

    func testMigrationPhaseFailureMessage() {
        XCTAssertNil(MigrationPhase.idle.failureMessage)
        XCTAssertNil(MigrationPhase.completed.failureMessage)
        XCTAssertEqual(MigrationPhase.failed("oops").failureMessage, "oops")
    }

    // MARK: - MigrationError Model

    func testMigrationErrorProperties() {
        let error = MigrationError(itemName: "TestItem", message: "Connection refused")
        XCTAssertEqual(error.itemName, "TestItem")
        XCTAssertEqual(error.message, "Connection refused")
        XCTAssertNotNil(error.id)
    }

    func testMigrationErrorsHaveUniqueIDs() {
        let error1 = MigrationError(itemName: "A", message: "x")
        let error2 = MigrationError(itemName: "A", message: "x")
        XCTAssertNotEqual(error1.id, error2.id)
    }

    // MARK: - MigrationDirection

    func testMigrationDirectionRawValues() {
        XCTAssertEqual(MigrationDirection.fromOnePassword.rawValue, "1Password → Keychain")
        XCTAssertEqual(MigrationDirection.toOnePassword.rawValue, "Keychain → 1Password")
    }

    func testMigrationDirectionAllCases() {
        XCTAssertEqual(MigrationDirection.allCases.count, 2)
    }
}
