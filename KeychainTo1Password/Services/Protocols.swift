//
//  Protocols.swift
//  KeychainTo1Password
//
//  Protocol abstractions for dependency injection and testability.
//
//  Created by Jordan Koch on 5/14/26.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation

protocol KeychainReading {
    func readAllItems() async throws -> [KeychainItem]
    func readItems(ofType type: KeychainItemType) async throws -> [KeychainItem]
}

extension KeychainReader: KeychainReading {}
