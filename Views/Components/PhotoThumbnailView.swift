//
//  PhotoThumbnailView.swift
//  PureLibrary
//
//  Asynchronous photo thumbnail loader with Best Shot and Staged overlays.
//  Supports synthetic demo rendering and avoids gesture swallowing when onSelect is nil.
//  Strictly ZERO-EMOJI Rule compliant.
//

import SwiftUI
import Photos

public struct PhotoThumbnailView: View {
    public let item: PhotoAssetItem
    public let isBestShot: Bool
    public let isStaged: Bool
    public let targetSize: CGSize
    public let showOverlayControls: Bool
    public let onSelect: (() -> Void)?
    
    @State private var thumbnailImage: CGImage?
    
    public init(
        item: PhotoAssetItem,
        isBestShot: Bool = false,
        isStaged: Bool = false,
        targetSize: CGSize = CGSize(width: 140, height: 140),
        showOverlayControls: Bool = true,
        onSelect: (() -> Void)? = nil
    ) {
        self.item = item
        self.isBestShot = isBestShot
        self.isStaged = isStaged
        self.targetSize = targetSize
        self.showOverlayControls = showOverlayControls
        self.onSelect = onSelect
    }
    
    public var body: some View {
        let baseContent = ZStack(alignment: .topTrailing) {
            // Background / Image content
            Group {
                if let cg = thumbnailImage {
                    Image(decorative: cg, scale: 1.0)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(AppTheme.Colors.surfaceRaised)
                        .overlay(
                            VectorIconView(.sharpnessScan, size: 24, color: AppTheme.Colors.textSecondary.opacity(0.4))
                        )
                }
            }
            .frame(width: targetSize.width, height: targetSize.height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .stroke(
                        isStaged ? AppTheme.Colors.semanticCrimson : (isBestShot ? AppTheme.Colors.primaryAccent : AppTheme.Colors.surfaceBorder),
                        lineWidth: (isStaged || isBestShot) ? 2.0 : 1.0
                    )
            )
            .opacity(isStaged ? 0.45 : 1.0)
            
            // Best Shot Crown Badge (Top-Left)
            if isBestShot && showOverlayControls {
                VStack {
                    HStack {
                        HStack(spacing: 3) {
                            VectorIconView(.crown, size: 10, color: AppTheme.Colors.textPrimary, lineWidth: 2.0)
                            Text("BEST")
                                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(AppTheme.Colors.primaryAccent)
                        .clipShape(Capsule())
                        
                        Spacer()
                    }
                    Spacer()
                }
                .padding(6)
            }
            
            // Staging or Selection Checkmark Indicator + Bottom File Size Tag
            if showOverlayControls {
                VStack {
                    HStack {
                        Spacer()
                        ZStack {
                            Circle()
                                .fill(isStaged ? AppTheme.Colors.semanticCrimson : (isBestShot ? AppTheme.Colors.primaryAccent : AppTheme.Colors.surfaceCard))
                                .frame(width: 24, height: 24)
                            
                            if isStaged {
                                VectorIconView(.trashBin, size: 12, color: AppTheme.Colors.textPrimary)
                            } else if isBestShot {
                                VectorIconView(.checkmark, size: 12, color: AppTheme.Colors.textPrimary)
                            } else {
                                Circle()
                                    .stroke(AppTheme.Colors.textSecondary, lineWidth: 1.5)
                                    .frame(width: 14, height: 14)
                            }
                        }
                    }
                    Spacer()
                    
                    HStack {
                        Text(item.formattedFileSize)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.75))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                        
                        Spacer()
                    }
                }
                .padding(6)
            }
        }
        .frame(width: targetSize.width, height: targetSize.height)
        .contentShape(Rectangle())
        .task(id: item.id) {
            await loadThumbnail()
        }
        
        if let action = onSelect {
            baseContent.onTapGesture {
                action()
            }
        } else {
            baseContent
        }
    }
    
    private func loadThumbnail() async {
        if item.id.hasPrefix("demo_") {
            let synth = PhotoLibraryService.shared.renderSyntheticImage(
                for: item.id,
                width: Int(max(160, targetSize.width * 2)),
                height: Int(max(160, targetSize.height * 2))
            )
            self.thumbnailImage = synth
            return
        }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [item.id], options: nil)
        guard let asset = fetchResult.firstObject else {
            self.thumbnailImage = PhotoLibraryService.shared.renderSyntheticImage(for: item.id, width: 240, height: 240)
            return
        }
        let image = await PhotoLibraryService.shared.loadThumbnailImage(for: asset, targetSize: targetSize)
        self.thumbnailImage = image
    }
}
