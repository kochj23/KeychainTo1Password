//
//  DesignSystem.swift
//  KeychainTo1Password
//
//  Dark-mode-first glassmorphic design system.
//  Inspired by NMAPScanner and RsyncGUI.
//
//  Created by Jordan Koch on 5/14/26.
//  Copyright © 2026 Jordan Koch. All rights reserved.
//

import SwiftUI

// MARK: - Colors

struct AppColors {
    // Background gradient
    static let gradientStart = Color(red: 0.06, green: 0.09, blue: 0.18)
    static let gradientEnd = Color(red: 0.10, green: 0.14, blue: 0.26)

    // Accent — cyan/teal
    static let accent = Color(red: 0.25, green: 0.82, blue: 0.88)
    static let accentDim = Color(red: 0.20, green: 0.65, blue: 0.70)

    // Status
    static let success = Color(red: 0.30, green: 0.90, blue: 0.55)
    static let warning = Color(red: 1.0, green: 0.78, blue: 0.28)
    static let error = Color(red: 1.0, green: 0.35, blue: 0.40)

    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.7)
    static let textTertiary = Color.white.opacity(0.45)

    // Glass
    static let glassBackground = Color.white.opacity(0.05)
    static let glassBorder = Color.white.opacity(0.12)

    // Background gradient
    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [gradientStart, gradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Glass Card Modifier

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 16

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(AppColors.glassBackground)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(.ultraThinMaterial)
                            .opacity(0.8)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(AppColors.glassBorder, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Accent Button Style

struct AccentButtonStyle: ButtonStyle {
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isDestructive ? AppColors.error : AppColors.accent)
                    .opacity(configuration.isPressed ? 0.7 : 1.0)
            )
            .shadow(
                color: (isDestructive ? AppColors.error : AppColors.accent).opacity(0.4),
                radius: configuration.isPressed ? 2 : 8,
                y: 2
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(AppColors.accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.accent.opacity(0.5), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(AppColors.accent.opacity(configuration.isPressed ? 0.15 : 0.05))
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Background View

struct AppBackground: View {
    var body: some View {
        ZStack {
            AppColors.backgroundGradient
                .ignoresSafeArea()

            // Subtle floating orbs
            Circle()
                .fill(AppColors.accent.opacity(0.08))
                .frame(width: 200, height: 200)
                .blur(radius: 60)
                .offset(x: -120, y: -150)

            Circle()
                .fill(Color.purple.opacity(0.06))
                .frame(width: 180, height: 180)
                .blur(radius: 50)
                .offset(x: 150, y: 100)
        }
    }
}

// MARK: - Monospace Status Text

struct StatusText: View {
    let text: String
    var color: Color = AppColors.textSecondary

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .regular, design: .monospaced))
            .foregroundColor(color)
    }
}
