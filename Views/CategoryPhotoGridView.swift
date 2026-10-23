//
//  CategoryPhotoGridView.swift
//  PureLibrary
//
//  3-Column Category Photo Grid View:
//  - Multi-selection with Select All / Deselect All
//  - Sharpness score badge overlay per photo
//  - File size indication & Best Shot / Staged status
//  - Tap cell to launch FullScreenPhotoInspectorView with high-res zoom & pan
//  - Batch stage to trash action bar
//  Strictly ZERO-EMOJI Rule compliant.
//

import SwiftUI

public enum CategoryViewType: Equatable {
    case similarClusters
    case blurry
    case screenshots
    case largeVideos
}

public struct CategoryPhotoGridView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    @ObservedObject public var scannerViewModel: LibraryScannerViewModel
    
    public let categoryType: CategoryViewType
    public let categoryTitle: String
    
    @State private var selectedPhotoIds: Set<String> = []
    @State private var inspectingItemIndex: Int? = nil
    @State private var showClusterCompareSheet: Bool = false
    
    public init(
        scannerViewModel: LibraryScannerViewModel,
        categoryType: CategoryViewType,
        categoryTitle: String
    ) {
        self.scannerViewModel = scannerViewModel
        self.categoryType = categoryType
        self.categoryTitle = categoryTitle
    }
    
    private var photoItems: [PhotoAssetItem] {
        switch categoryType {
        case .similarClusters:
            return scannerViewModel.similarClusters.flatMap { $0.items }
        case .blurry:
            return scannerViewModel.blurryPhotos
        case .screenshots:
            return scannerViewModel.screenshotReceipts
        case .largeVideos:
            return scannerViewModel.largeVideos
        }
    }
    
    private var selectedBytes: Int64 {
        photoItems
            .filter { selectedPhotoIds.contains($0.id) }
            .reduce(0) { $0 + $1.fileSizeBytes }
    }
    
    private var stagedIdsSet: Set<String> {
        Set(scannerViewModel.stagedForTrashAssets.map { $0.id })
    }
    
    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]
    
    public var body: some View {
        ZStack {
            AppTheme.Colors.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Action Toolbar (Select All / Deselect All + Cluster Compare shortcut)
                HStack(spacing: AppTheme.Spacing.xs) {
                    Button {
                        if selectedPhotoIds.count == photoItems.count {
                            selectedPhotoIds.removeAll()
                        } else {
                            selectedPhotoIds = Set(photoItems.map { $0.id })
                        }
                    } label: {
                        HStack(spacing: 4) {
                            VectorIconView(selectedPhotoIds.count == photoItems.count && !photoItems.isEmpty ? .checkmark : .duplicateLayers, size: 12, color: AppTheme.Colors.primaryAccent)
                            Text(selectedPhotoIds.count == photoItems.count && !photoItems.isEmpty ? loc.t("grid_deselect_all") : loc.t("grid_select_all"))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(AppTheme.Colors.primaryAccent)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.Colors.primaryAccentGlow)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(photoItems.isEmpty)
                    
                    if categoryType == .similarClusters && !scannerViewModel.similarClusters.isEmpty {
                        Button {
                            showClusterCompareSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                VectorIconView(.crown, size: 11, color: AppTheme.Colors.semanticEmerald)
                                Text(loc.t("cluster_compare_title"))
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(AppTheme.Colors.semanticEmerald)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(AppTheme.Colors.surfaceCard)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Spacer()
                    
                    Text("\(photoItems.count) \(loc.t("items_count_suffix"))")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.xs)
                .background(AppTheme.Colors.surfaceRaised)
                
                // Photo Grid
                if photoItems.isEmpty {
                    Spacer()
                    VStack(spacing: AppTheme.Spacing.sm) {
                        VectorIconView(.sparkles, size: 32, color: AppTheme.Colors.textSecondary)
                        Text(loc.t("no_items_in_category"))
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(Array(photoItems.enumerated()), id: \.element.id) { index, item in
                                let isBest = isBestShotItem(item.id)
                                let isStaged = stagedIdsSet.contains(item.id)
                                
                                ZStack(alignment: .topLeading) {
                                    // Thumbnail cell with tap to open FullScreenPhotoInspectorView
                                    Button {
                                        inspectingItemIndex = index
                                    } label: {
                                        GeometryReader { geo in
                                            PhotoThumbnailView(
                                                item: item,
                                                isBestShot: isBest,
                                                isStaged: isStaged,
                                                targetSize: CGSize(width: geo.size.width, height: geo.size.width),
                                                showOverlayControls: false,
                                                onSelect: nil
                                            )
                                        }
                                        .aspectRatio(1.0, contentMode: .fit)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    // Top-Left Multi-Selection Checkbox
                                    Button {
                                        toggleSelection(for: item.id)
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(selectedPhotoIds.contains(item.id) ? AppTheme.Colors.primaryAccent : Color.black.opacity(0.65))
                                                .frame(width: 24, height: 24)
                                                .overlay(
                                                    Circle().stroke(selectedPhotoIds.contains(item.id) ? AppTheme.Colors.textPrimary : AppTheme.Colors.surfaceBorder, lineWidth: 1.2)
                                                )
                                            
                                            if selectedPhotoIds.contains(item.id) {
                                                VectorIconView(.checkmark, size: 11, color: AppTheme.Colors.textPrimary)
                                            }
                                        }
                                        .padding(6)
                                    }
                                    .buttonStyle(.plain)
                                    
                                    // Top-Right Sharpness Score Badge
                                    VStack {
                                        HStack {
                                            Spacer()
                                            Text("\(Int(item.sharpnessScore))")
                                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                                .foregroundColor(AppTheme.Colors.textPrimary)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(sharpnessColor(item.sharpnessScore))
                                                .clipShape(Capsule())
                                        }
                                        Spacer()
                                    }
                                    .padding(5)
                                    .allowsHitTesting(false)
                                    
                                    // Bottom-Left File Size & Best/Staged Indicator
                                    VStack {
                                        Spacer()
                                        HStack(spacing: 4) {
                                            Text(item.formattedFileSize)
                                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                                .foregroundColor(AppTheme.Colors.textPrimary)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 2)
                                                .background(Color.black.opacity(0.72))
                                                .clipShape(RoundedRectangle(cornerRadius: 3))
                                            
                                            Spacer()
                                            
                                            if isStaged {
                                                VectorIconView(.trashBin, size: 10, color: AppTheme.Colors.semanticCrimson)
                                                    .padding(3)
                                                    .background(Color.black.opacity(0.75))
                                                    .clipShape(Circle())
                                            } else if isBest {
                                                VectorIconView(.crown, size: 10, color: AppTheme.Colors.primaryAccent)
                                                    .padding(3)
                                                    .background(Color.black.opacity(0.75))
                                                    .clipShape(Circle())
                                            }
                                        }
                                    }
                                    .padding(5)
                                    .allowsHitTesting(false)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                        .padding(.bottom, AppTheme.Spacing.xl * 2)
                    }
                }
                
                // Bottom Floating Action Bar
                if !selectedPhotoIds.isEmpty {
                    VStack {
                        Button {
                            stageSelectedToTrash()
                        } label: {
                            HStack(spacing: AppTheme.Spacing.xxs) {
                                VectorIconView(.trashBin, size: 14, color: AppTheme.Colors.textPrimary)
                                Text("\(loc.t("grid_stage_selected")) (\(selectedPhotoIds.count)) - \(ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file))")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(AppTheme.Colors.textPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.Colors.semanticCrimson)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
                            .shadow(color: AppTheme.Colors.semanticCrimson.opacity(0.4), radius: 10, y: 4)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, AppTheme.Spacing.md)
                        .padding(.bottom, AppTheme.Spacing.sm)
                    }
                    .background(AppTheme.Colors.backgroundPrimary.opacity(0.95))
                }
            }
        }
        .navigationTitle(categoryTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.Colors.backgroundPrimary, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showClusterCompareSheet) {
            ClusterCompareView(
                clusterReviewViewModel: ClusterReviewViewModel(clusters: scannerViewModel.similarClusters),
                onStageCluster: { stagedIds in
                    let allClusterItems = scannerViewModel.similarClusters.flatMap { $0.items }
                    for item in allClusterItems where stagedIds.contains(item.id) {
                        scannerViewModel.stageAssetForTrash(item)
                    }
                }
            )
        }
        .fullScreenCover(item: Binding<InspectorIndexWrapper?>(
            get: { inspectingItemIndex.map { InspectorIndexWrapper(index: $0) } },
            set: { inspectingItemIndex = $0?.index }
        )) { wrapper in
            FullScreenPhotoInspectorView(
                items: photoItems,
                initialIndex: wrapper.index,
                stagedAssetIds: stagedIdsSet,
                onStageToTrash: { item in
                    scannerViewModel.stageAssetForTrash(item)
                },
                onKeep: { item in
                    scannerViewModel.unstageAssetFromTrash(item)
                }
            )
        }
    }
    
    private func toggleSelection(for id: String) {
        if selectedPhotoIds.contains(id) {
            selectedPhotoIds.remove(id)
        } else {
            selectedPhotoIds.insert(id)
        }
    }
    
    private func stageSelectedToTrash() {
        for item in photoItems where selectedPhotoIds.contains(item.id) {
            scannerViewModel.stageAssetForTrash(item)
        }
        selectedPhotoIds.removeAll()
    }
    
    private func isBestShotItem(_ id: String) -> Bool {
        scannerViewModel.similarClusters.contains { $0.bestShotId == id }
    }
    
    private func sharpnessColor(_ score: Double) -> Color {
        if score >= 70.0 {
            return AppTheme.Colors.semanticEmerald
        } else if score >= 40.0 {
            return AppTheme.Colors.semanticAmber
        } else {
            return AppTheme.Colors.semanticCrimson
        }
    }
}

private struct InspectorIndexWrapper: Identifiable {
    let index: Int
    var id: Int { index }
}
