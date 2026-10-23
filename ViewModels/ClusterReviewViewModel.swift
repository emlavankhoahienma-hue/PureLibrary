//
//  ClusterReviewViewModel.swift
//  PureLibrary
//
//  ViewModel managing the detailed comparison of similar photo clusters.
//  Strictly ZERO-EMOJI Rule compliant.
//

import SwiftUI

@MainActor
public final class ClusterReviewViewModel: ObservableObject {
    @Published public var clusters: [PhotoClusterGroup]
    @Published public var currentClusterIndex: Int = 0
    @Published public var stagedAssetIds: Set<String> = []
    
    public init(clusters: [PhotoClusterGroup] = []) {
        self.clusters = clusters
    }
    
    // MARK: - Current Cluster Accessors
    public var currentCluster: PhotoClusterGroup? {
        guard currentClusterIndex >= 0 && currentClusterIndex < clusters.count else { return nil }
        return clusters[currentClusterIndex]
    }
    
    public var totalClustersCount: Int {
        clusters.count
    }
    
    public var hasNextCluster: Bool {
        currentClusterIndex < (clusters.count - 1)
    }
    
    public var hasPreviousCluster: Bool {
        currentClusterIndex > 0
    }
    
    // MARK: - Navigation
    public func nextCluster() {
        if hasNextCluster {
            currentClusterIndex += 1
        }
    }
    
    public func previousCluster() {
        if hasPreviousCluster {
            currentClusterIndex -= 1
        }
    }
    
    public func jumpToCluster(at index: Int) {
        guard index >= 0 && index < clusters.count else { return }
        currentClusterIndex = index
    }
    
    // MARK: - Actions
    /// 1-Tap Keep Best & Stage Rest: stages all non-best photos in the current cluster
    public func stageRestExceptBest(in cluster: PhotoClusterGroup) {
        guard let idx = clusters.firstIndex(where: { $0.id == cluster.id }) else { return }
        clusters[idx].stageRestExceptBest()
        
        for item in clusters[idx].items {
            if item.id == clusters[idx].bestShotId {
                stagedAssetIds.remove(item.id)
            } else {
                stagedAssetIds.insert(item.id)
            }
        }
    }
    
    /// Toggle individual photo stage status
    public func toggleItemStaged(_ itemId: String) {
        guard var cluster = currentCluster, let idx = clusters.firstIndex(where: { $0.id == cluster.id }) else { return }
        cluster.toggleStagedStatus(for: itemId)
        clusters[idx] = cluster
        
        if stagedAssetIds.contains(itemId) {
            stagedAssetIds.remove(itemId)
        } else {
            stagedAssetIds.insert(itemId)
        }
    }
    
    /// User manually sets a new Best Shot
    public func setManualBestShot(assetId: String) {
        guard var cluster = currentCluster, let idx = clusters.firstIndex(where: { $0.id == cluster.id }) else { return }
        cluster.setManualBestShot(assetId: assetId)
        clusters[idx] = cluster
        // Best shot should never be staged
        stagedAssetIds.remove(assetId)
    }
    
    public func isItemStaged(_ itemId: String) -> Bool {
        stagedAssetIds.contains(itemId)
    }
    
    // Total bytes currently staged across all reviewed clusters
    public var totalStagedBytes: Int64 {
        var total: Int64 = 0
        for cluster in clusters {
            for item in cluster.items where stagedAssetIds.contains(item.id) {
                total += item.fileSizeBytes
            }
        }
        return total
    }
    
    public var formattedTotalStagedBytes: String {
        ByteCountFormatter.string(fromByteCount: totalStagedBytes, countStyle: .file)
    }
}
