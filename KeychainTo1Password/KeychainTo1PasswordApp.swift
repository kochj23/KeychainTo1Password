//
//  KeychainTo1PasswordApp.swift
//  KeychainTo1Password
//
//  Created by Jordan Koch on 5/14/26.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

@main
struct KeychainTo1PasswordApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 650, minHeight: 600)
                .frame(width: 650, height: 650)
        }
        .windowResizability(.contentMinSize)
    }
}
