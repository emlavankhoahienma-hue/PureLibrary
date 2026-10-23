//
//  ClusterCompareView.swift
//  PureLibrary
//
//  Cluster Comparison View: Best Shot Inspection, Metrics Breakdown & 1-Tap Staging.
//  Strictly ZERO-EMOJI Rule compliant.
//

import SwiftUI

public struct ClusterCompareView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @ObservedObject public var clusterReviewViewModel: ClusterReviewViewModel
    public let onStageCluster: (Set<String>) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var activeInspectedAssetId: String?
    
    public init(
        clusterReviewViewModel: ClusterReviewViewModel,
        onStageCluster: @escaping (Set<String>) -> Void
    ) {
        self.clusterReviewViewModel = clusterReviewViewModel
        self.onStageCluster = onStageCluster
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.backgroundPrimary
                    .ignoresSafeArea()
                
                if let cluster = clusterReviewViewModel.currentCluster {
                    VStack(spacing: 0) {
                        // Top Cluster Pager Bar
                        HStack {
                            Button {
                                clusterReviewViewModel.previousCluster()
                                resetInspectedAsset()
                            } label: {
                                VectorIconView(.chevron(.left), size: 16, color: clusterReviewViewModel.hasPreviousCluster ? AppTheme.Colors.textPrimary : AppTheme.Colors.surfaceBorder)
                            }
                            .disabled(!clusterReviewViewModel.hasPreviousCluster)
                            
                            Spacer()
                            
                            VStack(spacing: 2) {
                                Text("\(loc.t("cluster_of_label")) \(clusterReviewViewModel.currentClusterIndex + 1) / \(clusterReviewViewModel.totalClustersCount)")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                
                                Text(cluster.clusterType.rawValue.uppercased())
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundColor(AppTheme.Colors.primaryAccent)
                            }
                            
                            Spacer()
                            
                            Button {
                                clusterReviewViewModel.nextCluster()
                                resetInspectedAsset()
                            } label: {
                                VectorIconView(.chevron(.right), size: 16, color: clusterReviewViewModel.hasNextCluster ? AppTheme.Colors.textPrimary : AppTheme.Colors.surfaceBorder)
                            }
                            .disabled(!clusterReviewViewModel.hasNextCluster)
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.vertical, AppTheme.Spacing.sm)
                        .background(AppTheme.Colors.surfaceCard)
                        
                        ScrollView {
                            VStack(spacing: AppTheme.Spacing.md) {
                                // Horizontal Photo Strip for Cluster
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: AppTheme.Spacing.sm) {
                                        ForEach(cluster.items) { item in
                                            let isBest = (item.id == cluster.bestShotId)
                                            let isStaged = clusterReviewViewModel.isItemStaged(item.id)
                                            let isSelected = (item.id == activeAsset(in: cluster).id)
                                            
                                            VStack(spacing: 6) {
                                                PhotoThumbnailView(
                                                    item: item,
                                                    isBestShot: isBest,
                                                    isStaged: isStaged,
                                                    targetSize: CGSize(width: 130, height: 160),
                                                    onSelect: {
                                                        activeInspectedAssetId = item.id
                                                    }
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: AppTheme.Radius.md)
                                                        .stroke(isSelected ? AppTheme.Colors.textPrimary : Color.clear, lineWidth: 2)
                                                )
                                                
                                                if !isBest {
                                                    Button {
                                                        clusterReviewViewModel.setManualBestShot(assetId: item.id)
                                                    } label: {
                                                        Text(loc.t("btn_set_best"))
                                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                                            .foregroundColor(AppTheme.Colors.textSecondary)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(AppTheme.Colors.surfaceRaised)
                                                            .clipShape(Capsule())
                                                    }
                                                    .buttonStyle(.plain)
                                                } else {
                                                    Text(loc.t("ai_winner_badge"))
                                                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                                        .foregroundColor(AppTheme.Colors.primaryAccent)
                                                        .padding(.vertical, 2)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.horizontal, AppTheme.Spacing.md)
                                    .padding(.vertical, AppTheme.Spacing.sm)
                                }
                                
                                // Selected Asset AI Score Breakdown Card
                                let inspected = activeAsset(in: cluster)
                                ScoreBreakdownView(
                                    item: inspected,
                                    isBestShot: inspected.id == cluster.bestShotId
                                )
                                .padding(.horizontal, AppTheme.Spacing.md)
                                
                                // Cluster Space Savings Metric
                                HStack {
                                    HStack(spacing: AppTheme.Spacing.xxs) {
                                        VectorIconView(.duplicateLayers, size: 14, color: AppTheme.Colors.textSecondary)
                                        Text(loc.t("reclaimable_in_cluster"))
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .foregroundColor(AppTheme.Colors.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(cluster.formattedReclaimableBytes)
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundColor(AppTheme.Colors.semanticEmerald)
                                }
                                .padding(.horizontal, AppTheme.Spacing.md)
                                
                                Spacer(minLength: AppTheme.Spacing.lg)
                            }
                            .padding(.vertical, AppTheme.Spacing.sm)
                        }
                        
                        // Bottom Thumb-friendly Action Bar
                        VStack(spacing: AppTheme.Spacing.xs) {
                            Button {
                                clusterReviewViewModel.stageRestExceptBest(in: cluster)
                                onStageCluster(clusterReviewViewModel.stagedAssetIds)
                                if clusterReviewViewModel.hasNextCluster {
                                    clusterReviewViewModel.nextCluster()
                                    resetInspectedAsset()
                                } else {
                                    dismiss()
                                }
                            } label: {
                                HStack(spacing: AppTheme.Spacing.xs) {
                                    VectorIconView(.crown, size: 16, color: AppTheme.Colors.textPrimary)
                                    Text(loc.t("btn_keep_best_stage_rest"))
                                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                                }
                                .foregroundColor(AppTheme.Colors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, AppTheme.Spacing.md)
                                .background(AppTheme.Colors.primaryAccent)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(AppTheme.Spacing.md)
                        .background(AppTheme.Colors.surfaceCard)
                    }
                } else {
                    VStack(spacing: AppTheme.Spacing.md) {
                        VectorIconView(.checkmark, size: 36, color: AppTheme.Colors.semanticEmerald)
                        Text(loc.t("no_clusters_title"))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        Text(loc.t("no_clusters_sub"))
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                }
            }
            .navigationTitle(loc.t("cluster_compare_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.Colors.backgroundPrimary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc.t("btn_close")) {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.textPrimary)
                }
            }
        }
    }
    
    private func activeAsset(in cluster: PhotoClusterGroup) -> PhotoAssetItem {
        if let id = activeInspectedAssetId, let found = cluster.items.first(where: { $0.id == id }) {
            return found
        }
        return cluster.bestShotItem ?? cluster.items[0]
    }
    
    private func resetInspectedAsset() {
        activeInspectedAssetId = nil
    }
}
