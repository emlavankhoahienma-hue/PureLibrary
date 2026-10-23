//
//  SettingsView.swift
//  PureLibrary
//
//  Application Preferences, AI Sensitivity, Cache Management & Developer Info.
//  Supports both standalone sheet presentation and embedded 4th-tab layout.
//  Strictly ZERO-EMOJI Rule compliant.
//

import SwiftUI

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var loc = LocalizationManager.shared
    @ObservedObject public var scannerViewModel: LibraryScannerViewModel
    public let isEmbeddedInTab: Bool
    
    @AppStorage("blur_sensitivity") private var savedSensitivity: String = BlurSensitivity.balanced.rawValue
    @State private var showClearCacheAlert = false
    @State private var cachedItemsCount: Int = 0
    
    public init(scannerViewModel: LibraryScannerViewModel, isEmbeddedInTab: Bool = false) {
        self.scannerViewModel = scannerViewModel
        self.isEmbeddedInTab = isEmbeddedInTab
    }
    
    private var currentSensitivity: BlurSensitivity {
        BlurSensitivity(rawValue: savedSensitivity) ?? .balanced
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.Colors.backgroundPrimary
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppTheme.Spacing.md) {
                        // Section 1: Language
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            Text(loc.t("section_language").uppercased())
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            VStack(spacing: 0) {
                                Button {
                                    loc.setLanguage("vi")
                                    Task {
                                        await scannerViewModel.autoSyncLibraryIfNeeded(forceIncrementalCheck: true)
                                    }
                                } label: {
                                    HStack {
                                        Text(loc.t("lang_vietnamese"))
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(AppTheme.Colors.textPrimary)
                                        Spacer()
                                        if loc.currentLanguage == "vi" {
                                            VectorIconView(.checkmark, size: 14, color: AppTheme.Colors.primaryAccent)
                                        }
                                    }
                                    .padding(.vertical, AppTheme.Spacing.sm)
                                    .padding(.horizontal, AppTheme.Spacing.md)
                                }
                                .buttonStyle(.plain)
                                
                                Divider()
                                    .background(AppTheme.Colors.surfaceBorder)
                                
                                Button {
                                    loc.setLanguage("en")
                                    Task {
                                        await scannerViewModel.autoSyncLibraryIfNeeded(forceIncrementalCheck: true)
                                    }
                                } label: {
                                    HStack {
                                        Text(loc.t("lang_english"))
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(AppTheme.Colors.textPrimary)
                                        Spacer()
                                        if loc.currentLanguage == "en" {
                                            VectorIconView(.checkmark, size: 14, color: AppTheme.Colors.primaryAccent)
                                        }
                                    }
                                    .padding(.vertical, AppTheme.Spacing.sm)
                                    .padding(.horizontal, AppTheme.Spacing.md)
                                }
                                .buttonStyle(.plain)
                            }
                            .pureCard(cornerRadius: AppTheme.Radius.md, padding: 0)
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                        
                        // Section 2: Blur Sensitivity
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            Text(loc.t("section_blur_sensitivity").uppercased())
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                                ForEach(BlurSensitivity.allCases, id: \.self) { sensitivity in
                                    Button {
                                        savedSensitivity = sensitivity.rawValue
                                        scannerViewModel.startScan()
                                    } label: {
                                        HStack(spacing: AppTheme.Spacing.sm) {
                                            ZStack {
                                                Circle()
                                                    .stroke(currentSensitivity == sensitivity ? AppTheme.Colors.primaryAccent : AppTheme.Colors.surfaceBorder, lineWidth: 2)
                                                    .frame(width: 18, height: 18)
                                                if currentSensitivity == sensitivity {
                                                    Circle()
                                                        .fill(AppTheme.Colors.primaryAccent)
                                                        .frame(width: 10, height: 10)
                                                }
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(sensitivityTitle(for: sensitivity))
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(AppTheme.Colors.textPrimary)
                                                
                                                Text(sensitivityDesc(for: sensitivity))
                                                    .font(.system(size: 11))
                                                    .foregroundColor(AppTheme.Colors.textSecondary)
                                            }
                                            Spacer()
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                Divider()
                                    .background(AppTheme.Colors.surfaceBorder)
                                    .padding(.vertical, 4)
                                
                                Button {
                                    if !isEmbeddedInTab {
                                        dismiss()
                                    }
                                    Task {
                                        await scannerViewModel.autoSyncLibraryIfNeeded(forceIncrementalCheck: true)
                                    }
                                } label: {
                                    HStack(spacing: AppTheme.Spacing.xxs) {
                                        VectorIconView(.sharpnessScan, size: 14, color: AppTheme.Colors.textPrimary)
                                        Text(loc.t("btn_rescan_library"))
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(AppTheme.Colors.textPrimary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, AppTheme.Spacing.sm)
                                    .background(AppTheme.Colors.primaryAccent)
                                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                            .pureCard(cornerRadius: AppTheme.Radius.md, padding: AppTheme.Spacing.md)
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                        
                        // Section 3: Cache Management
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            Text(loc.t("section_cache").uppercased())
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            VStack(spacing: AppTheme.Spacing.sm) {
                                HStack {
                                    Text(loc.t("cached_entries"))
                                        .font(.system(size: 13))
                                        .foregroundColor(AppTheme.Colors.textSecondary)
                                    Spacer()
                                    Text("\(cachedItemsCount)")
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundColor(AppTheme.Colors.textPrimary)
                                }
                                
                                Button {
                                    showClearCacheAlert = true
                                } label: {
                                    HStack(spacing: AppTheme.Spacing.xxs) {
                                        VectorIconView(.trashBin, size: 14, color: AppTheme.Colors.semanticCrimson)
                                        Text(loc.t("btn_clear_cache"))
                                            .font(.system(size: 13, weight: .bold, design: .rounded))
                                            .foregroundColor(AppTheme.Colors.semanticCrimson)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, AppTheme.Spacing.sm)
                                    .background(AppTheme.Colors.surfaceRaised)
                                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppTheme.Radius.sm, style: .continuous)
                                            .stroke(AppTheme.Colors.semanticCrimson.opacity(0.4), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .pureCard(cornerRadius: AppTheme.Radius.md, padding: AppTheme.Spacing.md)
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                        
                        // Section 4: Developer Info (Strictly 3 rows: App, Version, Developer)
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            Text(loc.t("section_dev_info").uppercased())
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(AppTheme.Colors.textSecondary)
                            
                            VStack(spacing: AppTheme.Spacing.xs) {
                                devRow(label: loc.t("label_app_name"), value: loc.t("app_name"))
                                devRow(label: loc.t("label_version"), value: loc.t("app_version"))
                                devRow(label: loc.t("label_developer"), value: loc.t("val_developer"), highlight: true)
                            }
                            .pureCard(cornerRadius: AppTheme.Radius.md, padding: AppTheme.Spacing.md)
                        }
                        .padding(.horizontal, AppTheme.Spacing.md)
                        
                        Spacer(minLength: AppTheme.Spacing.xl * 2)
                    }
                    .padding(.vertical, AppTheme.Spacing.md)
                }
            }
            .navigationTitle(loc.t("settings_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppTheme.Colors.backgroundPrimary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if !isEmbeddedInTab {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            VectorIconView(.cross, size: 14, color: AppTheme.Colors.textPrimary)
                        }
                    }
                }
            }
            .task {
                cachedItemsCount = await ScanCacheService.shared.fetchCacheCount()
            }
            .alert(loc.t("btn_clear_cache"), isPresented: $showClearCacheAlert) {
                Button(loc.t("btn_confirm"), role: .destructive) {
                    Task {
                        await ScanCacheService.shared.clearCache()
                        cachedItemsCount = 0
                        await scannerViewModel.autoSyncLibraryIfNeeded(forceIncrementalCheck: true)
                    }
                }
                Button(loc.t("btn_cancel"), role: .cancel) {}
            } message: {
                Text(loc.t("clear_cache_confirm"))
            }
        }
    }
    
    private func devRow(label: String, value: String, highlight: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(AppTheme.Colors.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: highlight ? .heavy : .medium, design: .monospaced))
                .foregroundColor(highlight ? AppTheme.Colors.primaryAccent : AppTheme.Colors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 2)
    }
    
    private func sensitivityTitle(for s: BlurSensitivity) -> String {
        switch s {
        case .strict: return loc.t("blur_strict")
        case .balanced: return loc.t("blur_balanced")
        case .conservative: return loc.t("blur_conservative")
        }
    }
    
    private func sensitivityDesc(for s: BlurSensitivity) -> String {
        switch s {
        case .strict: return loc.t("blur_strict_desc")
        case .balanced: return loc.t("blur_balanced_desc")
        case .conservative: return loc.t("blur_conservative_desc")
        }
    }
}
