//
//  SimilarityClusterEngine.swift
//  PureLibrary
//
//  2-Stage Hybrid Photo Clustering Engine:
//  - Stage 1: Fast Temporal Windowing & 64-bit dHash Pre-filtering
//  - Stage 2: Apple Vision VNGenerateImageFeaturePrintRequest on ANE/CPU
//  - Disjoint Set Union (Union-Find) Graph Clustering
//  - Automated Best Shot Selection
//  Strictly ZERO-EMOJI Rule compliant.
//

import Foundation
import CoreGraphics
import Vision

public final class SimilarityClusterEngine: Sendable {
    public static let shared = SimilarityClusterEngine()
    
    public init() {}
    
    // MARK: - Disjoint Set Union (DSU) Structure
    private final class DisjointSetUnion {
        private var parent: [Int: Int] = [:]
        private var rank: [Int: Int] = [:]
        
        init(indices: [Int]) {
            for i in indices {
                parent[i] = i
                rank[i] = 0
            }
        }
        
        func find(_ x: Int) -> Int {
            guard let px = parent[x] else { return x }
            if px != x {
                parent[x] = find(px) // Path compression
            }
            return parent[x] ?? x
        }
        
        func union(_ x: Int, _ y: Int) {
            let rootX = find(x)
            let rootY = find(y)
            if rootX == rootY { return }
            
            let rankX = rank[rootX] ?? 0
            let rankY = rank[rootY] ?? 0
            
            if rankX < rankY {
                parent[rootX] = rootY
            } else if rankX > rankY {
                parent[rootY] = rootX
            } else {
                parent[rootY] = rootX
                rank[rootX] = rankX + 1
            }
        }
    }
    
    // MARK: - Clustering Entry Point
    public func clusterPhotos(
        items: [PhotoAssetItem],
        featurePrints: [String: VNFeaturePrintObservation] = [:],
        timeWindowSeconds: TimeInterval = 60.0,
        maxHammingDistance: Int = 10,
        maxFeatureDistance: Float = 0.40
    ) -> [PhotoClusterGroup] {
        guard items.count >= 2 else { return [] }
        
        // 1. Sort items chronologically
        let sortedItems = items.sorted { $0.creationDate < $1.creationDate }
        let count = sortedItems.count
        let indices = Array(0..<count)
        let dsu = DisjointSetUnion(indices: indices)
        
        // Keep track of pairwise distances for cluster metadata
        var clusterDistances: [Int: [Float]] = [:]
        
        // 2. Stage 1: Windowed Temporal & dHash Scan
        for i in 0..<count {
            let itemA = sortedItems[i]
            
            for j in (i + 1)..<count {
                let itemB = sortedItems[j]
                
                // Temporal cutoff: stop checking subsequent items if outside time window
                let timeDelta = abs(itemB.creationDate.timeIntervalSince(itemA.creationDate))
                let isSameBurst = (itemA.burstIdentifier != nil && itemA.burstIdentifier == itemB.burstIdentifier)
                
                if timeDelta > timeWindowSeconds && !isSameBurst {
                    break
                }
                
                // Check Burst match directly
                if isSameBurst {
                    dsu.union(i, j)
                    continue
                }
                
                // Check dHash Hamming distance
                let dist = PerceptualHashEngine.shared.hammingDistance(itemA.dHash64, itemB.dHash64)
                if dist <= maxHammingDistance {
                    // Candidate pair found: verify with Deep FeaturePrint if available
                    var isSimilar = true
                    var computedDist: Float = Float(dist) / 64.0
                    
                    if let fpA = featurePrints[itemA.id], let fpB = featurePrints[itemB.id] {
                        var visionDistance: Float = 1.0
                        do {
                            try fpA.computeDistance(&visionDistance, to: fpB)
                            computedDist = visionDistance
                            if visionDistance > maxFeatureDistance {
                                isSimilar = false
                            }
                        } catch {
                            // Fallback to dHash decision
                            isSimilar = (dist <= 8)
                        }
                    }
                    
                    if isSimilar {
                        dsu.union(i, j)
                        let root = dsu.find(i)
                        clusterDistances[root, default: []].append(computedDist)
                    }
                }
            }
        }
        
        // 3. Assemble Connected Components
        var components: [Int: [PhotoAssetItem]] = [:]
        for i in 0..<count {
            let root = dsu.find(i)
            components[root, default: []].append(sortedItems[i])
        }
        
        // 4. Form PhotoClusterGroups for clusters with 2 or more photos
        var clusterGroups: [PhotoClusterGroup] = []
        
        for (root, clusterItems) in components where clusterItems.count >= 2 {
            // Determine Best Shot: item with the highest composite score
            let bestShot = clusterItems.max { $0.compositeScore < $1.compositeScore } ?? clusterItems[0]
            
            // Determine Cluster Type
            let isBurst = clusterItems.allSatisfy { $0.burstIdentifier != nil && $0.burstIdentifier == clusterItems.first?.burstIdentifier }
            let allIdenticalHash = clusterItems.allSatisfy { $0.dHash64 == clusterItems[0].dHash64 }
            
            let cType: ClusterType
            if isBurst {
                cType = .burstSequence
            } else if allIdenticalHash {
                cType = .exactDuplicate
            } else {
                cType = .similarAngle
            }
            
            let distances = clusterDistances[root] ?? []
            let avgDist = distances.isEmpty ? 0.15 : (distances.reduce(0.0, +) / Float(distances.count))
            
            // Mark items classification
            var updatedItems = clusterItems
            for idx in updatedItems.indices {
                if updatedItems[idx].id != bestShot.id {
                    updatedItems[idx].classification = .similarDuplicate
                }
            }
            
            let group = PhotoClusterGroup(
                id: UUID().uuidString,
                createdAt: clusterItems.first?.creationDate ?? Date(),
                items: updatedItems,
                bestShotId: bestShot.id,
                clusterType: cType,
                averageSimilarityDistance: avgDist
            )
            clusterGroups.append(group)
        }
        
        // Sort clusters by reclaimable bytes descending (highest savings first)
        return clusterGroups.sorted { $0.reclaimableBytesIfBestKept > $1.reclaimableBytesIfBestKept }
    }
    
    // MARK: - Extract Vision FeaturePrint for an Image
    public func extractFeaturePrint(from cgImage: CGImage) async -> VNFeaturePrintObservation? {
        return await withCheckedContinuation { continuation in
            let request = VNGenerateImageFeaturePrintRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            
            do {
                try handler.perform([request])
                let observation = request.results?.first as? VNFeaturePrintObservation
                continuation.resume(returning: observation)
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}
