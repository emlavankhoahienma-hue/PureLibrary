//
//  ScanCacheService.swift
//  PureLibrary
//
//  Persistent JSON-backed caching layer for analyzed photo assets.
//  Avoids re-processing unchanged photos across app sessions.
//  Strictly ZERO-EMOJI Rule compliant.
//

import Foundation

public struct CachedAssetAnalysis: Codable, Sendable {
    public let assetId: String
    public let modificationTimestamp: TimeInterval
    public let dHash64: UInt64
    public let scores: CachedQualityScores
    public let classification: AssetClassification
    public let fileSizeBytes: Int64
    
    public init(
        assetId: String,
        modificationTimestamp: TimeInterval,
        dHash64: UInt64,
        scores: CachedQualityScores,
        classification: AssetClassification,
        fileSizeBytes: Int64
    ) {
        self.assetId = assetId
        self.modificationTimestamp = modificationTimestamp
        self.dHash64 = dHash64
        self.scores = scores
        self.classification = classification
        self.fileSizeBytes = fileSizeBytes
    }
}

public struct CachedQualityScores: Codable, Sendable {
    public let sharpness: Double
    public let faceQuality: Double
    public let exposure: Double
    public let aesthetic: Double
    public let motionBlur: Double
    public let composite: Double
    public let cpi: Double
    public let isProtectedMemory: Bool
    public let nima: Double
    public let iqa: Double
    
    public init(
        sharpness: Double,
        faceQuality: Double,
        exposure: Double,
        aesthetic: Double,
        motionBlur: Double,
        composite: Double,
        cpi: Double,
        isProtectedMemory: Bool = false,
        nima: Double = 65.0,
        iqa: Double = 70.0
    ) {
        self.sharpness = sharpness
        self.faceQuality = faceQuality
        self.exposure = exposure
        self.aesthetic = aesthetic
        self.motionBlur = motionBlur
        self.composite = composite
        self.cpi = cpi
        self.isProtectedMemory = isProtectedMemory
        self.nima = nima
        self.iqa = iqa
    }
}

public actor ScanCacheService {
    public static let shared = ScanCacheService()
    
    private var cacheTable: [String: CachedAssetAnalysis] = [:]
    private let fileURL: URL
    private var isDirty: Bool = false
    
    public init() {
        let fileManager = FileManager.default
        let directory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        self.fileURL = directory.appendingPathComponent("pure_library_analysis_cache.json")
        Task {
            await self.loadFromDisk()
        }
    }
    
    // MARK: - Read Cache
    public func getCachedAnalysis(assetId: String, modificationTimestamp: TimeInterval) -> CachedAssetAnalysis? {
        guard let entry = cacheTable[assetId] else { return nil }
        // Verify cache freshness: timestamps must match within 1 second
        if abs(entry.modificationTimestamp - modificationTimestamp) < 1.0 {
            return entry
        }
        return nil
    }
    
    // MARK: - Write Cache
    public func storeAnalysis(_ entry: CachedAssetAnalysis) {
        cacheTable[entry.assetId] = entry
        isDirty = true
    }
    
    // MARK: - Persistence
    public func flushToDisk() {
        guard isDirty else { return }
        do {
            let data = try JSONEncoder().encode(cacheTable)
            try data.write(to: fileURL, options: .atomic)
            isDirty = false
        } catch {
            // Silently handle caching write error without logging emoji
        }
    }
    
    public func clearAllCache() {
        cacheTable.removeAll()
        isDirty = false
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    public func clearCache() {
        clearAllCache()
    }
    
    public func fetchCacheCount() -> Int {
        cacheTable.count
    }
    
    public var cachedEntriesCount: Int {
        cacheTable.count
    }
    
    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let loaded = try JSONDecoder().decode([String: CachedAssetAnalysis].self, from: data)
            self.cacheTable = loaded
        } catch {
            self.cacheTable = [:]
        }
    }
}
