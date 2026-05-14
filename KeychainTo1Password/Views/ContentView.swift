//
//  ContentView.swift
//  KeychainTo1Password
//
//  Main UI — direction picker, vault selection, item list, migrate.
//
//  Created by Jordan Koch on 5/14/26.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @State private var manager = MigrationManager()
    @State private var showErrors = false

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                HeaderView()

                Divider().background(AppColors.glassBorder)

                ScrollView {
                    VStack(spacing: 16) {
                        if let error = manager.initError {
                            ErrorBanner(message: error)
                        }

                        if manager.isInitialized {
                            DirectionPickerCard(manager: manager)
                            VaultSelectionCard(manager: manager)
                            ItemListCard(manager: manager)
                            MigrationControlCard(manager: manager)
                        } else if manager.initError == nil {
                            ConnectingView()
                        }

                        if manager.state.isRunning || manager.state.phase.isCompleted {
                            ProgressCard(state: manager.state)
                        }

                        if manager.state.phase.isCompleted {
                            SummaryCard(state: manager.state, showErrors: $showErrors)
                        }

                        if let failMsg = manager.state.phase.failureMessage {
                            ErrorBanner(message: failMsg)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .task {
            await manager.initialize()
        }
        .sheet(isPresented: $showErrors) {
            ErrorListView(errors: manager.state.errors)
        }
    }
}

// MARK: - Header

struct HeaderView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.viewfinder")
                .font(.system(size: 28))
                .foregroundColor(AppColors.accent)
                .shadow(color: AppColors.accent.opacity(0.5), radius: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text("KeychainTo1Password")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)

                Text("Bidirectional migration: 1Password ↔ macOS Keychain")
                    .font(.system(size: 11))
                    .foregroundColor(AppColors.textTertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }
}

// MARK: - Connecting

struct ConnectingView: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView().controlSize(.small)
            StatusText(text: "Connecting to 1Password...")
        }
        .padding(16)
        .glassCard()
    }
}

// MARK: - Direction Picker

struct DirectionPickerCard: View {
    @Bindable var manager: MigrationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Direction", systemImage: "arrow.left.arrow.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            Picker("", selection: $manager.direction) {
                ForEach(MigrationDirection.allCases, id: \.self) { dir in
                    Label(dir.rawValue, systemImage: dir.icon)
                        .tag(dir)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: manager.direction) {
                manager.opItems = []
                manager.keychainItems = []
                manager.selectedOPItems.removeAll()
                manager.selectedKeychainItems.removeAll()
                manager.state.reset()
            }
        }
        .padding(14)
        .glassCard()
    }
}

// MARK: - Vault Selection

struct VaultSelectionCard: View {
    @Bindable var manager: MigrationManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("1Password Vault", systemImage: "lock.shield.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            HStack {
                Picker("", selection: $manager.selectedVault) {
                    Text("Select a vault...").tag(nil as OPVault?)
                    ForEach(manager.availableVaults) { vault in
                        Text(vault.name).tag(vault as OPVault?)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity)
                .onChange(of: manager.selectedVault) {
                    manager.opItems = []
                    manager.keychainItems = []
                    manager.selectedOPItems.removeAll()
                    manager.selectedKeychainItems.removeAll()
                }

                Button {
                    Task { await manager.loadItems() }
                } label: {
                    Label("Load Items", systemImage: "arrow.clockwise")
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(manager.selectedVault == nil || manager.isLoadingItems)
            }
        }
        .padding(14)
        .glassCard()
    }
}

// MARK: - Item List

struct ItemListCard: View {
    @Bindable var manager: MigrationManager

    var body: some View {
        if manager.isLoadingItems {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                StatusText(text: "Loading items...")
            }
            .padding(14)
            .glassCard()
        } else if manager.totalCount > 0 {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(
                        "\(manager.selectedCount) of \(manager.totalCount) selected",
                        systemImage: "checklist"
                    )
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    Button("All") { manager.selectAll() }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("None") { manager.selectNone() }
                        .buttonStyle(SecondaryButtonStyle())
                }

                // Options
                Toggle("Overwrite duplicates", isOn: $manager.overwriteDuplicates)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textSecondary)
                    .toggleStyle(.checkbox)

                Divider().background(AppColors.glassBorder)

                ScrollView {
                    LazyVStack(spacing: 4) {
                        switch manager.direction {
                        case .fromOnePassword:
                            ForEach(manager.opItems) { item in
                                OPItemRow(item: item, isSelected: manager.selectedOPItems.contains(item.id)) {
                                    if manager.selectedOPItems.contains(item.id) {
                                        manager.selectedOPItems.remove(item.id)
                                    } else {
                                        manager.selectedOPItems.insert(item.id)
                                    }
                                }
                            }
                        case .toOnePassword:
                            ForEach(manager.keychainItems) { item in
                                KeychainItemRow(item: item, isSelected: manager.selectedKeychainItems.contains(item.id)) {
                                    if manager.selectedKeychainItems.contains(item.id) {
                                        manager.selectedKeychainItems.remove(item.id)
                                    } else {
                                        manager.selectedKeychainItems.insert(item.id)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
            .padding(14)
            .glassCard()
        }
    }
}

// MARK: - Item Rows

struct OPItemRow: View {
    let item: OPItem
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? AppColors.accent : AppColors.textTertiary)
                .font(.system(size: 14))

            Image(systemName: item.categoryIcon)
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let username = item.username, !username.isEmpty {
                        Text(username)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(AppColors.textTertiary)
                            .lineLimit(1)
                    }
                    if !item.isImportable {
                        Text("no password")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(AppColors.warning)
                    }
                }
            }

            Spacer()

            Text(item.category)
                .font(.system(size: 10))
                .foregroundColor(AppColors.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.glassBackground)
                )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { toggle() }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? AppColors.accent.opacity(0.08) : Color.clear)
        )
    }
}

struct KeychainItemRow: View {
    let item: KeychainItem
    let isSelected: Bool
    let toggle: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? AppColors.accent : AppColors.textTertiary)
                .font(.system(size: 14))

            Image(systemName: item.type.icon)
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayTitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                if let account = item.account, !account.isEmpty {
                    Text(account)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(AppColors.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(item.type.rawValue)
                .font(.system(size: 10))
                .foregroundColor(AppColors.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.glassBackground)
                )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { toggle() }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? AppColors.accent.opacity(0.08) : Color.clear)
        )
    }
}

// MARK: - Migration Control

struct MigrationControlCard: View {
    @Bindable var manager: MigrationManager

    var body: some View {
        if manager.selectedCount > 0 && !manager.state.isRunning {
            HStack {
                let label = manager.direction == .fromOnePassword
                    ? "Import \(manager.selectedCount) to Keychain"
                    : "Export \(manager.selectedCount) to 1Password"

                Button {
                    Task { await manager.migrate() }
                } label: {
                    Label(label, systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(AccentButtonStyle())

                Spacer()
            }
            .padding(14)
            .glassCard()
        }
    }
}

// MARK: - Progress Card

struct ProgressCard: View {
    let state: MigrationState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Progress", systemImage: "chart.bar.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.glassBackground)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(
                            colors: [AppColors.accent, AppColors.success],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * state.progress, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: state.progress)
                }
            }
            .frame(height: 8)

            HStack {
                StatusText(text: "\(state.processedItems)/\(state.totalItems)", color: AppColors.textSecondary)
                Spacer()
                StatusText(text: "\(Int(state.progress * 100))%", color: AppColors.accent)
            }

            if !state.currentItemName.isEmpty {
                StatusText(text: "Current: \(state.currentItemName)", color: AppColors.textTertiary)
                    .lineLimit(1).truncationMode(.middle)
            }
        }
        .padding(14)
        .glassCard()
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let state: MigrationState
    @Binding var showErrors: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Migration Complete", systemImage: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.success)

            HStack(spacing: 24) {
                StatBadge(label: "Success", value: state.successCount, color: AppColors.success)
                StatBadge(label: "Skipped", value: state.skippedCount, color: AppColors.warning)
                StatBadge(label: "Failed", value: state.failureCount, color: AppColors.error)
            }

            if !state.errors.isEmpty {
                Button {
                    showErrors = true
                } label: {
                    Label("View \(state.errors.count) Error\(state.errors.count == 1 ? "" : "s")", systemImage: "exclamationmark.triangle")
                        .font(.system(size: 12))
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(14)
        .glassCard()
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.textTertiary)
                .textCase(.uppercase)
        }
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppColors.error)
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(3)
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.error.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AppColors.error.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Error List View

struct ErrorListView: View {
    let errors: [MigrationError]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Migration Errors")
                    .font(.headline)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding()

            Divider()

            List(errors) { error in
                VStack(alignment: .leading, spacing: 4) {
                    Text(error.itemName)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(AppColors.textPrimary)
                    Text(error.message)
                        .font(.system(size: 11))
                        .foregroundColor(AppColors.textSecondary)
                }
                .listRowBackground(Color.clear)
            }
        }
        .frame(width: 500, height: 400)
        .background(AppColors.gradientStart)
    }
}

#Preview {
    ContentView()
        .frame(width: 650, height: 600)
}
