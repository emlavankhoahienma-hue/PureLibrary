//
//  TrashStagingView.swift
//  PureLibrary
//
//  Safety Confirmation Vault: Final inspection before PhotoKit batch deletion.
//  Strictly ZERO-EMOJI Rule compliant.
//

import SwiftUI

public struct TrashStagingView: View {
    @ObservedObject private var loc = LocalizationManager.shared
    public let stagedItems: [PhotoAssetItem]
    public let onUnstage: (PhotoAssetItem) -> Void
    public let onClearedAfterDeletion: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var isExecutingDeletion: Bool = false
    @State private var deletionErrorMessage: String?
    @State private var showConfirmAlert: Bool = false
    
    public init(
        stagedItems: [PhotoAssetItem],
        onUnstage: @escaping (PhotoAssetItem) -> Void,
        onClearedAfterDeletion: @escaping () -> Void
    ) {
        self.stagedItems = stagedItems
        self.onUnstage = onUnstage
        self.onClearedAfterDeletion = onClearedAfterDeletion
    }
    
    public var body: some View {
        ZStack {
            AppTheme.Colors.backgroundPrimary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Storage Summary Header
                VStack(spacing: AppTheme.Spacing.xs) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc.t("staged_for_trash_header"))
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            Text(totalStagedFormatted)
                                .font(.system(size: 26, weight: .heavy, design: .monospaced))
                                .foregroundColor(AppTheme.Colors.semanticEmerald)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            VectorIconView(.trashBin, size: 14, color: AppTheme.Colors.semanticCrimson)
                            Text("\(stagedItems.count) \(loc.t("items_count_suffix").uppercased())")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(AppTheme.Colors.textPrimary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.Colors.surfaceRaised)
                        .clipShape(Capsule())
                    }
                    
                    HStack(spacing: AppTheme.Spacing.xxs) {
                        VectorIconView(.shieldCheck, size: 12, color: AppTheme.Colors.textSecondary)
                        Text(loc.t("trash_safety_note"))
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                        Spacer()
                    }
                }
                .padding(AppTheme.Spacing.md)
                .background(AppTheme.Colors.surfaceCard)
                
                // Staged Items Grid
                if stagedItems.isEmpty {
                    Spacer()
                    VStack(spacing: AppTheme.Spacing.md) {
                        VectorIconView(.shieldCheck, size: 36, color: AppTheme.Colors.semanticEmerald)
                        Text(loc.t("trash_empty_title"))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(AppTheme.Colors.textPrimary)
                        Text(loc.t("trash_empty_sub"))
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.Colors.textSecondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 100, maximum: 120), spacing: AppTheme.Spacing.xs)
                            ],
                            spacing: AppTheme.Spacing.xs
                        ) {
                            ForEach(stagedItems) { item in
                                ZStack(alignment: .topTrailing) {
                                    PhotoThumbnailView(
                                        item: item,
                                        isBestShot: false,
                                        isStaged: true,
                                        targetSize: CGSize(width: 105, height: 105),
                                        showOverlayControls: false,
                                        onSelect: {
                                            onUnstage(item)
                                        }
                                    )
                                    
                                    Button {
                                        onUnstage(item)
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(Color.black.opacity(0.8))
                                                .frame(width: 22, height: 22)
                                            VectorIconView(.cross, size: 10, color: AppTheme.Colors.textPrimary)
                                        }
                                    }
                                    .padding(4)
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(AppTheme.Spacing.md)
                    }
                }
                
                // Bottom Destructive Confirmation Bar
                if !stagedItems.isEmpty {
                    VStack(spacing: AppTheme.Spacing.xs) {
                        if let err = deletionErrorMessage {
                            Text(err)
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.Colors.semanticCrimson)
                        }
                        
                        Button {
                            showConfirmAlert = true
                        } label: {
                            HStack(spacing: AppTheme.Spacing.xs) {
                                if isExecutingDeletion {
                                    ProgressView()
                                        .tint(AppTheme.Colors.textPrimary)
                                } else {
                                    VectorIconView(.trashBin, size: 16, color: AppTheme.Colors.textPrimary)
                                    Text("\(loc.t("btn_confirm_delete_prefix")) (\(stagedItems.count))")
                                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                                }
                            }
                            .foregroundColor(AppTheme.Colors.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, AppTheme.Spacing.md)
                            .background(AppTheme.Colors.semanticCrimson)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
                        }
                        .disabled(isExecutingDeletion)
                        .buttonStyle(.plain)
                    }
                    .padding(AppTheme.Spacing.md)
                    .background(AppTheme.Colors.surfaceCard)
                }
            }
        }
        .navigationTitle(loc.t("trash_basket_title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.Colors.backgroundPrimary, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert(loc.t("alert_confirm_delete_title"), isPresented: $showConfirmAlert) {
            Button(loc.t("btn_cancel"), role: .cancel) {}
            Button(loc.t("btn_delete_items"), role: .destructive) {
                executeDeletion()
            }
        } message: {
            Text(loc.t("alert_confirm_delete_msg"))
        }
    }
    
    private var totalStagedBytes: Int64 {
        stagedItems.reduce(0) { $0 + $1.fileSizeBytes }
    }
    
    private var totalStagedFormatted: String {
        ByteCountFormatter.string(fromByteCount: totalStagedBytes, countStyle: .file)
    }
    
    private func executeDeletion() {
        isExecutingDeletion = true
        deletionErrorMessage = nil
        let ids = stagedItems.map { $0.id }
        
        // Synthetic demo items can be purged directly without PhotoKit dialog
        let realIds = ids.filter { !$0.hasPrefix("demo_") }
        if realIds.isEmpty {
            isExecutingDeletion = false
            onClearedAfterDeletion()
            dismiss()
            return
        }
        
        Task {
            do {
                let success = try await PhotoLibraryService.shared.deleteAssets(withIdentifiers: realIds)
                await MainActor.run {
                    isExecutingDeletion = false
                    if success {
                        onClearedAfterDeletion()
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isExecutingDeletion = false
                    deletionErrorMessage = error.localizedDescription
                }
            }
        }
    }
}
