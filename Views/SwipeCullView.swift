//
//  SwipeCullView.swift
//  PureLibrary
//
//  Redesigned Full-Screen Swipe & Filmstrip Triage View:
//  - Crisp High-Resolution Photo Display with 2-finger Pinch-to-Zoom (1x - 5x)
//  - Smooth Physics Gesture: Swipe Up or Left to Trash, Swipe Right to Keep
//  - Quick Album Assignment Pill Bar (1-Tap add photo to real iPhone Album)
//  - Bottom Filmstrip Thumbnail Scrubber to jump to any photo in the month/bucket
//  - Instant Undo & Direct Trash Basket Access
//  Strictly ZERO-EMOJI Rule compliant.
//

import SwiftUI
import Photos

public struct SwipeCullView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    public let title: String
    @ObservedObject public var cullViewModel: SwipeCullViewModel
    @ObservedObject public var scannerViewModel: LibraryScannerViewModel
    public let onComplete: ([PhotoAssetItem]) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var dragOffset: CGSize = .zero
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var showTrashSheet: Bool = false
    @State private var showGridSheet: Bool = false
    @State private var albumToastMessage: String? = nil
    @State private var showNewAlbumPrompt: Bool = false
    @State private var newAlbumName: String = ""
    
    @MainActor
    public init(
        title: String = "",
        cullViewModel: SwipeCullViewModel,
        scannerViewModel: LibraryScannerViewModel,
        onComplete: @escaping ([PhotoAssetItem]) -> Void
    ) {
        self.title = title
        self.cullViewModel = cullViewModel
        self.scannerViewModel = scannerViewModel
        self.onComplete = onComplete
    }
    
    public var body: some View {
        ZStack {
            AppTheme.Colors.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 8) {
                // 1. Top Control Bar (Close, Counter, Undo, Grid, Trash Basket)
                topNavigationBar
                
                // 2. Main Interactive High-Res Photo Card Area
                ZStack {
                    if let current = cullViewModel.currentItem {
                        InteractiveSwipePhotoCard(
                            item: current,
                            dragOffset: dragOffset,
                            zoomScale: $zoomScale,
                            lastZoomScale: $lastZoomScale
                        )
                        .offset(x: dragOffset.width, y: dragOffset.height)
                        .rotationEffect(.degrees(Double(dragOffset.width / 22.0)))
                        .gesture(
                            DragGesture(minimumDistance: 14)
                                .onChanged { gesture in
                                    guard zoomScale <= 1.05 else { return }
                                    dragOffset = gesture.translation
                                }
                                .onEnded { gesture in
                                    guard zoomScale <= 1.05 else { return }
                                    handleSwipeEnd(translation: gesture.translation)
                                }
                        )
                    } else {
                        completedQueueView
                    }
                    
                    // Toast confirmation when added to an iPhone Album
                    if let toast = albumToastMessage {
                        VStack {
                            Text(toast)
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(AppTheme.Colors.semanticEmerald)
                                .clipShape(Capsule())
                                .shadow(radius: 8)
                            Spacer()
                        }
                        .padding(.top, 12)
                        .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, AppTheme.Spacing.sm)
                
                if cullViewModel.currentItem != nil {
                    // 3. Quick Album Assignment Bar
                    quickAlbumBar
                    
                    // 4. Bottom Filmstrip Scrubber + Quick Action Buttons
                    bottomFilmstripAndControls
                }
            }
        }
        .sheet(isPresented: $showTrashSheet) {
            NavigationStack {
                TrashStagingView(
                    stagedItems: scannerViewModel.stagedForTrashAssets,
                    onUnstage: { item in
                        scannerViewModel.unstageAssetFromTrash(item)
                        cullViewModel.stagedForTrash.removeAll { $0.id == item.id }
                    },
                    onClearedAfterDeletion: {
                        let deletedIds = Set(scannerViewModel.stagedForTrashAssets.map { $0.id })
                        scannerViewModel.purgeDeletedAssets(ids: deletedIds)
                        cullViewModel.stagedForTrash.removeAll()
                        cullViewModel.allItems.removeAll { deletedIds.contains($0.id) }
                    }
                )
            }
        }
        .alert(loc.t("new_album_prompt_title"), isPresented: $showNewAlbumPrompt) {
            TextField(loc.t("new_album_placeholder"), text: $newAlbumName)
            Button(loc.t("btn_cancel"), role: .cancel) { newAlbumName = "" }
            Button(loc.t("btn_create")) {
                let name = newAlbumName
                newAlbumName = ""
                Task {
                    if let newId = try? await PhotoLibraryService.shared.createAlbum(title: name),
                       let current = cullViewModel.currentItem {
                        _ = try? await PhotoLibraryService.shared.addAssets(assetIds: [current.id], toAlbum: newId)
                        await MainActor.run {
                            scannerViewModel.refreshAlbumsAndUnsorted()
                            triggerAlbumToast("\(loc.t("added_to_album_toast")): \(name)")
                            cullViewModel.swipe(.right)
                        }
                    }
                }
            }
        }
        .onDisappear {
            onComplete(cullViewModel.stagedForTrash)
        }
    }
    
    // MARK: - Top Navigation Bar
    private var topNavigationBar: some View {
        HStack(spacing: 10) {
            // Close Button
            Button {
                onComplete(cullViewModel.stagedForTrash)
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.surfaceRaised)
                        .frame(width: 36, height: 36)
                    VectorIconView(.cross, size: 13, color: AppTheme.Colors.textPrimary)
                }
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(title.isEmpty ? loc.t("swipe_culler_title") : title)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                    .lineLimit(1)
                if !cullViewModel.allItems.isEmpty {
                    Text("\(min(cullViewModel.currentIndex + 1, cullViewModel.allItems.count)) / \(cullViewModel.allItems.count)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                }
            }
            
            Spacer()
            
            // Instant Undo Button
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                    cullViewModel.undoLastAction()
                }
            } label: {
                HStack(spacing: 4) {
                    VectorIconView(.undo, size: 13, color: cullViewModel.canUndo ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary.opacity(0.4))
                    Text(loc.t("btn_undo"))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(cullViewModel.canUndo ? AppTheme.Colors.textPrimary : AppTheme.Colors.textSecondary.opacity(0.4))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(AppTheme.Colors.surfaceRaised)
                .clipShape(Capsule())
            }
            .disabled(!cullViewModel.canUndo)
            .buttonStyle(.plain)
            
            // Trash Basket Button
            Button {
                syncStagedToScanner()
                showTrashSheet = true
            } label: {
                HStack(spacing: 4) {
                    VectorIconView(.trashBin, size: 13, color: AppTheme.Colors.textPrimary)
                    Text("\(cullViewModel.stagedForTrash.count)")
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(cullViewModel.stagedForTrash.isEmpty ? AppTheme.Colors.surfaceRaised : AppTheme.Colors.semanticCrimson)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, 6)
    }
    
    // MARK: - Quick Album Assignment Bar
    private var quickAlbumBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    showNewAlbumPrompt = true
                } label: {
                    HStack(spacing: 4) {
                        Text("+")
                            .font(.system(size: 13, weight: .heavy))
                        Text(loc.t("btn_new_album"))
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(AppTheme.Colors.primaryAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.Colors.primaryAccentGlow)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                ForEach(scannerViewModel.userAlbums.filter { !$0.isSmartAlbum }) { album in
                    Button {
                        assignCurrentPhoto(to: album)
                    } label: {
                        HStack(spacing: 5) {
                            VectorIconView(.duplicateLayers, size: 11, color: AppTheme.Colors.textSecondary)
                            Text(album.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(AppTheme.Colors.surfaceCard)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppTheme.Colors.surfaceBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
        }
    }
    
    // MARK: - Bottom Filmstrip Thumbnail Scrubber & Controls
    private var bottomFilmstripAndControls: some View {
        VStack(spacing: 8) {
            // Horizontal Filmstrip Scrubber
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 6) {
                        ForEach(Array(cullViewModel.allItems.enumerated()), id: \.element.id) { idx, item in
                            let isCurrent = (idx == cullViewModel.currentIndex)
                            let isStaged = cullViewModel.isStaged(item.id)
                            
                            Button {
                                zoomScale = 1.0
                                lastZoomScale = 1.0
                                cullViewModel.jumpTo(index: idx)
                            } label: {
                                ZStack(alignment: .topTrailing) {
                                    PhotoThumbnailView(
                                        item: item,
                                        isBestShot: false,
                                        isStaged: isStaged,
                                        targetSize: CGSize(width: isCurrent ? 52 : 42, height: isCurrent ? 52 : 42),
                                        showOverlayControls: false
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .stroke(
                                                isCurrent ? AppTheme.Colors.primaryAccent : (isStaged ? AppTheme.Colors.semanticCrimson : Color.clear),
                                                lineWidth: isCurrent ? 2.5 : 1.5
                                            )
                                    )
                                    
                                    if isStaged {
                                        Circle()
                                            .fill(AppTheme.Colors.semanticCrimson)
                                            .frame(width: 14, height: 14)
                                            .overlay(
                                                VectorIconView(.trashBin, size: 8, color: AppTheme.Colors.textPrimary)
                                            )
                                            .padding(2)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .id(idx)
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                }
                .frame(height: 56)
                .onChange(of: cullViewModel.currentIndex) { newIdx in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(newIdx, anchor: .center)
                    }
                }
            }
            
            // Action Buttons Row (Trash vs Keep)
            HStack(spacing: AppTheme.Spacing.lg) {
                Button {
                    triggerSwipeAnimation(.up)
                } label: {
                    HStack(spacing: 6) {
                        VectorIconView(.trashBin, size: 16, color: AppTheme.Colors.semanticCrimson)
                        Text(loc.t("btn_stage_short"))
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundColor(AppTheme.Colors.semanticCrimson)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.Colors.surfaceCard)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppTheme.Colors.semanticCrimson.opacity(0.5), lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                
                Button {
                    triggerSwipeAnimation(.right)
                } label: {
                    HStack(spacing: 6) {
                        VectorIconView(.checkmark, size: 16, color: AppTheme.Colors.semanticEmerald)
                        Text(loc.t("btn_keep_short"))
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundColor(AppTheme.Colors.semanticEmerald)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.Colors.surfaceCard)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppTheme.Colors.semanticEmerald.opacity(0.5), lineWidth: 1.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.bottom, 8)
        }
    }
    
    private var completedQueueView: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            VectorIconView(.checkmark, size: 42, color: AppTheme.Colors.semanticEmerald)
            Text(loc.t("swipe_queue_cleaned"))
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(AppTheme.Colors.textPrimary)
            Text("\(cullViewModel.stagedForTrash.count) \(loc.t("swipe_items_staged_sub"))")
                .font(.system(size: 14))
                .foregroundColor(AppTheme.Colors.textSecondary)
            
            if !cullViewModel.stagedForTrash.isEmpty {
                Button {
                    syncStagedToScanner()
                    showTrashSheet = true
                } label: {
                    Text(loc.t("btn_proceed_trash"))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(AppTheme.Colors.semanticCrimson)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            Button {
                onComplete(cullViewModel.stagedForTrash)
                dismiss()
            } label: {
                Text(loc.t("btn_close"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.Colors.textSecondary)
                    .padding(.top, 6)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Gesture Physics Helpers
    private func handleSwipeEnd(translation: CGSize) {
        let horizontalThreshold: CGFloat = 85.0
        let verticalUpThreshold: CGFloat = -85.0
        
        if translation.height < verticalUpThreshold && abs(translation.height) > abs(translation.width) {
            // Swipe Up -> Trash
            triggerSwipeAnimation(.up)
        } else if translation.width < -horizontalThreshold {
            // Swipe Left -> Trash
            triggerSwipeAnimation(.left)
        } else if translation.width > horizontalThreshold {
            // Swipe Right -> Keep
            triggerSwipeAnimation(.right)
        } else {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                dragOffset = .zero
            }
        }
    }
    
    private func triggerSwipeAnimation(_ direction: SwipeDirection) {
        let targetOffset: CGSize
        switch direction {
        case .up:
            targetOffset = CGSize(width: 0, height: -520)
        case .left:
            targetOffset = CGSize(width: -460, height: 0)
        case .right:
            targetOffset = CGSize(width: 460, height: 0)
        }
        
        withAnimation(.easeOut(duration: 0.18)) {
            dragOffset = targetOffset
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            if let current = cullViewModel.currentItem {
                if direction == .left || direction == .up {
                    scannerViewModel.stageAssetForTrash(current)
                } else {
                    scannerViewModel.unstageAssetFromTrash(current)
                }
            }
            cullViewModel.swipe(direction)
            dragOffset = .zero
            zoomScale = 1.0
            lastZoomScale = 1.0
        }
    }
    
    private func assignCurrentPhoto(to album: UserPhotoAlbum) {
        guard let current = cullViewModel.currentItem else { return }
        Task {
            let added = (try? await PhotoLibraryService.shared.addAssets(assetIds: [current.id], toAlbum: album.id)) ?? false
            await MainActor.run {
                if added {
                    scannerViewModel.refreshAlbumsAndUnsorted()
                    triggerAlbumToast("\(loc.t("added_to_album_toast")): \(album.title)")
                    cullViewModel.swipe(.right)
                }
            }
        }
    }
    
    private func triggerAlbumToast(_ msg: String) {
        withAnimation {
            albumToastMessage = msg
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation {
                albumToastMessage = nil
            }
        }
    }
    
    private func syncStagedToScanner() {
        for item in cullViewModel.stagedForTrash {
            scannerViewModel.stageAssetForTrash(item)
        }
    }
}

// MARK: - Interactive High-Res Photo Card with Pinch-to-Zoom
private struct InteractiveSwipePhotoCard: View {
    @ObservedObject private var loc = LocalizationManager.shared
    let item: PhotoAssetItem
    let dragOffset: CGSize
    @Binding var zoomScale: CGFloat
    @Binding var lastZoomScale: CGFloat
    
    @State private var loadedImage: CGImage?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geo in
                ZStack {
                    Color.black
                    
                    if let img = loadedImage {
                        Image(decorative: img, scale: 1.0)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(zoomScale)
                            .gesture(
                                MagnificationGesture()
                                    .onChanged { val in
                                        let delta = val / max(0.01, lastZoomScale)
                                        lastZoomScale = val
                                        zoomScale = min(5.0, max(1.0, zoomScale * delta))
                                    }
                                    .onEnded { _ in
                                        lastZoomScale = 1.0
                                        if zoomScale < 1.05 {
                                            withAnimation(.spring()) { zoomScale = 1.0 }
                                        }
                                    }
                            )
                            .onTapGesture(count: 2) {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                                    if zoomScale > 1.2 {
                                        zoomScale = 1.0
                                        lastZoomScale = 1.0
                                    } else {
                                        zoomScale = 2.5
                                        lastZoomScale = 2.5
                                    }
                                }
                            }
                    } else {
                        ProgressView()
                            .tint(AppTheme.Colors.primaryAccent)
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
            
            // Visual Stamp Overlay during Swipe
            VStack {
                HStack {
                    if dragOffset.width < -35 || dragOffset.height < -35 {
                        Text(loc.t("stamp_stage_trash"))
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppTheme.Colors.semanticCrimson)
                            .clipShape(Capsule())
                            .padding(18)
                    }
                    Spacer()
                    if dragOffset.width > 35 {
                        Text(loc.t("stamp_keep_photo"))
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppTheme.Colors.semanticEmerald)
                            .clipShape(Capsule())
                            .padding(18)
                    }
                }
                Spacer()
            }
            
            // Subtle Bottom Info Pill
            HStack {
                Text(item.creationDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                Spacer()
                
                Text(item.formattedFileSize)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(AppTheme.Colors.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [Color.black.opacity(0.8), Color.clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                .stroke(AppTheme.Colors.surfaceBorder, lineWidth: 1)
        )
        .task(id: item.id) {
            if item.id.hasPrefix("demo_") {
                self.loadedImage = PhotoLibraryService.shared.renderSyntheticImage(for: item.id, width: 800, height: 1000)
                return
            }
            let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [item.id], options: nil)
            if let asset = fetch.firstObject {
                if let thumb = await PhotoLibraryService.shared.loadThumbnailImage(for: asset, targetSize: CGSize(width: 360, height: 360)) {
                    self.loadedImage = thumb
                }
                if let highRes = await PhotoLibraryService.shared.loadFullResolutionImage(for: asset) {
                    self.loadedImage = highRes
                }
            }
        }
    }
}
