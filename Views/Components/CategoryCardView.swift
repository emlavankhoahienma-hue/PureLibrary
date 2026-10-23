//
//  CategoryCardView.swift
//  PureLibrary
//
//  Dashboard Category Navigation Card.
//  Strictly ZERO-EMOJI Rule compliant.
//

import SwiftUI

public struct CategoryCardView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    public let icon: VectorIconType
    public let title: String
    public let subtitle: String
    public let count: Int
    public let reclaimableBytes: Int64
    public let accentColor: Color
    public let action: () -> Void
    
    public init(
        icon: VectorIconType,
        title: String,
        subtitle: String,
        count: Int,
        reclaimableBytes: Int64,
        accentColor: Color = AppTheme.Colors.primaryAccent,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.count = count
        self.reclaimableBytes = reclaimableBytes
        self.accentColor = accentColor
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.md) {
                // Vector Icon Box
                ZStack {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                        .fill(AppTheme.Colors.surfaceRaised)
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                                .stroke(AppTheme.Colors.surfaceBorder, lineWidth: 1)
                        )
                    
                    VectorIconView(icon, size: 20, color: accentColor)
                }
                
                // Titles
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                // Metrics and Chevron
                VStack(alignment: .trailing, spacing: 3) {
                    Text(ByteCountFormatter.string(fromByteCount: reclaimableBytes, countStyle: .file))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(reclaimableBytes > 0 ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
                    
                    Text("\(count) \(loc.t("items_count_suffix"))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                VectorIconView(.chevron(.right), size: 14, color: AppTheme.Colors.textSecondary)
            }
            .pureCard(cornerRadius: AppTheme.Radius.md, padding: AppTheme.Spacing.md)
        }
        .buttonStyle(.plain)
    }
}
