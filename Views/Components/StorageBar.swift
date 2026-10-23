//
//  StorageBar.swift
//  PureLibrary
//
//  Monochromatic device storage usage bar with Cobalt Blue reclaimable overlay.
//  Strictly ZERO-EMOJI Rule compliant.
//

import SwiftUI

public struct StorageBar: View {
    @ObservedObject private var loc = LocalizationManager.shared
    public let totalBytes: Int64
    public let freeBytes: Int64
    public let reclaimableBytes: Int64
    
    public init(totalBytes: Int64, freeBytes: Int64, reclaimableBytes: Int64) {
        self.totalBytes = totalBytes
        self.freeBytes = freeBytes
        self.reclaimableBytes = reclaimableBytes
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            // Header stats
            HStack {
                HStack(spacing: AppTheme.Spacing.xxs) {
                    VectorIconView(.storageMeter, size: 14, color: AppTheme.Colors.textSecondary)
                    Text(loc.t("device_storage"))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                
                Spacer()
                
                Text("\(ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            
            // Bar visualization
            GeometryReader { geometry in
                let w = geometry.size.width
                let total = max(1.0, Double(totalBytes))
                let usedRatio = max(0.0, min(1.0, Double(usedBytes - reclaimableBytes) / total))
                let reclaimRatio = max(0.0, min(1.0, Double(reclaimableBytes) / total))
                let freeRatio = max(0.0, min(1.0, Double(freeBytes) / total))
                
                HStack(spacing: 2) {
                    Rectangle()
                        .fill(AppTheme.Colors.surfaceRaised)
                        .frame(width: max(2, w * CGFloat(usedRatio)))
                    
                    Rectangle()
                        .fill(AppTheme.Colors.primaryAccent)
                        .frame(width: max(2, w * CGFloat(reclaimRatio)))
                    
                    Rectangle()
                        .fill(AppTheme.Colors.surfaceBorder)
                        .frame(width: max(2, w * CGFloat(freeRatio)))
                }
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))
            }
            .frame(height: 10)
            
            // Legend
            HStack(spacing: AppTheme.Spacing.md) {
                LegendItem(color: AppTheme.Colors.surfaceRaised, label: loc.t("storage_used_system"))
                LegendItem(color: AppTheme.Colors.primaryAccent, label: loc.t("storage_reclaimable"))
                LegendItem(color: AppTheme.Colors.surfaceBorder, label: loc.t("storage_free"))
                
                Spacer()
                
                if reclaimableBytes > 0 {
                    Text("+\(ByteCountFormatter.string(fromByteCount: reclaimableBytes, countStyle: .file)) \(loc.t("storage_freeable_suffix"))")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.Colors.semanticEmerald)
                }
            }
            .padding(.top, AppTheme.Spacing.xxs)
        }
        .pureCard(cornerRadius: AppTheme.Radius.md, padding: AppTheme.Spacing.md)
    }
    
    private var usedBytes: Int64 {
        max(0, totalBytes - freeBytes)
    }
}

private struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
        }
    }
}
