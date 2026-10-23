//
//  LibraryScannerViewModel.swift
//  PureLibrary
//
//  Main orchestrator ViewModel for:
//  - Zero-Click Instant Library Sync & Monthly Timeline Organization
//  - Real-time PHPhotoLibraryChangeObserver updates when new photos are taken
//  - Incremental Background AI Analysis (Cached + Newly Captured Photos)
//  - Native iOS Album Creation & Photo Assignment
//  Strictly ZERO-EMOJI Rule compliant.
//

import SwiftUI
import Photos
import Vision
import Combine

public enum ScanStatus: Equatable, Sendable {
    case idle
    case scanning(stage: String)
    case paused
    case completed
    case error(message: String)
}

@MainActor
public final class LibraryScannerViewModel: ObservableObject {
    @Published public var status: ScanStatus = .idle
    @Published public var progress: Double = 0.0
    @Published public var scannedCount: Int = 0
    @Published public var totalCount: Int = 0
    @Published public var currentStageName: String = "Ready"
    @Published public var photosPerSecond: Double = 0.0
    @Published public var hasPhotoAccess: Bool = false
    
    // Live Scanning Properties (internal compatibility)
    @Published public var currentlyScanningThumbnail: CGImage? = nil
    @Published public var currentlyScanningAssetId: String = ""
    @Published public var currentMeasuredSharpness: Double = 0.0
    @Published public var currentMeasuredClassification: String = ""
    
    // Organize Tab Data (Populated Instantly in < 50ms on App Launch)
    @Published public var allLibraryItems: [PhotoAssetItem] = []
    @Published public var unsortedItems: [PhotoAssetItem] = []
    @Published public var unsortedVideos: [PhotoAssetItem] = []
    @Published public var unsortedScreenshots: [PhotoAssetItem] = []
    @Published public var thisWeekItems: [PhotoAssetItem] = []
    @Published public var randomItems: [PhotoAssetItem] = []
    @Published public var monthlyBuckets: [MonthlyPhotoBucket] = []
    @Published public var userAlbums: [UserPhotoAlbum] = []
    
    // AI Clean Categorized Findings
    @Published public var summaryReport: ScanSummaryReport = ScanSummaryReport()
    @Published public var similarClusters: [PhotoClusterGroup] = []
    @Published public var blurryPhotos: [PhotoAssetItem] = []
    @Published public var screenshotReceipts: [PhotoAssetItem] = []
    @Published public var largeVideos: [PhotoAssetItem] = []
    
    // Staging Basket for Trash Confirmation
    @Published public var stagedForTrashAssets: [PhotoAssetItem] = []
    
    private var scanTask: Task<Void, Never>?
    private var changeObserverCancellable: AnyCancellable?
    private var lastSyncedAssetCount: Int = -1
    private var lastSyncedNewestId: String = ""
    
    private let photoService = PhotoLibraryService.shared
    private let cacheService = ScanCacheService.shared
    private let hashEngine = PerceptualHashEngine.shared
    private let qualityEngine = PhotoQualityScoringEngine.shared
    private let clusterEngine = SimilarityClusterEngine.shared
    private let junkEngine = JunkAndBlurDetectorEngine.shared
    
    public init() {
        refreshStorageStats()
        hasPhotoAccess = photoService.hasAccess
        
        // Listen for live iOS Photo Library changes (e.g., new photo captured or deleted outside app)
        changeObserverCancellable = NotificationCenter.default
            .publisher(for: .photoLibraryDidUpdate)
            .debounce(for: .milliseconds(450), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.autoSyncLibraryIfNeeded(forceIncrementalCheck: true)
                }
            }
    }
    
    // MARK: - Disk Storage Refresh
    public func refreshStorageStats() {
        let (free, total) = photoService.fetchDiskStorageCapacity()
        summaryReport.deviceFreeDiskBytes = free
        summaryReport.deviceTotalDiskBytes = total
    }
    
    // MARK: - Zero-Click Instant Library Sync + Incremental Background AI Scan
    public func autoSyncLibraryIfNeeded(forceIncrementalCheck: Bool = false) async {
        refreshStorageStats()
        let authorized = await photoService.requestAuthorization()
        hasPhotoAccess = authorized
        guard authorized else {
            status = .error(message: "Photo library access not granted.")
            return
        }
        
        let assets = photoService.fetchAllPhotosAndVideos()
        let newestId = assets.first?.localIdentifier ?? ""
        
        // Avoid redundant rebuild if nothing changed and already completed
        if !forceIncrementalCheck && assets.count == lastSyncedAssetCount && newestId == lastSyncedNewestId && !allLibraryItems.isEmpty {
            return
        }
        
        lastSyncedAssetCount = assets.count
        lastSyncedNewestId = newestId
        
        // 1. Instant Metadata & Monthly Grouping (Sub-50ms so UI renders immediately with zero lag!)
        await populateInstantOrganizeData(from: assets)
        
        // 2. Trigger Incremental Background AI Analysis automatically
        startScan()
    }
    
    private func populateInstantOrganizeData(from assets: [PHAsset]) async {
        let (albums, albumedIds) = photoService.fetchUserAlbums()
        self.userAlbums = albums
        
        let calendar = Calendar.current
        let now = Date()
        let oneWeekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now.addingTimeInterval(-604800)
        
        var items: [PhotoAssetItem] = []
        items.reserveCapacity(assets.count)
        
        var monthGroups: [String: (year: Int, month: Int, list: [PhotoAssetItem])] = [:]
        var weekList: [PhotoAssetItem] = []
        var unsortedList: [PhotoAssetItem] = []
        var videoList: [PhotoAssetItem] = []
        var screenshotList: [PhotoAssetItem] = []
        
        for asset in assets {
            let assetId = asset.localIdentifier
            let created = asset.creationDate ?? now
            let fastBytes = photoService.estimateFastByteSize(for: asset)
            let isScreen = asset.mediaSubtypes.contains(.photoScreenshot)
            let isVid = (asset.mediaType == .video)
            
            let item = PhotoAssetItem(
                id: assetId,
                creationDate: created,
                pixelWidth: asset.pixelWidth,
                pixelHeight: asset.pixelHeight,
                fileSizeBytes: fastBytes,
                isFavorite: asset.isFavorite,
                isScreenshot: isScreen,
                isVideo: isVid,
                burstIdentifier: asset.burstIdentifier,
                sharpnessScore: 75.0,
                faceQualityScore: 70.0,
                exposureScore: 80.0,
                aestheticScore: 72.0,
                motionBlurScore: 0.0,
                compositeScore: 76.0,
                cleanupPriorityIndex: 0.5,
                dHash64: 0,
                classification: isScreen ? .screenshotOrReceipt : (isVid && fastBytes > 50_000_000 ? .largeVideo : .normal),
                cullStatus: .unreviewed
            )
            
            items.append(item)
            
            if created >= oneWeekAgo {
                weekList.append(item)
            }
            if !albumedIds.contains(assetId) {
                unsortedList.append(item)
            }
            if isVid {
                videoList.append(item)
            }
            if isScreen {
                screenshotList.append(item)
            }
            
            let comps = calendar.dateComponents([.year, .month], from: created)
            let y = comps.year ?? 2026
            let m = comps.month ?? 1
            let key = String(format: "%04d-%02d", y, m)
            if monthGroups[key] != nil {
                monthGroups[key]?.list.append(item)
            } else {
                monthGroups[key] = (year: y, month: m, list: [item])
            }
        }
        
        // Sort monthly buckets newest first
        let sortedKeys = monthGroups.keys.sorted(by: >)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocalizationManager.shared.currentLanguage == "vi" ? "vi_VN" : "en_US")
        formatter.dateFormat = LocalizationManager.shared.currentLanguage == "vi" ? "'Tháng' M, yyyy" : "MMM yyyy"
        
        var builtBuckets: [MonthlyPhotoBucket] = []
        builtBuckets.reserveCapacity(sortedKeys.count)
        
        for (idx, key) in sortedKeys.enumerated() {
            guard let group = monthGroups[key] else { continue }
            var comps = DateComponents()
            comps.year = group.year
            comps.month = group.month
            comps.day = 1
            let dateObj = calendar.date(from: comps) ?? now
            let rawTitle = formatter.string(from: dateObj)
            let cleanTitle = rawTitle.prefix(1).uppercased() + rawTitle.dropFirst()
            
            builtBuckets.append(
                MonthlyPhotoBucket(
                    id: key,
                    year: group.year,
                    month: group.month,
                    title: cleanTitle,
                    paletteIndex: idx % 6,
                    items: group.list
                )
            )
        }
        
        self.allLibraryItems = items
        self.thisWeekItems = weekList
        self.unsortedItems = unsortedList
        self.unsortedVideos = videoList
        self.unsortedScreenshots = screenshotList
        self.randomItems = Array(items.shuffled().prefix(60))
        self.monthlyBuckets = builtBuckets
        self.totalCount = items.count
    }
    
    public func refreshAlbumsAndUnsorted() {
        let (albums, albumedIds) = photoService.fetchUserAlbums()
        self.userAlbums = albums
        self.unsortedItems = allLibraryItems.filter { !albumedIds.contains($0.id) }
    }
    
    public func reshuffleRandomItems() {
        self.randomItems = Array(allLibraryItems.shuffled().prefix(60))
    }
    
    public func itemsForAlbum(_ album: UserPhotoAlbum) -> [PhotoAssetItem] {
        let ids = Set(photoService.fetchAssetIds(inAlbum: album.id))
        return allLibraryItems.filter { ids.contains($0.id) }
    }
    
    // MARK: - Start / Restart Background Incremental AI Scan
    public func startScan() {
        scanTask?.cancel()
        scanTask = Task {
            await executeScanPipeline()
        }
    }
    
    public func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        status = .idle
        currentStageName = LocalizationManager.shared.t("scan_cancelled")
    }
    
    // Kept for backwards compatibility with any unit test harness
    public func loadSyntheticBenchmarkDataset() {
        startScan()
    }
    
    private struct WorkerScanOutput: Sendable {
        let index: Int
        let item: PhotoAssetItem
        let fileSize: Int64
        let featurePrint: VNFeaturePrintObservation?
    }
    
    private func executeScanPipeline() async {
        let startTime = Date()
        let authorized = await photoService.requestAuthorization()
        hasPhotoAccess = authorized
        guard authorized else {
            status = .error(message: "Photo library access not granted.")
            return
        }
        
        let assets = photoService.fetchAllPhotosAndVideos()
        totalCount = assets.count
        guard totalCount > 0 else {
            status = .completed
            return
        }
        
        if allLibraryItems.isEmpty {
            await populateInstantOrganizeData(from: assets)
        }
        
        status = .scanning(stage: LocalizationManager.shared.t("ai_syncing_badge"))
        currentStageName = LocalizationManager.shared.t("ai_syncing_badge")
        
        let rawSens = UserDefaults.standard.string(forKey: "blur_sensitivity") ?? "balanced"
        let blurSensitivity = BlurSensitivity(rawValue: rawSens) ?? .balanced
        
        var analyzedItems: [PhotoAssetItem] = []
        analyzedItems.reserveCapacity(totalCount)
        var featurePrints: [String: VNFeaturePrintObservation] = [:]
        var totalLibraryBytes: Int64 = 0
        
        let batchSize = 4
        let photoSvc = self.photoService
        let cacheSvc = self.cacheService
        let hashEng = self.hashEngine
        let qualEng = self.qualityEngine
        let junkEng = self.junkEngine
        let clustEng = self.clusterEngine
        
        var batchStartIndex = 0
        while batchStartIndex < totalCount {
            if Task.isCancelled { return }
            let batchEndIndex = min(totalCount, batchStartIndex + batchSize)
            let batchSlice = Array(assets[batchStartIndex..<batchEndIndex].enumerated())
            let baseIdx = batchStartIndex
            let batchStartClock = Date()
            
            let batchOutputs: [WorkerScanOutput] = await withTaskGroup(of: WorkerScanOutput?.self) { group in
                for (offset, asset) in batchSlice {
                    let globalIndex = baseIdx + offset
                    group.addTask {
                        if Task.isCancelled { return nil }
                        let assetId = asset.localIdentifier
                        let modTime = asset.modificationDate?.timeIntervalSince1970 ?? 0
                        
                        if let entry = await cacheSvc.getCachedAnalysis(assetId: assetId, modificationTimestamp: modTime) {
                            var resolvedClass = entry.classification
                            if resolvedClass == .blurry || resolvedClass == .normal {
                                let isProtected = entry.scores.sharpness >= 50.0 || entry.scores.faceQuality > 45.0 || entry.scores.isProtectedMemory
                                if isProtected {
                                    resolvedClass = .normal
                                } else if entry.scores.sharpness < blurSensitivity.cutoffThreshold || (entry.scores.motionBlur > 0 && entry.scores.sharpness < 45.0) {
                                    resolvedClass = .blurry
                                } else {
                                    resolvedClass = .normal
                                }
                            }
                            
                            let cachedItem = PhotoAssetItem(
                                id: assetId,
                                creationDate: asset.creationDate ?? Date(),
                                pixelWidth: asset.pixelWidth,
                                pixelHeight: asset.pixelHeight,
                                fileSizeBytes: entry.fileSizeBytes,
                                isFavorite: asset.isFavorite,
                                isScreenshot: asset.mediaSubtypes.contains(.photoScreenshot),
                                isVideo: asset.mediaType == .video,
                                burstIdentifier: asset.burstIdentifier,
                                sharpnessScore: entry.scores.sharpness,
                                faceQualityScore: entry.scores.faceQuality,
                                exposureScore: entry.scores.exposure,
                                aestheticScore: entry.scores.aesthetic,
                                motionBlurScore: entry.scores.motionBlur,
                                compositeScore: entry.scores.composite,
                                isProtectedMemory: entry.scores.isProtectedMemory,
                                nimaAestheticScore: entry.scores.nima,
                                technicalIqaScore: entry.scores.iqa,
                                cleanupPriorityIndex: entry.scores.cpi,
                                dHash64: entry.dHash64,
                                classification: resolvedClass,
                                cullStatus: .unreviewed
                            )
                            return WorkerScanOutput(
                                index: globalIndex,
                                item: cachedItem,
                                fileSize: entry.fileSizeBytes,
                                featurePrint: nil
                            )
                        } else {
                            let fileSize = photoSvc.calculateAssetByteSize(for: asset)
                            let cgImage = await photoSvc.loadAnalysisImage(for: asset, maxDimension: 512.0)
                            let dHash = cgImage.map { hashEng.computeDHash(from: $0) } ?? 0
                            
                            let scores: DetailedQualityScores
                            if let img = cgImage {
                                scores = await qualEng.analyzeQuality(
                                    cgImage: img,
                                    fileSizeBytes: fileSize,
                                    isFavorite: asset.isFavorite
                                )
                            } else {
                                scores = DetailedQualityScores()
                            }
                            
                            var tempItem = PhotoAssetItem(
                                id: assetId,
                                creationDate: asset.creationDate ?? Date(),
                                pixelWidth: asset.pixelWidth,
                                pixelHeight: asset.pixelHeight,
                                fileSizeBytes: fileSize,
                                isFavorite: asset.isFavorite,
                                isScreenshot: asset.mediaSubtypes.contains(.photoScreenshot),
                                isVideo: asset.mediaType == .video,
                                burstIdentifier: asset.burstIdentifier,
                                sharpnessScore: scores.saliencyWeightedSharpness,
                                faceQualityScore: scores.faceAndEyeQuality,
                                exposureScore: scores.exposureHistogramIntegrity,
                                aestheticScore: scores.nimaScore,
                                motionBlurScore: scores.motionBlurPenalty,
                                compositeScore: scores.compositeScore,
                                isProtectedMemory: scores.isProtectedMemory,
                                nimaAestheticScore: scores.nimaScore,
                                technicalIqaScore: scores.iqaScore,
                                cleanupPriorityIndex: scores.cleanupPriorityIndex,
                                dHash64: dHash,
                                classification: .normal,
                                cullStatus: .unreviewed
                            )
                            
                            let junkResult = await junkEng.evaluateAsset(
                                item: tempItem,
                                cgImage: cgImage,
                                blurSensitivity: blurSensitivity
                            )
                            tempItem.classification = junkResult.classification
                            
                            let cacheEntry = CachedAssetAnalysis(
                                assetId: assetId,
                                modificationTimestamp: modTime,
                                dHash64: dHash,
                                scores: CachedQualityScores(
                                    sharpness: scores.saliencyWeightedSharpness,
                                    faceQuality: scores.faceAndEyeQuality,
                                    exposure: scores.exposureHistogramIntegrity,
                                    aesthetic: scores.nimaScore,
                                    motionBlur: scores.motionBlurPenalty,
                                    composite: scores.compositeScore,
                                    cpi: scores.cleanupPriorityIndex,
                                    isProtectedMemory: scores.isProtectedMemory,
                                    nima: scores.nimaScore,
                                    iqa: scores.iqaScore
                                ),
                                classification: tempItem.classification,
                                fileSizeBytes: fileSize
                            )
                            await cacheSvc.storeAnalysis(cacheEntry)
                            
                            var fpObs: VNFeaturePrintObservation? = nil
                            if let img = cgImage, asset.burstIdentifier != nil || globalIndex % 4 == 0 {
                                fpObs = await clustEng.extractFeaturePrint(from: img)
                            }
                            
                            return WorkerScanOutput(
                                index: globalIndex,
                                item: tempItem,
                                fileSize: fileSize,
                                featurePrint: fpObs
                            )
                        }
                    }
                }
                
                var collected: [WorkerScanOutput] = []
                for await result in group {
                    if let valid = result {
                        collected.append(valid)
                    }
                }
                return collected.sorted { $0.index < $1.index }
            }
            
            if Task.isCancelled { return }
            
            for out in batchOutputs {
                analyzedItems.append(out.item)
                totalLibraryBytes += out.fileSize
                if let fp = out.featurePrint {
                    featurePrints[out.item.id] = fp
                }
            }
            
            scannedCount = analyzedItems.count
            progress = Double(scannedCount) / Double(max(1, totalCount))
            let batchElapsed = Date().timeIntervalSince(batchStartClock)
            if batchElapsed > 0 {
                photosPerSecond = Double(batchOutputs.count) / batchElapsed
            }
            
            // Progressive intermediate UI update every 32 items so user sees AI results immediately
            if scannedCount % 32 == 0 || scannedCount == totalCount {
                applyIncrementalFindings(from: analyzedItems, featurePrints: featurePrints, totalLibraryBytes: totalLibraryBytes)
            }
            
            batchStartIndex = batchEndIndex
        }
        
        if Task.isCancelled { return }
        
        applyIncrementalFindings(from: analyzedItems, featurePrints: featurePrints, totalLibraryBytes: totalLibraryBytes)
        
        // Update accurate scores into allLibraryItems & monthlyBuckets
        let scoreMap = Dictionary(uniqueKeysWithValues: analyzedItems.map { ($0.id, $0) })
        self.allLibraryItems = allLibraryItems.map { scoreMap[$0.id] ?? $0 }
        for bIdx in monthlyBuckets.indices {
            monthlyBuckets[bIdx].items = monthlyBuckets[bIdx].items.map { scoreMap[$0.id] ?? $0 }
        }
        
        let totalDuration = Date().timeIntervalSince(startTime)
        summaryReport.scanDurationSeconds = totalDuration
        summaryReport.photosPerSecond = totalDuration > 0 ? Double(scannedCount) / totalDuration : 0.0
        
        await cacheService.flushToDisk()
        self.status = .completed
        self.currentStageName = LocalizationManager.shared.t("ai_synced_badge")
    }
    
    private func applyIncrementalFindings(
        from analyzedItems: [PhotoAssetItem],
        featurePrints: [String: VNFeaturePrintObservation],
        totalLibraryBytes: Int64
    ) {
        let clusters = clusterEngine.clusterPhotos(items: analyzedItems, featurePrints: featurePrints)
        
        var blurry: [PhotoAssetItem] = []
        var screenshots: [PhotoAssetItem] = []
        var videos: [PhotoAssetItem] = []
        
        for item in analyzedItems {
            switch item.classification {
            case .blurry, .blankPocket:
                blurry.append(item)
            case .screenshotOrReceipt:
                screenshots.append(item)
            case .largeVideo:
                videos.append(item)
            case .normal, .similarDuplicate:
                if item.isVideo && item.fileSizeBytes > 50 * 1024 * 1024 {
                    videos.append(item)
                }
            }
        }
        
        self.similarClusters = clusters
        self.blurryPhotos = blurry.sorted { $0.cleanupPriorityIndex > $1.cleanupPriorityIndex }
        self.screenshotReceipts = screenshots.sorted { $0.fileSizeBytes > $1.fileSizeBytes }
        self.largeVideos = videos.sorted { $0.fileSizeBytes > $1.fileSizeBytes }
        
        summaryReport.totalAssetsScanned = analyzedItems.count
        summaryReport.totalLibrarySizeBytes = totalLibraryBytes
        recalculateSummaryMetrics()
    }
    
    // MARK: - Staging & 1-Tap Smart Cleanup Helpers
    public func stageAssetForTrash(_ item: PhotoAssetItem) {
        guard !stagedForTrashAssets.contains(where: { $0.id == item.id }) else { return }
        var updated = item
        updated.cullStatus = .stagedForTrash
        stagedForTrashAssets.append(updated)
        updateStagedSummary()
    }
    
    public func unstageAssetFromTrash(_ item: PhotoAssetItem) {
        stagedForTrashAssets.removeAll { $0.id == item.id }
        updateStagedSummary()
    }
    
    public func toggleStageAsset(_ item: PhotoAssetItem) {
        if stagedForTrashAssets.contains(where: { $0.id == item.id }) {
            unstageAssetFromTrash(item)
        } else {
            stageAssetForTrash(item)
        }
    }
    
    public func stageEntireClusterExceptBest(_ clusterId: String) {
        guard let clusterIndex = similarClusters.firstIndex(where: { $0.id == clusterId }) else { return }
        similarClusters[clusterIndex].stageRestExceptBest()
        
        for item in similarClusters[clusterIndex].items where item.id != similarClusters[clusterIndex].bestShotId {
            stageAssetForTrash(item)
        }
        updateStagedSummary()
    }
    
    public func stageAllDuplicatesAndBlurry() {
        for cluster in similarClusters {
            for item in cluster.items where item.id != cluster.bestShotId {
                stageAssetForTrash(item)
            }
        }
        for item in blurryPhotos {
            stageAssetForTrash(item)
        }
        updateStagedSummary()
    }
    
    public func stageBatch(_ items: [PhotoAssetItem]) {
        for item in items {
            stageAssetForTrash(item)
        }
        updateStagedSummary()
    }
    
    // MARK: - Post-Deletion Synchronization
    public func purgeDeletedAssets(ids: Set<String>) {
        guard !ids.isEmpty else { return }
        stagedForTrashAssets.removeAll { ids.contains($0.id) }
        allLibraryItems.removeAll { ids.contains($0.id) }
        unsortedItems.removeAll { ids.contains($0.id) }
        unsortedVideos.removeAll { ids.contains($0.id) }
        unsortedScreenshots.removeAll { ids.contains($0.id) }
        thisWeekItems.removeAll { ids.contains($0.id) }
        randomItems.removeAll { ids.contains($0.id) }
        blurryPhotos.removeAll { ids.contains($0.id) }
        screenshotReceipts.removeAll { ids.contains($0.id) }
        largeVideos.removeAll { ids.contains($0.id) }
        
        var updatedBuckets: [MonthlyPhotoBucket] = []
        for var bucket in monthlyBuckets {
            bucket.items.removeAll { ids.contains($0.id) }
            if !bucket.items.isEmpty {
                updatedBuckets.append(bucket)
            }
        }
        monthlyBuckets = updatedBuckets
        
        var updatedClusters: [PhotoClusterGroup] = []
        for var cluster in similarClusters {
            cluster.items.removeAll { ids.contains($0.id) }
            if cluster.items.count >= 2 {
                if !cluster.items.contains(where: { $0.id == cluster.bestShotId }),
                   let newBest = cluster.items.max(by: { $0.compositeScore < $1.compositeScore }) {
                    cluster.bestShotId = newBest.id
                }
                updatedClusters.append(cluster)
            }
        }
        similarClusters = updatedClusters
        
        refreshStorageStats()
        refreshAlbumsAndUnsorted()
        recalculateSummaryMetrics()
    }
    
    private func recalculateSummaryMetrics() {
        let totalReclaimable = similarClusters.reduce(0) { $0 + $1.reclaimableBytesIfBestKept }
                             + blurryPhotos.reduce(0) { $0 + $1.fileSizeBytes }
                             + screenshotReceipts.reduce(0) { $0 + $1.fileSizeBytes }
                             + largeVideos.reduce(0) { $0 + $1.fileSizeBytes }
        
        summaryReport.reclaimableBytes = totalReclaimable
        summaryReport.similarGroupsCount = similarClusters.count
        summaryReport.similarPhotosCount = similarClusters.reduce(0) { $0 + $1.items.count }
        summaryReport.blurryPhotosCount = blurryPhotos.count
        summaryReport.screenshotReceiptsCount = screenshotReceipts.count
        summaryReport.largeVideosCount = largeVideos.count
        updateStagedSummary()
    }
    
    private func updateStagedSummary() {
        summaryReport.stagedPhotosCount = stagedForTrashAssets.count
        summaryReport.stagedBytes = stagedForTrashAssets.reduce(0) { $0 + $1.fileSizeBytes }
    }
}
