//
//  PureLibraryApp.swift
//  PureLibrary
//
//  Main Application Entry Point.
//  Strictly ZERO-EMOJI Rule compliant.
//

import SwiftUI

@main
struct PureLibraryApp: App {
    @StateObject private var scannerViewModel = LibraryScannerViewModel()
    
    var body: some Scene {
        WindowGroup {
            DashboardView(scannerViewModel: scannerViewModel)
                .preferredColorScheme(.dark)
                .background(AppTheme.Colors.backgroundPrimary)
        }
    }
}
