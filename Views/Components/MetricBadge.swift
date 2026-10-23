//
//  MetricBadge.swift
//  PureLibrary
//
//  Precision Metric Badge with Vector Icon and Status Tinting.
//  Strictly ZERO-EMOJI Rule compliant.
//

import SwiftUI

public struct MetricBadge: View {
    public let icon: VectorIconType
    public let title: String
    public let value: String
    public let tintColor: Color
    
    public init(
        icon: VectorIconType,
        title: String,
        value: String,
        tintColor: Color = AppTheme.Colors.primaryAccent
    ) {
        self.icon = icon
        self.title = title
        self.value = value
        self.tintColor = tintColor
    }
    
    public var body: some View {
        HStack(spacing: AppTheme.Spacing.xxs) {
            VectorIconView(icon, size: 12, color: tintColor, lineWidth: 1.6)
            
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(tintColor)
        }
        .padding(.horizontal, AppTheme.Spacing.xs)
        .padding(.vertical, AppTheme.Spacing.xxs)
        .background(AppTheme.Colors.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
                .stroke(AppTheme.Colors.surfaceBorder, lineWidth: 1)
        )
    }
}
