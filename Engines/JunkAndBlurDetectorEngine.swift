//
//  JunkAndBlurDetectorEngine.swift
//  PureLibrary
//
//  Specialized Engine for detecting:
//  - Blurry & Out-of-Focus photos (90th-Percentile Block Tenengrad/Laplacian cutoff)
//  - Screenshots & Screen Captures
//  - Receipts, Bills & Document junk via VNRecognizeTextRequest OCR density
//  - Accidental pocket / pitch-black blank frames
//  - Large storage-hogging videos
//  Strictly ZERO-EMOJI Rule compliant.
//

import Foundation
import CoreGraphics
import Vision

public enum BlurSensitivity: String, CaseIterable, Sendable {
    case strict       // Cutoff at 35.0
    case balanced     // Cutoff at 25.0
    case conservative // Cutoff at 15.0
    
    public var cutoffThreshold: Double {
        switch self {
        case .strict: return 35.0
        case .balanced: return 25.0
        case .conservative: return 15.0
        }
    }
}

public final class JunkAndBlurDetectorEngine: Sendable {
    public static let shared = JunkAndBlurDetectorEngine()
    
    public init() {}
    
    // MARK: - Classification Result
    public struct JunkDetectionResult: Sendable {
        public let classification: AssetClassification
        public let junkConfidence: Double
        public let reason: String
        public let isJunkCandidate: Bool
    }
    
    // MARK: - Detect Junk Category
    public func evaluateAsset(
        item: PhotoAssetItem,
        cgImage: CGImage?,
        blurSensitivity: BlurSensitivity = .balanced
    ) async -> JunkDetectionResult {
        // 1. Large Video Check
        if item.isVideo && item.fileSizeBytes > (100 * 1024 * 1024) {
            return JunkDetectionResult(
                classification: .largeVideo,
                junkConfidence: 0.95,
                reason: "Video exceeds 100 MB threshold",
                isJunkCandidate: true
            )
        }
        
        // 2. Screenshot Metadata Flag
        if item.isScreenshot {
            return JunkDetectionResult(
                classification: .screenshotOrReceipt,
                junkConfidence: 0.90,
                reason: "Tagged as iOS screenshot",
                isJunkCandidate: true
            )
        }
        
        // 3. Image Analysis (reuse precomputed Saliency-Weighted scores if available, else compute from cgImage)
        let hasPrecomputedScores = (item.sharpnessScore > 0.0 || item.exposureScore > 0.0)
        
        if let image = cgImage {
            let exposureScore: Double
            let measuredSharpness: Double
            let isMotionBlurred: Bool
            let isDefiniteSharp: Bool
            
            if hasPrecomputedScores {
                exposureScore = item.exposureScore
                measuredSharpness = item.sharpnessScore
                isMotionBlurred = item.motionBlurScore > 0.0
                isDefiniteSharp = measuredSharpness >= 50.0
            } else {
                let exposureMetrics = PhotoQualityScoringEngine.shared.analyzeExposureHistogram(from: image)
                exposureScore = exposureMetrics.score
                let sharpness = PhotoQualityScoringEngine.shared.computeSaliencyWeightedSharpness(
                    from: image,
                    saliencyBox: nil,
                    faceBoxes: []
                )
                measuredSharpness = sharpness.sharpnessScore
                isMotionBlurred = sharpness.isMotionBlurred
                isDefiniteSharp = sharpness.isDefiniteSharp || measuredSharpness >= 50.0
            }
            
            // Check for Blank / Pocket Shot
            if exposureScore <= 5.0 {
                return JunkDetectionResult(
                    classification: .blankPocket,
                    junkConfidence: 0.98,
                    reason: "Pitch-black or blank accidental frame",
                    isJunkCandidate: true
                )
            }
            
            // Anti-False-Blur Rule:
            // Any photo with 90th-percentile block sharpness >= 50.0 or clear face > 45.0 is NEVER flagged as blurry
            let isAntiBlurProtected = isDefiniteSharp || item.faceQualityScore > 45.0 || measuredSharpness >= 50.0 || item.isProtectedMemory
            
            if !isAntiBlurProtected {
                let isBlur = (measuredSharpness < blurSensitivity.cutoffThreshold) || (isMotionBlurred && measuredSharpness < 45.0)
                if isBlur {
                    return JunkDetectionResult(
                        classification: .blurry,
                        junkConfidence: 0.88,
                        reason: isMotionBlurred ? "Directional motion blur detected" : "Subject out of focus",
                        isJunkCandidate: true
                    )
                }
            }
            
            // Check for Receipt / Document OCR Text Density
            let textMetrics = await analyzeOCRTextDensity(on: image)
            if textMetrics.isReceiptOrDocument {
                return JunkDetectionResult(
                    classification: .screenshotOrReceipt,
                    junkConfidence: 0.92,
                    reason: "High OCR text density / receipt detected",
                    isJunkCandidate: true
                )
            }
        }
        
        // Asset appears normal
        return JunkDetectionResult(
            classification: .normal,
            junkConfidence: 0.0,
            reason: "Standard photo",
            isJunkCandidate: false
        )
    }
    
    // MARK: - OCR Text Density Analysis
    public struct OCRMetrics: Sendable {
        public let textLineCount: Int
        public let textCoverageRatio: Double
        public let hasReceiptKeywords: Bool
        public let isReceiptOrDocument: Bool
    }
    
    public func analyzeOCRTextDensity(on cgImage: CGImage) async -> OCRMetrics {
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .fast
            request.usesLanguageCorrection = false
            
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            
            do {
                try handler.perform([request])
                guard let observations = request.results, !observations.isEmpty else {
                    continuation.resume(returning: OCRMetrics(
                        textLineCount: 0,
                        textCoverageRatio: 0.0,
                        hasReceiptKeywords: false,
                        isReceiptOrDocument: false
                    ))
                    return
                }
                
                let lineCount = observations.count
                var totalTextBoundingArea: CGFloat = 0.0
                var fullRecognizedString = ""
                
                for obs in observations {
                    let box = obs.boundingBox
                    totalTextBoundingArea += (box.width * box.height)
                    if let topCandidate = obs.topCandidates(1).first {
                        fullRecognizedString += " " + topCandidate.string.lowercased()
                    }
                }
                
                let coverageRatio = Double(min(1.0, totalTextBoundingArea))
                let receiptKeywords = [
                    "total", "subtotal", "amount", "tax", "vat", "invoice",
                    "receipt", "order", "cash", "payment", "card", "visa",
                    "mastercard", "balance", "thank you", "store",
                    "tổng cộng", "thành tiền", "hóa đơn", "thanh toán", "biên lai"
                ]
                
                var matchedKeywordCount = 0
                for kw in receiptKeywords {
                    if fullRecognizedString.contains(kw) {
                        matchedKeywordCount += 1
                    }
                }
                
                let hasKeywords = matchedKeywordCount >= 2
                let isReceipt = (lineCount >= 10 && coverageRatio > 0.22) || (hasKeywords && lineCount >= 4)
                
                continuation.resume(returning: OCRMetrics(
                    textLineCount: lineCount,
                    textCoverageRatio: coverageRatio,
                    hasReceiptKeywords: hasKeywords,
                    isReceiptOrDocument: isReceipt
                ))
            } catch {
                continuation.resume(returning: OCRMetrics(
                    textLineCount: 0,
                    textCoverageRatio: 0.0,
                    hasReceiptKeywords: false,
                    isReceiptOrDocument: false
                ))
            }
        }
    }
}
