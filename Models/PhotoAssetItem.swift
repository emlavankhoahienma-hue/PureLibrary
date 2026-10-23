//
//  PhotoAssetItem.swift
//  PureLibrary
//
//  Model representing a photo/video asset, monthly timeline buckets, and native iOS albums.
//  Strictly ZERO-EMOJI Rule compliant.
//

import Foundation

public enum AssetClassification: String, Codable, CaseIterable, Sendable {
    case normal = "Normal"
    case similarDuplicate = "Similar / Duplicate"
    case blurry = "Blurry / Out-of-Focus"
    case screenshotOrReceipt = "Screenshot / Receipt"
    case blankPocket = "Blank / Pocket Shot"
    case largeVideo = "Large Video"
    
    public var displayName: String { rawValue }
}

public enum CullDecision: String, Codable, CaseIterable, Sendable {
    case unreviewed = "Unreviewed"
    case keep = "Keep"
    case stagedForTrash = "Staged for Trash"
    case deleted = "Deleted"
}

public struct PhotoAssetItem: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let creationDate: Date
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let fileSizeBytes: Int64
    public let isFavorite: Bool
    public let isScreenshot: Bool
    public let isVideo: Bool
    public let burstIdentifier: String?
    
    // AI Quality Metrics (Range: 0.0 - 100.0)
    public var sharpnessScore: Double
    public var faceQualityScore: Double
    public var exposureScore: Double
    public var aestheticScore: Double
    public var motionBlurScore: Double
    public var compositeScore: Double
    
    // CoreML Neural Engine Metrics
    public var isProtectedMemory: Bool
    public var nimaAestheticScore: Double
    public var technicalIqaScore: Double
    
    // Storage & Prioritization
    public var cleanupPriorityIndex: Double
    public var dHash64: UInt64
    public var classification: AssetClassification
    public var cullStatus: CullDecision
    
    public init(
        id: String,
        creationDate: Date = Date(),
        pixelWidth: Int = 0,
        pixelHeight: Int = 0,
        fileSizeBytes: Int64 = 0,
        isFavorite: Bool = false,
        isScreenshot: Bool = false,
        isVideo: Bool = false,
        burstIdentifier: String? = nil,
        sharpnessScore: Double = 0.0,
        faceQualityScore: Double = 0.0,
        exposureScore: Double = 0.0,
        aestheticScore: Double = 0.0,
        motionBlurScore: Double = 0.0,
        compositeScore: Double = 0.0,
        isProtectedMemory: Bool = false,
        nimaAestheticScore: Double = 0.0,
        technicalIqaScore: Double = 0.0,
        cleanupPriorityIndex: Double = 0.0,
        dHash64: UInt64 = 0,
        classification: AssetClassification = .normal,
        cullStatus: CullDecision = .unreviewed
    ) {
        self.id = id
        self.creationDate = creationDate
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.fileSizeBytes = fileSizeBytes
        self.isFavorite = isFavorite
        self.isScreenshot = isScreenshot
        self.isVideo = isVideo
        self.burstIdentifier = burstIdentifier
        self.sharpnessScore = sharpnessScore
        self.faceQualityScore = faceQualityScore
        self.exposureScore = exposureScore
        self.aestheticScore = aestheticScore
        self.motionBlurScore = motionBlurScore
        self.compositeScore = compositeScore
        self.isProtectedMemory = isProtectedMemory
        self.nimaAestheticScore = nimaAestheticScore
        self.technicalIqaScore = technicalIqaScore
        self.cleanupPriorityIndex = cleanupPriorityIndex
        self.dHash64 = dHash64
        self.classification = classification
        self.cullStatus = cullStatus
    }
    
    public var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }
    
    public var aspectRatio: Double {
        guard pixelHeight > 0 else { return 1.0 }
        return Double(pixelWidth) / Double(pixelHeight)
    }
}

// MARK: - Monthly Timeline Bucket (e.g., "Oct 2026", "Sep 2026")
public struct MonthlyPhotoBucket: Identifiable, Hashable, Sendable {
    public let id: String        // Format: "2026-10"
    public let year: Int
    public let month: Int
    public let title: String     // Localized e.g. "Oct 2026" or "Thg 10, 2026"
    public let paletteIndex: Int // Used for rotating pastel-slate bar styling
    public var items: [PhotoAssetItem]
    
    public var count: Int { items.count }
    public var coverItem: PhotoAssetItem? { items.first }
    public var totalBytes: Int64 { items.reduce(0) { $0 + $1.fileSizeBytes } }
    
    public init(
        id: String,
        year: Int,
        month: Int,
        title: String,
        paletteIndex: Int,
        items: [PhotoAssetItem]
    ) {
        self.id = id
        self.year = year
        self.month = month
        self.title = title
        self.paletteIndex = paletteIndex
        self.items = items
    }
}

// MARK: - Native iPhone Photo Album Model
public struct UserPhotoAlbum: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public var assetCount: Int
    public var coverAssetId: String?
    public let isSmartAlbum: Bool
    
    public init(
        id: String,
        title: String,
        assetCount: Int,
        coverAssetId: String? = nil,
        isSmartAlbum: Bool = false
    ) {
        self.id = id
        self.title = title
        self.assetCount = assetCount
        self.coverAssetId = coverAssetId
        self.isSmartAlbum = isSmartAlbum
    }
}
