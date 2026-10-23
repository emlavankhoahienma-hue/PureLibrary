//
//  FullScreenPhotoInspectorView.swift
//  PureLibrary
//
//  Full-Screen Photo Inspector:
//  - Progressive Thumbnail -> True High-Resolution Loading from PhotoKit
//  - Safe Synthetic Demo Fallback (no invalid empty PHAsset crash)
//  - Interactive Pinch-to-Zoom (1x to 5x) & Pan Gesture isolated from 1x Swipe
//  - Complete Photographic & AI Quality Metadata Panel
//  - Keep & Stage-to-Trash Instant Actions
//  Strictly ZERO-EMOJI Rule compliant.
//

import SwiftUI
import Photos

public struct FullScreenPhotoInspectorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var loc = LocalizationManager.shared
    
    public let items: [PhotoAssetItem]
    @State public var currentIndex: Int
    public let stagedAssetIds: Set<String>
    public let onStageToTrash: (PhotoAssetItem) -> Void
    public let onKeep: ((PhotoAssetItem) -> Void)?
    
    // Zoom & Pan state
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // Image loading
    @State private var highResImage: CGImage?
    @State private var isLoadingHighRes: Bool = false
    @State private var showMetadataDrawer: Bool = true
    @State private var localStagedIds: Set<String>
    
    public init(
        items: [PhotoAssetItem],
        initialIndex: Int = 0,
        stagedAssetIds: Set<String> = [],
        onStageToTrash: @escaping (PhotoAssetItem) -> Void,
        onKeep: ((PhotoAssetItem) -> Void)? = nil
    ) {
        self.items = items
        self._currentIndex = State(initialValue: max(0, min(initialIndex, max(0, items.count - 1))))
        self.stagedAssetIds = stagedAssetIds
        self._localStagedIds = State(initialValue: stagedAssetIds)
        self.onStageToTrash = onStageToTrash
        self.onKeep = onKeep
    }
    
    private var currentItem: PhotoAssetItem? {
        guard !items.isEmpty, currentIndex >= 0, currentIndex < items.count else { return nil }
        return items[currentIndex]
    }
    
    public var body: some View {
        ZStack {
            // Dark Backdrop
            Color.black
                .ignoresSafeArea()
            
            if let item = currentItem {
                // Interactive Zoom & Pan Image Viewer
                GeometryReader { geometry in
                    ZStack {
                        if let cg = highResImage {
                            Image(decorative: cg, scale: 1.0)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .scaleEffect(scale)
                                .offset(offset)
                                .gesture(magnificationGesture)
                                .simultaneousGesture(dragGesture(containerSize: geometry.size))
                                .onTapGesture(count: 2) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                        if scale > 1.2 {
                                            resetZoom()
                                        } else {
                                            scale = 2.75
                                            lastScale = 2.75
                                        }
                                    }
                                }
                        } else {
                            // Loading state
                            VStack(spacing: AppTheme.Spacing.sm) {
                                ProgressView()
                                    .tint(AppTheme.Colors.primaryAccent)
                                    .scaleEffect(1.2)
                                Text(loc.t("inspector_zoom_hint"))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(AppTheme.Colors.textSecondary)
                            }
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                
                // Overlay Controls & Metadata Drawer
                VStack(spacing: 0) {
                    topBar(for: item)
                    
                    Spacer()
                    
                    if showMetadataDrawer {
                        bottomMetadataDrawer(for: item)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            } else {
                VStack(spacing: AppTheme.Spacing.md) {
                    Text(loc.t("no_items_in_category"))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Button(loc.t("btn_close")) {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.Colors.primaryAccent)
                }
            }
        }
        .task(id: currentItem?.id) {
            await loadFullResCurrentItem()
        }
        .onChange(of: items.count) { newCount in
            if newCount == 0 {
                dismiss()
            } else if currentIndex >= newCount {
                currentIndex = max(0, newCount - 1)
            }
        }
    }
    
    // MARK: - Gestures
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / max(0.01, lastScale)
                lastScale = value
                let newScale = scale * delta
                scale = min(5.0, max(1.0, newScale))
            }
            .onEnded { _ in
                lastScale = 1.0
                if scale < 1.05 {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        resetZoom()
                    }
                }
            }
    }
    
    private func dragGesture(containerSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                if scale > 1.05 {
                    let maxOffsetX = (containerSize.width * (scale - 1.0)) / 2.0
                    let maxOffsetY = (containerSize.height * (scale - 1.0)) / 2.0
                    
                    let proposedX = lastOffset.width + value.translation.width
                    let proposedY = lastOffset.height + value.translation.height
                    
                    offset = CGSize(
                        width: min(maxOffsetX, max(-maxOffsetX, proposedX)),
                        height: min(maxOffsetY, max(-maxOffsetY, proposedY))
                    )
                }
            }
            .onEnded { value in
                if scale > 1.05 {
                    lastOffset = offset
                } else {
                    // Horizontal swipe to next / previous photo only when unzoomed (1x)
                    let threshold: CGFloat = 55.0
                    if abs(value.translation.width) > abs(value.translation.height) {
                        if value.translation.width < -threshold, currentIndex < items.count - 1 {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentIndex += 1
                                resetZoom()
                            }
                        } else if value.translation.width > threshold, currentIndex > 0 {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                currentIndex -= 1
                                resetZoom()
                            }
                        }
                    }
                }
            }
    }
    
    private func resetZoom() {
        scale = 1.0
        lastScale = 1.0
        offset = .zero
        lastOffset = .zero
    }
    
    // MARK: - Top Bar
    private func topBar(for item: PhotoAssetItem) -> some View {
        let isStaged = localStagedIds.contains(item.id)
        return HStack {
            // Dismiss button
            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.surfaceRaised.opacity(0.85))
                        .frame(width: 36, height: 36)
                    VectorIconView(.cross, size: 14, color: AppTheme.Colors.textPrimary)
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Photo Counter + Staged Pill
            HStack(spacing: 6) {
                Text("\(currentIndex + 1) / \(items.count)")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(AppTheme.Colors.textPrimary)
                
                if isStaged {
                    Text(loc.t("staged_badge"))
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AppTheme.Colors.semanticCrimson)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(AppTheme.Colors.surfaceRaised.opacity(0.85))
            .clipShape(Capsule())
            
            Spacer()
            
            // Toggle Drawer button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showMetadataDrawer.toggle()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.Colors.surfaceRaised.opacity(0.85))
                        .frame(width: 36, height: 36)
                    VectorIconView(.layers, size: 14, color: showMetadataDrawer ? AppTheme.Colors.primaryAccent : AppTheme.Colors.textPrimary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.top, AppTheme.Spacing.sm)
    }
    
    // MARK: - Bottom Metadata Drawer & Action Buttons
    private func bottomMetadataDrawer(for item: PhotoAssetItem) -> some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            // Sharpness Badge & Quick Metrics
            HStack(spacing: AppTheme.Spacing.sm) {
                HStack(spacing: 4) {
                    VectorIconView(.sharpnessScan, size: 12, color: sharpnessColor(item.sharpnessScore))
                    Text("\(loc.t("sharpness_label")) \(Int(item.sharpnessScore))/100")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundColor(sharpnessColor(item.sharpnessScore))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(sharpnessColor(item.sharpnessScore).opacity(0.15))
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(sharpnessColor(item.sharpnessScore).opacity(0.3), lineWidth: 1)
                )
                
                if item.faceQualityScore > 0 {
                    HStack(spacing: 4) {
                        VectorIconView(.faceDetection, size: 12, color: AppTheme.Colors.primaryAccent)
                        Text("\(loc.t("face_label")) \(Int(item.faceQualityScore))/100")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(AppTheme.Colors.primaryAccent)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.Colors.surfaceRaised)
                    .clipShape(Capsule())
                }
                
                Spacer()
                
                Text(item.formattedFileSize)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(AppTheme.Colors.textPrimary)
            }
            
            // Technical Specs Grid
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc.t("resolution_label"))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Text("\(item.pixelWidth) x \(item.pixelHeight)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(loc.t("exposure_label"))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Text("\(Int(item.exposureScore))/100")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.textPrimary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(loc.t("classification_label"))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(AppTheme.Colors.textSecondary)
                    Text(classificationText(for: item.classification))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(item.classification == .blurry ? AppTheme.Colors.semanticCrimson : AppTheme.Colors.semanticEmerald)
                }
            }
            .padding(.vertical, 4)
            
            // Action Buttons
            HStack(spacing: AppTheme.Spacing.sm) {
                Button {
                    localStagedIds.remove(item.id)
                    onKeep?(item)
                    advanceToNextOrDismiss()
                } label: {
                    HStack(spacing: AppTheme.Spacing.xxs) {
                        VectorIconView(.checkmark, size: 14, color: AppTheme.Colors.textPrimary)
                        Text(loc.t("btn_keep"))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppTheme.Colors.surfaceRaised)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(AppTheme.Colors.surfaceBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                Button {
                    localStagedIds.insert(item.id)
                    onStageToTrash(item)
                    advanceToNextOrDismiss()
                } label: {
                    HStack(spacing: AppTheme.Spacing.xxs) {
                        VectorIconView(.trashBin, size: 14, color: AppTheme.Colors.textPrimary)
                        Text(loc.t("btn_stage_to_trash"))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppTheme.Colors.semanticCrimson)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, AppTheme.Spacing.md)
        .padding(.vertical, AppTheme.Spacing.md)
        .background(
            AppTheme.Colors.backgroundPrimary.opacity(0.95)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
                .shadow(color: Color.black.opacity(0.6), radius: 16, y: -4)
        )
        .padding(.horizontal, AppTheme.Spacing.sm)
        .padding(.bottom, AppTheme.Spacing.sm)
    }
    
    private func advanceToNextOrDismiss() {
        if currentIndex < items.count - 1 {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentIndex += 1
                resetZoom()
            }
        } else {
            dismiss()
        }
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
    
    private func classificationText(for c: AssetClassification) -> String {
        switch c {
        case .normal: return loc.t("status_sharp")
        case .blurry: return loc.t("status_blurry")
        case .similarDuplicate: return loc.t("status_duplicate")
        case .screenshotOrReceipt: return loc.t("status_screenshot")
        case .blankPocket: return loc.t("status_pocket")
        case .largeVideo: return loc.t("cat_videos_title")
        }
    }
    
    private func loadFullResCurrentItem() async {
        guard let item = currentItem else { return }
        isLoadingHighRes = true
        
        if item.id.hasPrefix("demo_") {
            self.highResImage = PhotoLibraryService.shared.renderSyntheticImage(for: item.id, width: 1080, height: 1440)
            isLoadingHighRes = false
            return
        }
        
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [item.id], options: nil)
        if let asset = fetch.firstObject {
            // Progressive: load fast preview first if highResImage is nil, then replace with full 2048px image
            if let fastThumb = await PhotoLibraryService.shared.loadThumbnailImage(for: asset, targetSize: CGSize(width: 360, height: 360)) {
                self.highResImage = fastThumb
            }
            if let fullImg = await PhotoLibraryService.shared.loadFullResolutionImage(for: asset) {
                self.highResImage = fullImg
            }
        } else {
            self.highResImage = PhotoLibraryService.shared.renderSyntheticImage(for: item.id, width: 1080, height: 1440)
        }
        isLoadingHighRes = false
    }
}
