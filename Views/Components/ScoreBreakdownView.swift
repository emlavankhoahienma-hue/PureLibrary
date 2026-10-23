//
//  ScoreBreakdownView.swift
//  PureLibrary
//
//  Detailed inspection card showing empirical AI scoring parameters (85% Physical + 15% Neural).
//  Strictly ZERO-EMOJI Rule compliant.
//

import SwiftUI

public struct ScoreBreakdownView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    public let item: PhotoAssetItem
    public let isBestShot: Bool
    
    public init(item: PhotoAssetItem, isBestShot: Bool = false) {
        self.item = item
        self.isBestShot = isBestShot
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            // Header
            HStack {
                if isBestShot {
                    HStack(spacing: AppTheme.Spacing.xxs) {
                        VectorIconView(.crown, size: 14, color: AppTheme.Colors.primaryAccent, lineWidth: 2.0)
                        Text(loc.t("best_shot_winner"))
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .foregroundColor(AppTheme.Colors.primaryAccent)
                    }
                    .padding(.horizontal, AppTheme.Spacing.xs)
                    .padding(.vertical, 4)
                    .background(AppTheme.Colors.primaryAccentGlow)
                    .clipShape(Capsule())
                }
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(loc.t("composite_label"))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Text(String(format: "%.1f", item.compositeScore))
                        .font(.system(size: 16, weight: .heavy, design: .monospaced))
                        .foregroundColor(scoreColor(item.compositeScore))
                }
            }
            
            Divider()
                .background(AppTheme.Colors.surfaceBorder)
            
            // Score rows (85% Physical + 15% Neural Advisor)
            VStack(spacing: AppTheme.Spacing.xs) {
                ScoreRow(
                    icon: .sharpnessScan,
                    label: loc.t("score_sharpness_row"),
                    score: item.sharpnessScore,
                    weight: "45%"
                )
                ScoreRow(
                    icon: .eyeSparkle,
                    label: loc.t("score_face_row"),
                    score: item.faceQualityScore,
                    weight: "25%"
                )
                ScoreRow(
                    icon: .exposureSlider,
                    label: loc.t("score_exposure_row"),
                    score: item.exposureScore,
                    weight: "15%"
                )
                ScoreRow(
                    icon: .sparkles,
                    label: loc.t("score_aesthetic_row"),
                    score: item.aestheticScore,
                    weight: "15%"
                )
            }
            
            // Negative flags & penalties
            if item.motionBlurScore > 0 {
                HStack(spacing: AppTheme.Spacing.xxs) {
                    VectorIconView(.blurDrop, size: 12, color: AppTheme.Colors.semanticCrimson)
                    Text(loc.t("motion_blur_penalty_row"))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.semanticCrimson)
                }
                .padding(.top, 2)
            }
        }
        .pureCard(cornerRadius: AppTheme.Radius.md, padding: AppTheme.Spacing.md)
    }
    
    private func scoreColor(_ score: Double) -> Color {
        if score >= 75.0 {
            return AppTheme.Colors.semanticEmerald
        } else if score >= 50.0 {
            return AppTheme.Colors.primaryAccent
        } else if score >= 30.0 {
            return AppTheme.Colors.semanticAmber
        } else {
            return AppTheme.Colors.semanticCrimson
        }
    }
}

private struct ScoreRow: View {
    let icon: VectorIconType
    let label: String
    let score: Double
    let weight: String
    
    var body: some View {
        HStack(spacing: AppTheme.Spacing.xs) {
            VectorIconView(icon, size: 12, color: AppTheme.Colors.textSecondary)
                .frame(width: 14)
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .lineLimit(1)
            
            Text("(\(weight))")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            Spacer()
            
            GeometryReader { geo in
                let ratio = max(0.0, min(1.0, score / 100.0))
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.Colors.surfaceRaised)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppTheme.Colors.primaryAccent)
                        .frame(width: geo.size.width * CGFloat(ratio))
                }
            }
            .frame(width: 60, height: 6)
            
            Text(String(format: "%.0f", score))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(AppTheme.Colors.textPrimary)
                .frame(width: 26, alignment: .trailing)
        }
    }
}
