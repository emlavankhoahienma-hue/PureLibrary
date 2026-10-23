//
//  ScanSummaryReport.swift
//  PureLibrary
//
//  Aggregated statistical report of library analysis and reclaimable storage.
//  Strictly ZERO-EMOJI Rule compliant.
//

import Foundation

public struct ScanSummaryReport: Codable, Hashable, Sendable {
    public var totalAssetsScanned: Int
    public var totalLibrarySizeBytes: Int64
    public var reclaimableBytes: Int64
    
    // Categorical breakdown
    public var similarGroupsCount: Int
    public var similarPhotosCount: Int
    public var blurryPhotosCount: Int
    public var screenshotReceiptsCount: Int
    public var largeVideosCount: Int
    
    // Staging stats
    public var stagedPhotosCount: Int
    public var stagedBytes: Int64
    
    // Performance metrics
    public var scanDurationSeconds: TimeInterval
    public var photosPerSecond: Double
    
    // Device storage context
    public var deviceFreeDiskBytes: Int64
    public var deviceTotalDiskBytes: Int64
    
    public init(
        totalAssetsScanned: Int = 0,
        totalLibrarySizeBytes: Int64 = 0,
        reclaimableBytes: Int64 = 0,
        similarGroupsCount: Int = 0,
        similarPhotosCount: Int = 0,
        blurryPhotosCount: Int = 0,
        screenshotReceiptsCount: Int = 0,
        largeVideosCount: Int = 0,
        stagedPhotosCount: Int = 0,
        stagedBytes: Int64 = 0,
        scanDurationSeconds: TimeInterval = 0.0,
        photosPerSecond: Double = 0.0,
        deviceFreeDiskBytes: Int64 = 0,
        deviceTotalDiskBytes: Int64 = 0
    ) {
        self.totalAssetsScanned = totalAssetsScanned
        self.totalLibrarySizeBytes = totalLibrarySizeBytes
        self.reclaimableBytes = reclaimableBytes
        self.similarGroupsCount = similarGroupsCount
        self.similarPhotosCount = similarPhotosCount
        self.blurryPhotosCount = blurryPhotosCount
        self.screenshotReceiptsCount = screenshotReceiptsCount
        self.largeVideosCount = largeVideosCount
        self.stagedPhotosCount = stagedPhotosCount
        self.stagedBytes = stagedBytes
        self.scanDurationSeconds = scanDurationSeconds
        self.photosPerSecond = photosPerSecond
        self.deviceFreeDiskBytes = deviceFreeDiskBytes
        self.deviceTotalDiskBytes = deviceTotalDiskBytes
    }
    
    // MARK: - Formatted Strings
    public var formattedTotalLibrarySize: String {
        ByteCountFormatter.string(fromByteCount: totalLibrarySizeBytes, countStyle: .file)
    }
    
    public var formattedReclaimableBytes: String {
        ByteCountFormatter.string(fromByteCount: reclaimableBytes, countStyle: .file)
    }
    
    public var formattedStagedBytes: String {
        ByteCountFormatter.string(fromByteCount: stagedBytes, countStyle: .file)
    }
    
    public var formattedDeviceFreeDisk: String {
        ByteCountFormatter.string(fromByteCount: deviceFreeDiskBytes, countStyle: .file)
    }
    
    public var formattedDeviceTotalDisk: String {
        ByteCountFormatter.string(fromByteCount: deviceTotalDiskBytes, countStyle: .file)
    }
    
    public var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: scanDurationSeconds) ?? "\(Int(scanDurationSeconds))s"
    }
    
    public var formattedRate: String {
        String(format: "%.1f photos/sec", photosPerSecond)
    }
    
    public var storageUsedPercentage: Double {
        guard deviceTotalDiskBytes > 0 else { return 0.0 }
        let used = deviceTotalDiskBytes - deviceFreeDiskBytes
        return Double(used) / Double(deviceTotalDiskBytes)
    }
    
    public var reclaimablePercentage: Double {
        guard deviceTotalDiskBytes > 0 else { return 0.0 }
        return Double(reclaimableBytes) / Double(deviceTotalDiskBytes)
    }
}
