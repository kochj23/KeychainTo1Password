//
//  KeychainItem.swift
//  KeychainTo1Password
//
//  Created by Jordan Koch on 5/14/26.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import Foundation
import Security

/// Represents the type/class of a Keychain item
enum KeychainItemType: String, CaseIterable, Sendable {
    case internetPassword = "Internet Password"
    case genericPassword = "Generic Password"
    case certificate = "Certificate"
    case key = "Key"
    case identity = "Identity"

    var secClass: CFString {
        switch self {
        case .internetPassword: return kSecClassInternetPassword
        case .genericPassword: return kSecClassGenericPassword
        case .certificate: return kSecClassCertificate
        case .key: return kSecClassKey
        case .identity: return kSecClassIdentity
        }
    }

    var icon: String {
        switch self {
        case .internetPassword: return "globe"
        case .genericPassword: return "key.fill"
        case .certificate: return "doc.badge.gearshape"
        case .key: return "lock.fill"
        case .identity: return "person.badge.key.fill"
        }
    }
}

/// A unified model representing any Keychain item
struct KeychainItem: Identifiable, Sendable {
    let id = UUID()
    let type: KeychainItemType
    let label: String
    let account: String?
    let service: String?
    let server: String?
    let port: Int?
    let `protocol`: String?
    let path: String?
    let data: Data?
    let creationDate: Date?
    let modificationDate: Date?
    let keychainSource: String // e.g., "Login", "System", "iCloud"

    /// The display title for this item
    var displayTitle: String {
        if !label.isEmpty {
            return label
        }
        if let service = service, !service.isEmpty {
            return service
        }
        if let server = server, !server.isEmpty {
            return server
        }
        return "Untitled Item"
    }

    /// Whether this appears to be a WiFi password
    var isWiFiPassword: Bool {
        guard type == .genericPassword else { return false }
        return service?.hasPrefix("com.apple.network.wlan.ssid") == true
    }

    /// WiFi SSID if this is a WiFi password
    var wifiSSID: String? {
        guard isWiFiPassword else { return nil }
        // The SSID is typically stored in the account field or after the service prefix
        if let account = account, !account.isEmpty {
            return account
        }
        // Try extracting from label
        if label.contains("Wi-Fi") || label.contains("WiFi") {
            return label
        }
        return label.isEmpty ? nil : label
    }

    /// The password/secret as a string (if applicable)
    var passwordString: String? {
        guard let data = data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Constructed URL for internet passwords
    var url: String? {
        guard type == .internetPassword, let server = server, !server.isEmpty else { return nil }
        var urlString = ""
        if let proto = self.protocol {
            urlString += "\(proto)://"
        } else {
            urlString += "https://"
        }
        urlString += server
        if let port = port, port != 0, port != 80, port != 443 {
            urlString += ":\(port)"
        }
        if let path = path, !path.isEmpty {
            urlString += path
        }
        return urlString
    }
}
