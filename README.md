# PureLibrary (iOS 16+ / 17+)

PureLibrary is an open-source, on-device AI photo culler and storage cleaner for iOS 16+ / 17+.
Developed by **ace4youblade**.

## Key Design Principles
- AI On-Device Neural Engine (Local Privacy Secured): All Apple Vision, CoreGraphics, CoreML, and ANE/Accelerate algorithms execute strictly on-device. Complete personal privacy.
- 90th-Percentile Block Tenengrad/Laplacian: 8x8 block grid isolates subjects from flat sky, wall, or bokeh backgrounds, preventing false blur classification.
- Human-Crafted Monochromatic Dark UI: Monochromatic slate palette with Electric Cobalt Blue (#2563EB) primary accent. Strictly Zero-Emoji UI with custom vector shapes.
- Full-Screen Photo Inspector: High-resolution inspection with 1x-5x pinch-to-zoom, pan drag, swipe navigation, and detailed metrics.
- Runtime Bilingual (Vi/En) & Settings: Instant language switching, blur sensitivity customization (Strict / Balanced / Conservative), cache management, and developer attribution.
- Zero Dead Code Architecture: Every model, engine, service, and view model is strictly wired into the user workflow.

## Architecture

```text
PureLibrary/
├── App/
│   └── PureLibraryApp.swift
├── Theme/
│   ├── AppTheme.swift              # Monochromatic dark theme (#0B0E14, #141923, #2563EB)
│   └── VectorIconLibrary.swift     # Custom vector shapes (Crown, Reticle, Layers, Trash, etc.)
├── Models/
│   ├── PhotoAssetItem.swift        # Asset model with detailed AI quality metrics
│   ├── PhotoClusterGroup.swift     # Similar/duplicate clusters with Best Shot selection
│   └── ScanSummaryReport.swift     # Library aggregate storage statistics
├── Engines/
│   ├── PerceptualHashEngine.swift  # 64-bit dHash and DCT-II pHash
│   ├── SimilarityClusterEngine.swift # 2-stage temporal + deep Vision clustering
│   ├── PhotoQualityScoringEngine.swift # Multi-metric quality scoring & CPI
│   └── JunkAndBlurDetectorEngine.swift # Laplacian blur, OCR receipts, pocket frames
├── Services/
│   ├── PhotoLibraryService.swift   # PhotoKit batching, RAM optimization & deletion
│   └── ScanCacheService.swift      # JSON-backed persistent analysis cache
├── ViewModels/
│   ├── LibraryScannerViewModel.swift # Scanner pipeline coordinator
│   ├── ClusterReviewViewModel.swift  # Cluster inspector & Best Shot review
│   └── SwipeCullViewModel.swift     # Rapid card gesture triage engine
├── Views/
│   ├── DashboardView.swift         # Storage bar, scan trigger, 4 category cards
│   ├── ClusterCompareView.swift    # Side-by-side cluster inspector & 1-tap staging
│   ├── SwipeCullView.swift         # Tinder-style gesture triage deck with live stats
│   ├── TrashStagingView.swift      # Safety confirmation vault before batch deletion
│   └── Components/
│       ├── StorageBar.swift        # Monochromatic disk usage bar
│       ├── MetricBadge.swift       # Vector chip indicator
│       ├── ScoreBreakdownView.swift# Multi-factor score inspection card
│       ├── PhotoThumbnailView.swift# Async thumbnail loader with Best Shot crown
│       └── CategoryCardView.swift  # Dashboard category navigation card
└── tests/
    └── test_pure_library.py        # Empirical numerical test suite
```

## Running Empirical Tests

```bash
python tests/test_pure_library.py
```

## License
Distributed under the [MIT License](LICENSE).

## Author
**Ace4youblade (VanKhoa)**  
Open-source software developer (born 2012) from Hai Phong, Vietnam.  
GitHub: [@emlavankhoahienma-hue](https://github.com/emlavankhoahienma-hue)
