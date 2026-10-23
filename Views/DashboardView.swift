//
//  DashboardView.swift
//  PureLibrary
//
//  Main 4-Tab Application Shell:
//  1. Organize Tab: Unsorted/Albums switcher, Random & This Week hero cards,
//     All Unsorted / Videos / Screenshots bars, and Pastel-Slate Monthly Timeline ("Oct 2026", etc.)
//  2. AI Clean Tab: Visual-first Duplicate Clusters, Blurry, Screenshots & Large Videos with 1-tap cleanup
//  3. Albums Tab: Real iPhone PHAssetCollection albums with cover thumbnails & Create New Album
//  4. Settings Tab: Bilingual Vi/En switch, AI sensitivity, cache & developer attribution
//  Automatically syncs & incrementally scans library on launch and foreground return.
//  Strictly ZERO-EMOJI Rule compliant.
//

import SwiftUI

public enum MainAppTab: Int, CaseIterable {
    case organize = 0
    case aiClean = 1
    case albums = 2
    case settings = 3
}

public enum AICleanSegment: Int, CaseIterable {
    case duplicates = 0
    case blurry = 1
    case screenshots = 2
    case largeVideos = 3
}

public struct TriageSessionPayload: Identifiable {
    public let id = UUID()
    public let title: String
    public let items: [PhotoAssetItem]
    public let initialIndex: Int
}

public struct DashboardView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var loc = LocalizationManager.shared
    @ObservedObject public var scannerViewModel: LibraryScannerViewModel
    
    @State private var selectedTab: MainAppTab = .organize
    @State private var activeAICleanSegment: AICleanSegment = .duplicates
    @State private var activeTriageSession: TriageSessionPayload? = nil
    @State private var activeInspectorSession: TriageSessionPayload? = nil
    @State private var showTrashStagingSheet: Bool = false
    @State private var showNewAlbumAlert: Bool = false
    @State private var newAlbumTitle: String = ""
    
    public init(scannerViewModel: LibraryScannerViewModel) {
        self.scannerViewModel = scannerViewModel
    }
    
    private var stagedIdsSet: Set<String> {
        Set(scannerViewModel.stagedForTrashAssets.map { $0.id })
    }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            AppTheme.Colors.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Persistent Header Bar (except Settings tab which has its own header)
                if selectedTab != .settings {
                    topHeaderBar
                }
                
                // Main Content Area for 4 Tabs
                Group {
                    switch selectedTab {
                    case .organize:
                        organizeTabView
                    case .aiClean:
                        aiCleanTabView
                    case .albums:
                        albumsTabView
                    case .settings:
                        SettingsView(scannerViewModel: scannerViewModel, isEmbeddedInTab: true)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Bottom Custom 4-Tab Bar
                bottomTabBar
            }
        }
        .task {
            await scannerViewModel.autoSyncLibraryIfNeeded()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                Task {
                    await scannerViewModel.autoSyncLibraryIfNeeded(forceIncrementalCheck: true)
                }
            }
        }
        .fullScreenCover(item: $activeTriageSession) { session in
            SwipeCullView(
                title: session.title,
                cullViewModel: SwipeCullViewModel(
                    items: session.items,
                    initialIndex: session.initialIndex,
                    preStagedItems: scannerViewModel.stagedForTrashAssets
                ),
                scannerViewModel: scannerViewModel,
                onComplete: { stagedItems in
                    for item in stagedItems {
                        scannerViewModel.stageAssetForTrash(item)
                    }
                }
            )
        }
        .fullScreenCover(item: $activeInspectorSession) { session in
            FullScreenPhotoInspectorView(
                items: session.items,
                initialIndex: session.initialIndex,
                stagedAssetIds: stagedIdsSet,
                onStageToTrash: { item in
                    scannerViewModel.stageAssetForTrash(item)
                },
                onKeep: { item in
                    scannerViewModel.unstageAssetFromTrash(item)
                }
            )
        }
        .sheet(isPresented: $showTrashStagingSheet) {
            NavigationStack {
                TrashStagingView(
                    stagedItems: scannerViewModel.stagedForTrashAssets,
                    onUnstage: { item in
                        scannerViewModel.unstageAssetFromTrash(item)
                    },
                    onClearedAfterDeletion: {
                        let deletedIds = Set(scannerViewModel.stagedForTrashAssets.map { $0.id })
                        scannerViewModel.purgeDeletedAssets(ids: deletedIds)
                    }
                )
            }
        }
        .alert(loc.t("new_album_prompt_title"), isPresented: $showNewAlbumAlert) {
            TextField(loc.t("new_album_placeholder"), text: $newAlbumTitle)
            Button(loc.t("btn_cancel"), role: .cancel) {
                newAlbumTitle = ""
            }
            Button(loc.t("btn_create")) {
                let titleToCreate = newAlbumTitle
                newAlbumTitle = ""
                Task {
                    _ = try? await PhotoLibraryService.shared.createAlbum(title: titleToCreate)
                    await MainActor.run {
                        scannerViewModel.refreshAlbumsAndUnsorted()
                    }
                }
            }
        }
    }
    
    // MARK: - Top Header Bar
    private var topHeaderBar: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            Text(loc.t("app_title"))
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(AppTheme.Colors.textPrimary)
            
            if case .scanning = scannerViewModel.status {
                HStack(spacing: 5) {
                    ProgressView()
                        .scaleEffect(0.65)
                        .tint(AppTheme.Colors.primaryAccent)
                    Text("\(Int(scannerViewModel.progress * 100))%")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(AppTheme.Colors.surfaceRaised)
                .clipShape(Capsule())
            }
            
            Spacer()
            
            // Trash Basket Quick Button
            Button {
                showTrashStagingSheet = true
            } label: {
                HStack(spacing: 5) {
                    VectorIconView(
                        .trashBin,
                        size: 14,
                        color: scannerViewModel.stagedForTrashAssets.isEmpty ? AppTheme.Colors.textSecondary : AppTheme.Colors.textPrimary
                    )
                    Text("\(scannerViewModel.stagedForTrashAssets.count)")
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .foregroundColor(scannerViewModel.stagedForTrashAssets.isEmpty ? AppTheme.Colors.textSecondary : AppTheme.Colors.textPrimary)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    scannerViewModel.stagedForTrashAssets.isEmpty
                        ? AppTheme.Colors.surfaceRaised
                        : AppTheme.Colors.semanticCrimson
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.xs)
        .background(AppTheme.Colors.backgroundPrimary)
    }
    
    // MARK: - TAB 1: ORGANIZE (Monthly Timeline, Random, This Week, Unsorted)
    private var organizeTabView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppTheme.Spacing.md) {
                // Top Segmented Pill Switcher: Unsorted | Albums
                HStack(spacing: 4) {
                    Button {
                        selectedTab = .organize
                    } label: {
                        Text(loc.t("seg_unsorted"))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(AppTheme.Colors.primaryAccent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = .albums
                        }
                    } label: {
                        Text(loc.t("seg_albums"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(4)
                .background(AppTheme.Colors.surfaceCard)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppTheme.Colors.surfaceBorder, lineWidth: 1))
                .padding(.horizontal, AppTheme.Spacing.md)
                
                // Hero Cards: Random & This Week
                HStack(spacing: AppTheme.Spacing.sm) {
                    // Random Card
                    organizeHeroCard(
                        title: loc.t("card_random"),
                        subtitle: loc.t("card_random_sub"),
                        count: scannerViewModel.randomItems.count,
                        coverItem: scannerViewModel.randomItems.first,
                        accentTint: Color(hex: 0x3B82F6),
                        icon: .sparkles
                    ) {
                        scannerViewModel.reshuffleRandomItems()
                        openTriageSession(
                            title: loc.t("card_random"),
                            items: scannerViewModel.randomItems.isEmpty ? scannerViewModel.allLibraryItems : scannerViewModel.randomItems
                        )
                    }
                    
                    // This Week Card
                    organizeHeroCard(
                        title: loc.t("card_this_week"),
                        subtitle: loc.t("card_this_week_sub"),
                        count: scannerViewModel.thisWeekItems.count,
                        coverItem: scannerViewModel.thisWeekItems.first ?? scannerViewModel.allLibraryItems.first,
                        accentTint: Color(hex: 0x10B981),
                        icon: .sharpnessScan
                    ) {
                        openTriageSession(
                            title: loc.t("card_this_week"),
                            items: scannerViewModel.thisWeekItems.isEmpty ? Array(scannerViewModel.allLibraryItems.prefix(30)) : scannerViewModel.thisWeekItems
                        )
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                
                // 3 Rounded Category Bars: All Unsorted, Unsorted Videos, Unsorted Screenshots
                VStack(spacing: AppTheme.Spacing.xs) {
                    organizeWideBar(
                        icon: .duplicateLayers,
                        title: loc.t("row_all_unsorted"),
                        count: scannerViewModel.unsortedItems.count,
                        tintColor: Color(hex: 0x1E293B),
                        accentColor: Color(hex: 0x60A5FA)
                    ) {
                        openTriageSession(title: loc.t("row_all_unsorted"), items: scannerViewModel.unsortedItems)
                    }
                    
                    organizeWideBar(
                        icon: .videoFilm,
                        title: loc.t("row_unsorted_videos"),
                        count: scannerViewModel.unsortedVideos.count,
                        tintColor: Color(hex: 0x231F32),
                        accentColor: Color(hex: 0xA78BFA)
                    ) {
                        openTriageSession(title: loc.t("row_unsorted_videos"), items: scannerViewModel.unsortedVideos)
                    }
                    
                    organizeWideBar(
                        icon: .receiptScan,
                        title: loc.t("row_unsorted_screenshots"),
                        count: scannerViewModel.unsortedScreenshots.count,
                        tintColor: Color(hex: 0x1B2A2A),
                        accentColor: Color(hex: 0x34D399)
                    ) {
                        openTriageSession(title: loc.t("row_unsorted_screenshots"), items: scannerViewModel.unsortedScreenshots)
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                
                // Monthly Timeline Section ("Oct 2026", "Sep 2026", "Aug 2026"...)
                if !scannerViewModel.monthlyBuckets.isEmpty {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                        Text(loc.t("section_monthly_timeline"))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .padding(.horizontal, AppTheme.Spacing.md)
                            .padding(.top, AppTheme.Spacing.xs)
                        
                        LazyVStack(spacing: AppTheme.Spacing.xs) {
                            ForEach(scannerViewModel.monthlyBuckets) { bucket in
                                monthlyBucketRow(bucket: bucket) {
                                    openTriageSession(title: bucket.title, items: bucket.items)
                                }
                            }
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                    }
                } else if !scannerViewModel.hasPhotoAccess {
                    // Permission prompt card if access not yet granted
                    VStack(spacing: AppTheme.Spacing.sm) {
                        VectorIconView(.shieldCheck, size: 32, color: AppTheme.Colors.primaryAccent)
                        Text(loc.t("empty_library_title"))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        Text(loc.t("empty_library_sub"))
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                        Button {
                            Task {
                                await scannerViewModel.autoSyncLibraryIfNeeded(forceIncrementalCheck: true)
                            }
                        } label: {
                            Text(loc.t("btn_grant_access"))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(AppTheme.Colors.primaryAccent)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .pureCard(cornerRadius: AppTheme.Radius.lg, padding: AppTheme.Spacing.lg)
                    .padding(.horizontal, AppTheme.Spacing.md)
                }
                
                Spacer(minLength: AppTheme.Spacing.xl * 2)
            }
            .padding(.top, AppTheme.Spacing.xs)
        }
    }
    
    private func organizeHeroCard(
        title: String,
        subtitle: String,
        count: Int,
        coverItem: PhotoAssetItem?,
        accentTint: Color,
        icon: VectorIconType,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                if let cover = coverItem {
                    PhotoThumbnailView(
                        item: cover,
                        targetSize: CGSize(width: 180, height: 135),
                        showOverlayControls: false
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 135)
                    .clipped()
                    .overlay(
                        LinearGradient(
                            colors: [Color.black.opacity(0.85), Color.black.opacity(0.25)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                } else {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                        .fill(accentTint.opacity(0.18))
                        .frame(height: 135)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        ZStack {
                            Circle()
                                .fill(accentTint.opacity(0.28))
                                .frame(width: 28, height: 28)
                            VectorIconView(icon, size: 14, color: accentTint)
                        }
                        Spacer()
                        Text("\(count)")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    Text(title)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                        .lineLimit(1)
                }
                .padding(AppTheme.Spacing.sm)
            }
            .frame(height: 135)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                    .stroke(accentTint.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func organizeWideBar(
        icon: VectorIconType,
        title: String,
        count: Int,
        tintColor: Color,
        accentColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: AppTheme.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accentColor.opacity(0.18))
                        .frame(width: 36, height: 36)
                    VectorIconView(icon, size: 16, color: accentColor)
                }
                
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Text("\(count)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.28))
                    .clipShape(Capsule())
                
                VectorIconView(.chevron(.right), size: 13, color: AppTheme.Colors.textSecondary)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, 12)
            .background(tintColor)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                    .stroke(accentColor.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func monthlyBucketRow(bucket: MonthlyPhotoBucket, action: @escaping () -> Void) -> some View {
        let bgColors: [Color] = [
            Color(hex: 0x1E2638), // Soft Slate Blue
            Color(hex: 0x262135), // Muted Lavender Slate
            Color(hex: 0x1B2C2B), // Sage Teal Slate
            Color(hex: 0x2B2420), // Warm Terracotta Slate
            Color(hex: 0x1D283A), // Nordic Indigo
            Color(hex: 0x28202B)  // Soft Plum Slate
        ]
        let pillAccents: [Color] = [
            Color(hex: 0x93C5FD),
            Color(hex: 0xC4B5FD),
            Color(hex: 0x6EE7B7),
            Color(hex: 0xFCD34D),
            Color(hex: 0x7DD3FC),
            Color(hex: 0xF9A8D4)
        ]
        let idx = abs(bucket.paletteIndex) % bgColors.count
        let barBg = bgColors[idx]
        let accent = pillAccents[idx]
        
        return Button(action: action) {
            HStack(spacing: AppTheme.Spacing.sm) {
                if let cover = bucket.coverItem {
                    PhotoThumbnailView(
                        item: cover,
                        targetSize: CGSize(width: 42, height: 42),
                        showOverlayControls: false
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                
                Text(bucket.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Text("\(bucket.count)")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.32))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, 10)
            .background(barBg)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                    .stroke(accent.opacity(0.22), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - TAB 2: AI CLEAN (Visual-First Smart Cleanup)
    private var aiCleanTabView: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppTheme.Spacing.md) {
                    // Storage Summary + 1-Tap Smart Cleanup Banner
                    VStack(spacing: AppTheme.Spacing.sm) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(loc.t("reclaimable_capacity"))
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                Text(scannerViewModel.summaryReport.formattedReclaimableBytes)
                                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                                    .foregroundColor(AppTheme.Colors.primaryAccent)
                            }
                            Spacer()
                            
                            if !scannerViewModel.stagedForTrashAssets.isEmpty {
                                Button {
                                    showTrashStagingSheet = true
                                } label: {
                                    HStack(spacing: 6) {
                                        VectorIconView(.trashBin, size: 14, color: AppTheme.Colors.textPrimary)
                                        Text("\(loc.t("btn_delete_staged_now")) (\(scannerViewModel.stagedForTrashAssets.count))")
                                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                                            .foregroundColor(AppTheme.Colors.textPrimary)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(AppTheme.Colors.semanticCrimson)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        // 1-Tap Stage All Duplicates & Blurry Button
                        if !scannerViewModel.similarClusters.isEmpty || !scannerViewModel.blurryPhotos.isEmpty {
                            Button {
                                scannerViewModel.stageAllDuplicatesAndBlurry()
                            } label: {
                                HStack(spacing: 8) {
                                    VectorIconView(.sparkles, size: 14, color: AppTheme.Colors.textPrimary)
                                    Text(loc.t("btn_smart_clean_all"))
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(AppTheme.Colors.primaryAccent)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .pureCard(cornerRadius: AppTheme.Radius.lg, padding: AppTheme.Spacing.md)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    
                    // Category Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            aiFilterPill(
                                segment: .duplicates,
                                label: loc.t("filter_duplicates"),
                                count: scannerViewModel.similarClusters.reduce(0) { $0 + $1.items.count }
                            )
                            aiFilterPill(
                                segment: .blurry,
                                label: loc.t("filter_blurry"),
                                count: scannerViewModel.blurryPhotos.count
                            )
                            aiFilterPill(
                                segment: .screenshots,
                                label: loc.t("filter_screenshots"),
                                count: scannerViewModel.screenshotReceipts.count
                            )
                            aiFilterPill(
                                segment: .largeVideos,
                                label: loc.t("filter_videos"),
                                count: scannerViewModel.largeVideos.count
                            )
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                    }
                    
                    // Visual Content per Segment
                    switch activeAICleanSegment {
                    case .duplicates:
                        duplicatesVisualSection
                    case .blurry:
                        visualPhotoGridSection(items: scannerViewModel.blurryPhotos, title: loc.t("cat_blurry_title"))
                    case .screenshots:
                        visualPhotoGridSection(items: scannerViewModel.screenshotReceipts, title: loc.t("cat_screenshots_title"))
                    case .largeVideos:
                        visualPhotoGridSection(items: scannerViewModel.largeVideos, title: loc.t("cat_videos_title"))
                    }
                    
                    Spacer(minLength: AppTheme.Spacing.xl * 2)
                }
                .padding(.top, AppTheme.Spacing.xs)
            }
        }
    }
    
    private func aiFilterPill(segment: AICleanSegment, label: String, count: Int) -> some View {
        let isSelected = (activeAICleanSegment == segment)
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                activeAICleanSegment = segment
            }
        } label: {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text("\(count)")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.25))
                    .clipShape(Capsule())
            }
            .foregroundColor(isSelected ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? AppTheme.Colors.primaryAccent : AppTheme.Colors.surfaceCard)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isSelected ? Color.clear : AppTheme.Colors.surfaceBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // Visual Duplicate Clusters Section
    private var duplicatesVisualSection: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            if scannerViewModel.similarClusters.isEmpty {
                emptyCleanStateView
            } else {
                ForEach(scannerViewModel.similarClusters) { cluster in
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        // Cluster Header + 1-Tap Keep Best & Trash Rest
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(cluster.items.count) \(loc.t("items_count_suffix")) • \(cluster.formattedReclaimableBytes)")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                Text(cluster.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                            Spacer()
                            
                            Button {
                                scannerViewModel.stageEntireClusterExceptBest(cluster.id)
                            } label: {
                                HStack(spacing: 5) {
                                    VectorIconView(.crown, size: 12, color: AppTheme.Colors.textPrimary)
                                    Text(loc.t("btn_keep_best_clean_rest"))
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(AppTheme.Colors.primaryAccent)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Large Side-by-Side Photo Strip
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(cluster.items.enumerated()), id: \.element.id) { idx, item in
                                    let isBest = (item.id == cluster.bestShotId)
                                    let isStaged = stagedIdsSet.contains(item.id)
                                    
                                    ZStack(alignment: .topLeading) {
                                        Button {
                                            activeInspectorSession = TriageSessionPayload(
                                                title: loc.t("filter_duplicates"),
                                                items: cluster.items,
                                                initialIndex: idx
                                            )
                                        } label: {
                                            PhotoThumbnailView(
                                                item: item,
                                                isBestShot: isBest,
                                                isStaged: isStaged,
                                                targetSize: CGSize(width: 155, height: 195),
                                                showOverlayControls: false
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        
                                        // Top-Left Best or Staged Pill
                                        if isBest {
                                            HStack(spacing: 3) {
                                                VectorIconView(.crown, size: 10, color: AppTheme.Colors.textPrimary)
                                                Text(loc.t("best_badge"))
                                                    .font(.system(size: 9, weight: .heavy))
                                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                            }
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 4)
                                            .background(AppTheme.Colors.semanticEmerald)
                                            .clipShape(Capsule())
                                            .padding(8)
                                        } else if isStaged {
                                            Text(loc.t("staged_badge"))
                                                .font(.system(size: 9, weight: .heavy))
                                                .foregroundColor(AppTheme.Colors.textPrimary)
                                                .padding(.horizontal, 7)
                                                .padding(.vertical, 4)
                                                .background(AppTheme.Colors.semanticCrimson)
                                                .clipShape(Capsule())
                                                .padding(8)
                                        }
                                        
                                        // Bottom-Right Quick Trash Toggle Button
                                        VStack {
                                            Spacer()
                                            HStack {
                                                Text(item.formattedFileSize)
                                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 2)
                                                    .background(Color.black.opacity(0.65))
                                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                                
                                                Spacer()
                                                
                                                Button {
                                                    scannerViewModel.toggleStageAsset(item)
                                                } label: {
                                                    ZStack {
                                                        Circle()
                                                            .fill(isStaged ? AppTheme.Colors.semanticCrimson : Color.black.opacity(0.75))
                                                            .frame(width: 30, height: 30)
                                                        VectorIconView(
                                                            isStaged ? .checkmark : .trashBin,
                                                            size: 13,
                                                            color: AppTheme.Colors.textPrimary
                                                        )
                                                    }
                                                }
                                                .buttonStyle(.plain)
                                            }
                                            .padding(8)
                                        }
                                    }
                                    .frame(width: 155, height: 195)
                                }
                            }
                        }
                    }
                    .pureCard(cornerRadius: AppTheme.Radius.lg, padding: AppTheme.Spacing.md)
                    .padding(.horizontal, AppTheme.Spacing.md)
                }
            }
        }
    }
    
    // Large 2-Column Visual Grid for Blurry / Screenshots / Large Videos
    private func visualPhotoGridSection(items: [PhotoAssetItem], title: String) -> some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            if items.isEmpty {
                emptyCleanStateView
            } else {
                HStack {
                    Button {
                        openTriageSession(title: title, items: items)
                    } label: {
                        HStack(spacing: 6) {
                            VectorIconView(.sparkles, size: 13, color: AppTheme.Colors.primaryAccent)
                            Text(loc.t("swipe_culler_title"))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(AppTheme.Colors.primaryAccent)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(AppTheme.Colors.primaryAccentGlow)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Button {
                        scannerViewModel.stageBatch(items)
                    } label: {
                        HStack(spacing: 5) {
                            VectorIconView(.trashBin, size: 12, color: AppTheme.Colors.textPrimary)
                            Text(loc.t("btn_stage_all_category"))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(AppTheme.Colors.semanticCrimson)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                
                let twoCols = [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ]
                
                LazyVGrid(columns: twoCols, spacing: 10) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                        let isStaged = stagedIdsSet.contains(item.id)
                        
                        ZStack(alignment: .bottom) {
                            Button {
                                activeInspectorSession = TriageSessionPayload(
                                    title: title,
                                    items: items,
                                    initialIndex: idx
                                )
                            } label: {
                                GeometryReader { geo in
                                    PhotoThumbnailView(
                                        item: item,
                                        isBestShot: false,
                                        isStaged: isStaged,
                                        targetSize: CGSize(width: geo.size.width, height: geo.size.width * 1.15),
                                        showOverlayControls: false
                                    )
                                }
                                .aspectRatio(0.86, contentMode: .fit)
                            }
                            .buttonStyle(.plain)
                            
                            HStack {
                                Text(item.formattedFileSize)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.black.opacity(0.7))
                                    .clipShape(Capsule())
                                
                                Spacer()
                                
                                Button {
                                    scannerViewModel.toggleStageAsset(item)
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(isStaged ? AppTheme.Colors.semanticCrimson : Color.black.opacity(0.75))
                                            .frame(width: 32, height: 32)
                                        VectorIconView(isStaged ? .checkmark : .trashBin, size: 14, color: AppTheme.Colors.textPrimary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(8)
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
        }
    }
    
    private var emptyCleanStateView: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            VectorIconView(.checkmark, size: 32, color: AppTheme.Colors.semanticEmerald)
            Text(loc.t("clean_empty_group"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppTheme.Spacing.xl)
    }
    
    // MARK: - TAB 3: ALBUMS (Real iPhone Albums)
    private var albumsTabView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppTheme.Spacing.md) {
                HStack {
                    Text(loc.t("albums_title"))
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                    
                    Spacer()
                    
                    Button {
                        showNewAlbumAlert = true
                    } label: {
                        HStack(spacing: 5) {
                            Text("+")
                                .font(.system(size: 15, weight: .heavy))
                            Text(loc.t("btn_new_album"))
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(AppTheme.Colors.primaryAccent)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                
                if scannerViewModel.userAlbums.isEmpty {
                    VStack(spacing: AppTheme.Spacing.sm) {
                        VectorIconView(.duplicateLayers, size: 34, color: AppTheme.Colors.textSecondary)
                        Text(loc.t("no_albums_title"))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        Text(loc.t("no_albums_sub"))
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, AppTheme.Spacing.xl)
                    .padding(.horizontal, AppTheme.Spacing.md)
                } else {
                    LazyVStack(spacing: AppTheme.Spacing.xs) {
                        ForEach(scannerViewModel.userAlbums) { album in
                            Button {
                                let albumPhotos = scannerViewModel.itemsForAlbum(album)
                                openTriageSession(title: album.title, items: albumPhotos)
                            } label: {
                                HStack(spacing: AppTheme.Spacing.sm) {
                                    if let coverId = album.coverAssetId,
                                       let coverItem = scannerViewModel.allLibraryItems.first(where: { $0.id == coverId }) {
                                        PhotoThumbnailView(
                                            item: coverItem,
                                            targetSize: CGSize(width: 48, height: 48),
                                            showOverlayControls: false
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    } else {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(AppTheme.Colors.surfaceRaised)
                                            .frame(width: 48, height: 48)
                                            .overlay(
                                                VectorIconView(.duplicateLayers, size: 18, color: AppTheme.Colors.primaryAccent)
                                            )
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(album.title)
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundColor(AppTheme.Colors.textPrimary)
                                        Text("\(album.assetCount) \(loc.t("items_count_suffix"))")
                                            .font(.system(size: 12))
                                            .foregroundColor(AppTheme.Colors.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    VectorIconView(.chevron(.right), size: 14, color: AppTheme.Colors.textSecondary)
                                }
                                .pureCard(cornerRadius: AppTheme.Radius.lg, padding: AppTheme.Spacing.sm)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                }
                
                Spacer(minLength: AppTheme.Spacing.xl * 2)
            }
            .padding(.top, AppTheme.Spacing.xs)
        }
    }
    
    // MARK: - Custom 4-Tab Bottom Bar
    private var bottomTabBar: some View {
        HStack(spacing: 0) {
            tabBarItem(tab: .organize, icon: .duplicateLayers, title: loc.t("tab_organize"))
            tabBarItem(tab: .aiClean, icon: .sparkles, title: loc.t("tab_ai_clean"))
            tabBarItem(tab: .albums, icon: .storageMeter, title: loc.t("tab_albums"))
            tabBarItem(tab: .settings, icon: .sliders, title: loc.t("tab_settings"))
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            AppTheme.Colors.surfaceCard
                .overlay(
                    Rectangle()
                        .fill(AppTheme.Colors.surfaceBorder)
                        .frame(height: 1),
                    alignment: .top
                )
        )
    }
    
    private func tabBarItem(tab: MainAppTab, icon: VectorIconType, title: String) -> some View {
        let isSelected = (selectedTab == tab)
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                VectorIconView(
                    icon,
                    size: 18,
                    color: isSelected ? AppTheme.Colors.primaryAccent : AppTheme.Colors.textSecondary
                )
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                    .foregroundColor(isSelected ? AppTheme.Colors.primaryAccent : AppTheme.Colors.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
    
    private func openTriageSession(title: String, items: [PhotoAssetItem], initialIndex: Int = 0) {
        guard !items.isEmpty else { return }
        activeTriageSession = TriageSessionPayload(title: title, items: items, initialIndex: initialIndex)
    }
}
