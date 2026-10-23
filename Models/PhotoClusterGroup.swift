//
//  PhotoClusterGroup.swift
//  PureLibrary
//
//  Model representing a cluster of similar, burst, or duplicate photos.
//  Strictly ZERO-EMOJI Rule compliant.
//

import Foundation

public enum ClusterType: String, Codable, CaseIterable, Sendable {
    case burstSequence = "Burst Sequence"
    case similarAngle = "Similar Angle"
    case exactDuplicate = "Duplicate Match"
}

public struct PhotoClusterGroup: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let createdAt: Date
    public var items: [PhotoAssetItem]
    public var bestShotId: String
    public var clusterType: ClusterType
    public var averageSimilarityDistance: Float
    
    public init(
        id: String = UUID().uuidString,
        createdAt: Date = Date(),
        items: [PhotoAssetItem],
        bestShotId: String,
        clusterType: ClusterType = .similarAngle,
        averageSimilarityDistance: Float = 0.0
    ) {
        self.id = id
        self.createdAt = createdAt
        self.items = items
        self.bestShotId = bestShotId
        self.clusterType = clusterType
        self.averageSimilarityDistance = averageSimilarityDistance
    }
    
    // MARK: - Best Shot Item
    public var bestShotItem: PhotoAssetItem? {
        items.first(where: { $0.id == bestShotId }) ?? items.max(by: { $0.compositeScore < $1.compositeScore })
    }
    
    // MARK: - Reclaimable Bytes
    /// Returns total file size of all items except the Best Shot
    public var reclaimableBytesIfBestKept: Int64 {
        items.filter { $0.id != bestShotId }.reduce(0) { $0 + $1.fileSizeBytes }
    }
    
    /// Returns formatted reclaimable byte size
    public var formattedReclaimableBytes: String {
        ByteCountFormatter.string(fromByteCount: reclaimableBytesIfBestKept, countStyle: .file)
    }
    
    /// Returns total file size of all items in this cluster
    public var totalClusterBytes: Int64 {
        items.reduce(0) { $0 + $1.fileSizeBytes }
    }
    
    // MARK: - Actions
    /// Mark all items except the Best Shot as staged for trash
    public mutating func stageRestExceptBest() {
        for index in items.indices {
            if items[index].id == bestShotId {
                items[index].cullStatus = .keep
            } else {
                items[index].cullStatus = .stagedForTrash
            }
        }
    }
    
    /// Toggle staging status for a specific asset
    public mutating func toggleStagedStatus(for assetId: String) {
        guard let index = items.firstIndex(where: { $0.id == assetId }) else { return }
        if items[index].cullStatus == .stagedForTrash {
            items[index].cullStatus = .unreviewed
        } else {
            items[index].cullStatus = .stagedForTrash
        }
    }
    
    /// Re-assign the Best Shot identifier
    public mutating func setManualBestShot(assetId: String) {
        guard items.contains(where: { $0.id == assetId }) else { return }
        bestShotId = assetId
    }
}
