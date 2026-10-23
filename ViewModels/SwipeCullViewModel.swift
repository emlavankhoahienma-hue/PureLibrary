//
//  SwipeCullViewModel.swift
//  PureLibrary
//
//  ViewModel powering the Full-Screen Swipe & Filmstrip Triage View:
//  - Supports Swipe Up / Left to Trash, Swipe Right to Keep
//  - Filmstrip index scrubber to jump directly to any photo in a month/category
//  - Instant Undo & Quick Album Assignment
//  Strictly ZERO-EMOJI Rule compliant.
//

import SwiftUI

public enum SwipeDirection: Sendable {
    case left   // Stage for Trash
    case up     // Stage for Trash (Vertical flick)
    case right  // Keep
}

public struct SwipeActionRecord: Sendable {
    public let item: PhotoAssetItem
    public let index: Int
    public let decision: SwipeDirection
    public let timestamp: Date
}

@MainActor
public final class SwipeCullViewModel: ObservableObject {
    @Published public var allItems: [PhotoAssetItem] = []
    @Published public var currentIndex: Int = 0
    @Published public var stagedForTrash: [PhotoAssetItem] = []
    @Published public var keptPhotos: [PhotoAssetItem] = []
    @Published public var actionHistory: [SwipeActionRecord] = []
    
    // Legacy queue compatibility for tests
    public var queue: [PhotoAssetItem] {
        guard currentIndex < allItems.count else { return [] }
        return Array(allItems[currentIndex...])
    }
    
    public init(items: [PhotoAssetItem] = [], initialIndex: Int = 0, preStagedItems: [PhotoAssetItem] = []) {
        self.allItems = items
        self.currentIndex = max(0, min(initialIndex, max(0, items.count - 1)))
        self.stagedForTrash = preStagedItems
    }
    
    // MARK: - Current Card Accessor
    public var currentItem: PhotoAssetItem? {
        guard !allItems.isEmpty, currentIndex >= 0, currentIndex < allItems.count else { return nil }
        return allItems[currentIndex]
    }
    
    public var remainingCount: Int {
        max(0, allItems.count - currentIndex)
    }
    
    public var totalFreedBytes: Int64 {
        stagedForTrash.reduce(0) { $0 + $1.fileSizeBytes }
    }
    
    public var formattedFreedBytes: String {
        ByteCountFormatter.string(fromByteCount: totalFreedBytes, countStyle: .file)
    }
    
    public func isStaged(_ id: String) -> Bool {
        stagedForTrash.contains(where: { $0.id == id })
    }
    
    public func isKept(_ id: String) -> Bool {
        keptPhotos.contains(where: { $0.id == id })
    }
    
    // MARK: - Filmstrip Jump
    public func jumpTo(index: Int) {
        guard index >= 0, index < allItems.count else { return }
        currentIndex = index
    }
    
    // MARK: - Swipe Actions
    public func swipe(_ direction: SwipeDirection) {
        guard let item = currentItem else { return }
        let recordedIdx = currentIndex
        var updated = item
        
        switch direction {
        case .left, .up:
            updated.cullStatus = .stagedForTrash
            if !stagedForTrash.contains(where: { $0.id == updated.id }) {
                stagedForTrash.append(updated)
            }
            keptPhotos.removeAll { $0.id == updated.id }
            actionHistory.append(SwipeActionRecord(item: updated, index: recordedIdx, decision: direction, timestamp: Date()))
        case .right:
            updated.cullStatus = .keep
            if !keptPhotos.contains(where: { $0.id == updated.id }) {
                keptPhotos.append(updated)
            }
            stagedForTrash.removeAll { $0.id == updated.id }
            actionHistory.append(SwipeActionRecord(item: updated, index: recordedIdx, decision: .right, timestamp: Date()))
        }
        
        allItems[recordedIdx] = updated
        advanceToNext()
    }
    
    public func advanceToNext() {
        if currentIndex < allItems.count {
            currentIndex += 1
        }
    }
    
    // MARK: - Instant Undo
    public func undoLastAction() {
        guard let lastAction = actionHistory.popLast() else { return }
        
        switch lastAction.decision {
        case .left, .up:
            stagedForTrash.removeAll { $0.id == lastAction.item.id }
        case .right:
            keptPhotos.removeAll { $0.id == lastAction.item.id }
        }
        
        if lastAction.index >= 0 && lastAction.index < allItems.count {
            var restored = lastAction.item
            restored.cullStatus = .unreviewed
            allItems[lastAction.index] = restored
            currentIndex = lastAction.index
        }
    }
    
    public var canUndo: Bool {
        !actionHistory.isEmpty
    }
}
