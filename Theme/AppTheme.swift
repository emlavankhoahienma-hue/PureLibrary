//
//  AppTheme.swift
//  PureLibrary
//
//  Human-Crafted Design System: Monochromatic Dark + Electric Cobalt Blue
//  Strictly Zero-Emoji Rule compliant.
//

import SwiftUI

public enum AppTheme {
    // MARK: - Color Palette
    public enum Colors {
        /// Deep Obsidian background: #0B0E14
        public static let backgroundPrimary = Color(hex: 0x0B0E14)
        
        /// Elevated Slate card surface: #141923
        public static let surfaceCard = Color(hex: 0x141923)
        
        /// Raised slate surface for secondary layers: #1C2333
        public static let surfaceRaised = Color(hex: 0x1C2333)
        
        /// Subtle 1px border line: #222938
        public static let surfaceBorder = Color(hex: 0x222938)
        
        /// Crisp White text: #F3F5F8
        public static let textPrimary = Color(hex: 0xF3F5F8)
        
        /// Cool Gray secondary/muted text: #8A94A6
        public static let textSecondary = Color(hex: 0x8A94A6)
        
        /// Electric Cobalt Blue (Single Primary Accent): #2563EB
        public static let primaryAccent = Color(hex: 0x2563EB)
        
        /// Electric Cobalt subtle glow/tint
        public static let primaryAccentGlow = Color(hex: 0x2563EB).opacity(0.18)
        
        /// Semantic Status: Subtle Emerald (High scores & freed bytes): #10B981
        public static let semanticEmerald = Color(hex: 0x10B981)
        
        /// Semantic Status: Subtle Crimson (Destructive delete confirmation only): #EF4444
        public static let semanticCrimson = Color(hex: 0xEF4444)
        
        /// Semantic Status: Subtle Amber (Caution / medium score): #F59E0B
        public static let semanticAmber = Color(hex: 0xF59E0B)
    }
    
    // MARK: - Spacing Grid (8pt Standard)
    public enum Spacing {
        public static let xxs: CGFloat = 4
        public static let xs: CGFloat = 8
        public static let sm: CGFloat = 12
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
        public static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    public enum Radius {
        public static let sm: CGFloat = 6
        public static let md: CGFloat = 10
        public static let lg: CGFloat = 14
        public static let pill: CGFloat = 999
    }
}

// MARK: - Color Hex Extension
public extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

// MARK: - Custom Card View Modifier
public struct PureCardModifier: ViewModifier {
    public let cornerRadius: CGFloat
    public let padding: CGFloat
    
    public init(cornerRadius: CGFloat = AppTheme.Radius.md, padding: CGFloat = AppTheme.Spacing.md) {
        self.cornerRadius = cornerRadius
        self.padding = padding
    }
    
    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AppTheme.Colors.surfaceCard)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.Colors.surfaceBorder, lineWidth: 1)
            )
    }
}

public extension View {
    func pureCard(cornerRadius: CGFloat = AppTheme.Radius.md, padding: CGFloat = AppTheme.Spacing.md) -> some View {
        self.modifier(PureCardModifier(cornerRadius: cornerRadius, padding: padding))
    }
}
