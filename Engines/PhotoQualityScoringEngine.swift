//
//  PhotoQualityScoringEngine.swift
//  PureLibrary
//
//  Multi-criteria AI Photo Quality Scoring Engine:
//  - Saliency-Weighted Laplacian Sharpness (Bokeh-safe)
//  - Directional Motion Blur Analysis
//  - Face Capture Quality & Eye Aspect Ratio (EAR) Blink Detection
//  - Exposure Histogram Integrity (Highlight Clipping & Shadow Crushing)
//  - Aesthetic Composition Harmony & Cleanup Priority Index (CPI)
//  Strictly ZERO-EMOJI Rule compliant.
//

import Foundation
import CoreGraphics
import Vision

#if canImport(UIKit)
import UIKit
#endif

public struct DetailedQualityScores: Sendable {
    public let saliencyWeightedSharpness: Double
    public let faceAndEyeQuality: Double
    public let exposureHistogramIntegrity: Double
    public let aestheticComposition: Double
    public let motionBlurPenalty: Double
    public let compositeScore: Double
    public let cleanupPriorityIndex: Double
    public let isEyesClosedDetected: Bool
    public let isHighlightClipped: Bool
    public let isShadowCrushed: Bool
    public let isMotionBlurred: Bool
    public let isProtectedMemory: Bool
    public let nimaScore: Double
    public let iqaScore: Double
    
    public init(
        saliencyWeightedSharpness: Double = 0.0,
        faceAndEyeQuality: Double = 0.0,
        exposureHistogramIntegrity: Double = 0.0,
        aestheticComposition: Double = 0.0,
        motionBlurPenalty: Double = 0.0,
        compositeScore: Double = 0.0,
        cleanupPriorityIndex: Double = 0.0,
        isEyesClosedDetected: Bool = false,
        isHighlightClipped: Bool = false,
        isShadowCrushed: Bool = false,
        isMotionBlurred: Bool = false,
        isProtectedMemory: Bool = false,
        nimaScore: Double = 65.0,
        iqaScore: Double = 70.0
    ) {
        self.saliencyWeightedSharpness = saliencyWeightedSharpness
        self.faceAndEyeQuality = faceAndEyeQuality
        self.exposureHistogramIntegrity = exposureHistogramIntegrity
        self.aestheticComposition = aestheticComposition
        self.motionBlurPenalty = motionBlurPenalty
        self.compositeScore = compositeScore
        self.cleanupPriorityIndex = cleanupPriorityIndex
        self.isEyesClosedDetected = isEyesClosedDetected
        self.isHighlightClipped = isHighlightClipped
        self.isShadowCrushed = isShadowCrushed
        self.isMotionBlurred = isMotionBlurred
        self.isProtectedMemory = isProtectedMemory
        self.nimaScore = nimaScore
        self.iqaScore = iqaScore
    }
}

public final class PhotoQualityScoringEngine: Sendable {
    public static let shared = PhotoQualityScoringEngine()
    
    public init() {}
    
    // MARK: - Full Analysis from CGImage
    public func analyzeQuality(
        cgImage: CGImage,
        fileSizeBytes: Int64,
        isFavorite: Bool = false
    ) async -> DetailedQualityScores {
        let (width, height) = (cgImage.width, cgImage.height)
        
        // 1. Compute Exposure & Luminance Metrics
        let exposureMetrics = analyzeExposureHistogram(from: cgImage)
        
        // 2. Perform Apple Vision Face & Saliency Requests
        let visionResults = await executeVisionAnalysis(on: cgImage)
        
        // 3. Compute Saliency-Weighted Laplacian Sharpness & Directional Motion Blur
        let sharpnessMetrics = computeSaliencyWeightedSharpness(
            from: cgImage,
            saliencyBox: visionResults.primarySaliencyBox,
            faceBoxes: visionResults.faceBoxes
        )
        
        // 4. Compute Face Quality & EAR Blink Penalty
        let faceEyeScore: Double
        if visionResults.hasFaces {
            var fScore = visionResults.rawFaceQualityScore * 100.0
            if visionResults.isEyesClosed {
                fScore = max(0.0, fScore - 35.0) // Heavy penalty for mid-blink
            }
            faceEyeScore = fScore
        } else {
            // Neutral baseline when no human faces are present (e.g., landscapes, architecture)
            faceEyeScore = (sharpnessMetrics.sharpnessScore * 0.6) + (exposureMetrics.score * 0.4)
        }
        
        // 5. Neural Engine Evaluations (NIMA Aesthetic, Technical IQA, Semantic Zero-Shot)
        let nima = await CoreMLNeuralEngineService.shared.analyzeAestheticNIMA(cgImage: cgImage)
        let iqa = await CoreMLNeuralEngineService.shared.analyzeTechnicalIQA(
            cgImage: cgImage,
            laplacianSharpness: sharpnessMetrics.sharpnessScore
        )
        let semantic = await CoreMLNeuralEngineService.shared.analyzeSemanticContext(cgImage: cgImage)
        
        // 6. Motion Blur Penalty (Protected: architecture & horizons with sharpness >= 58.0 never penalized)
        let isAntiBlurProtected = sharpnessMetrics.isDefiniteSharp || (visionResults.hasFaces && visionResults.rawFaceQualityScore > 0.55)
        let isMotion = !isAntiBlurProtected && (sharpnessMetrics.isMotionBlurred || (iqa.motionBlurSeverity > 65.0 && sharpnessMetrics.sharpnessScore < 58.0))
        let motionBlurPenalty = isMotion ? 25.0 : 0.0
        
        // 7. Rebalanced Hybrid Scoring (85% Physical Measurements + 15% Neural Advisor)
        // Physical real measurements: Block Sharpness (45%), Face Quality/EAR (25%), Exposure (15%) = 85%
        // Neural Engine advisor: NIMA Aesthetic (10%), Technical IQA (5%) = 15%
        let physicalScore: Double
        if visionResults.hasFaces {
            physicalScore = (0.45 * sharpnessMetrics.sharpnessScore)
                          + (0.25 * faceEyeScore)
                          + (0.15 * exposureMetrics.score)
        } else {
            physicalScore = (0.55 * sharpnessMetrics.sharpnessScore)
                          + (0.30 * exposureMetrics.score)
        }
        let neuralScore = (0.10 * nima.normalizedScore) + (0.05 * iqa.overallTechnicalScore)
        
        var composite = physicalScore + neuralScore - motionBlurPenalty
        if semantic.isProtectedMemory {
            composite = min(100.0, composite + 8.0)
        }
        if isFavorite {
            composite = min(100.0, composite + 5.0)
        }
        composite = max(0.0, min(100.0, composite))
        
        // 8. Cleanup Priority Index (CPI)
        // High CPI = Large file with low quality, prime target for reclaiming storage
        let fileSizeMB = Double(fileSizeBytes) / (1024.0 * 1024.0)
        let qualityDeficit = max(0.05, 1.0 - (composite / 100.0))
        let junkMultiplier: Double = (sharpnessMetrics.sharpnessScore < 25.0 || visionResults.isEyesClosed || exposureMetrics.isClipped || semantic.isJunk) ? 1.8 : 1.0
        // Memory Shield items have heavily dampened CPI so they are never prioritized for deletion
        let finalMultiplier = semantic.isProtectedMemory ? 0.1 : junkMultiplier
        let cpi = fileSizeMB * qualityDeficit * finalMultiplier
        
        return DetailedQualityScores(
            saliencyWeightedSharpness: sharpnessMetrics.sharpnessScore,
            faceAndEyeQuality: faceEyeScore,
            exposureHistogramIntegrity: exposureMetrics.score,
            aestheticComposition: nima.normalizedScore,
            motionBlurPenalty: motionBlurPenalty,
            compositeScore: composite,
            cleanupPriorityIndex: cpi,
            isEyesClosedDetected: visionResults.isEyesClosed,
            isHighlightClipped: exposureMetrics.isClipped,
            isShadowCrushed: exposureMetrics.isCrushed,
            isMotionBlurred: isMotion,
            isProtectedMemory: semantic.isProtectedMemory,
            nimaScore: nima.normalizedScore,
            iqaScore: iqa.overallTechnicalScore
        )
    }
    
    // MARK: - 90th-Percentile Block Tenengrad/Laplacian Sharpness
    public struct SharpnessResult: Sendable {
        public let sharpnessScore: Double
        public let directionalRatio: Double
        public let isMotionBlurred: Bool
        public let isDefiniteSharp: Bool
        public let topBlockEnergy: Double
        
        public init(
            sharpnessScore: Double,
            directionalRatio: Double,
            isMotionBlurred: Bool,
            isDefiniteSharp: Bool = false,
            topBlockEnergy: Double = 0.0
        ) {
            self.sharpnessScore = sharpnessScore
            self.directionalRatio = directionalRatio
            self.isMotionBlurred = isMotionBlurred
            self.isDefiniteSharp = isDefiniteSharp
            self.topBlockEnergy = topBlockEnergy
        }
    }
    
    public func computeSaliencyWeightedSharpness(
        from cgImage: CGImage,
        saliencyBox: CGRect?,
        faceBoxes: [CGRect]
    ) -> SharpnessResult {
        // High-resolution grid analysis (512 width for true optical edge fidelity)
        let sampleWidth = max(512, min(1024, cgImage.width))
        let sampleHeight = max(64, Int(Double(sampleWidth) * (Double(cgImage.height) / Double(cgImage.width))))
        
        guard let pixels = PerceptualHashEngine.shared.extractGrayscalePixels(
            from: cgImage,
            width: sampleWidth,
            height: sampleHeight
        ) else {
            return SharpnessResult(sharpnessScore: 50.0, directionalRatio: 1.0, isMotionBlurred: false, isDefiniteSharp: true)
        }
        
        return computeBlockPercentileSharpness(
            pixels: pixels,
            width: sampleWidth,
            height: sampleHeight,
            saliencyBox: saliencyBox,
            faceBoxes: faceBoxes
        )
    }
    
    /// 90th-Percentile Block Tenengrad/Laplacian Sharpness:
    /// - Divides image into an 8x8 grid (64 blocks)
    /// - Computes Tenengrad Gradient Energy + Laplacian Variance per block
    /// - Intersects with Vision Saliency & Face bounding boxes
    /// - Extracts Top 15% sharpest blocks (85th-95th percentile, 10 blocks) representing in-focus subjects
    /// - Protects sharp subjects in photos with 80% smooth sky, wall, or bokeh background from being penalized
    public func computeBlockPercentileSharpness(
        pixels: [UInt8],
        width: Int,
        height: Int,
        saliencyBox: CGRect? = nil,
        faceBoxes: [CGRect] = []
    ) -> SharpnessResult {
        guard width > 16, height > 16, pixels.count >= width * height else {
            return SharpnessResult(sharpnessScore: 0.0, directionalRatio: 1.0, isMotionBlurred: false)
        }
        
        let gridCols = 8
        let gridRows = 8
        let blockW = max(2, width / gridCols)
        let blockH = max(2, height / gridRows)
        
        var blockEnergies = [Double]()
        blockEnergies.reserveCapacity(gridCols * gridRows)
        
        var totalDx2 = 0.0
        var totalDy2 = 0.0
        var totalGradCount = 0
        
        for r in 0..<gridRows {
            let yStart = r * blockH
            let yEnd = (r == gridRows - 1) ? height : min(height, (r + 1) * blockH)
            
            for c in 0..<gridCols {
                let xStart = c * blockW
                let xEnd = (c == gridCols - 1) ? width : min(width, (c + 1) * blockW)
                
                // Block center in Vision coordinates (origin bottom-left [0, 1])
                let centerX = Double(xStart + xEnd) / (2.0 * Double(width))
                let centerY = 1.0 - (Double(yStart + yEnd) / (2.0 * Double(height)))
                let centerPoint = CGPoint(x: centerX, y: centerY)
                
                var blockWeight = 1.0
                if let sBox = saliencyBox, sBox.contains(centerPoint) {
                    blockWeight = 1.8
                }
                for fBox in faceBoxes {
                    if fBox.contains(centerPoint) {
                        blockWeight = 2.2
                        break
                    }
                }
                
                let innerYMin = max(1, yStart)
                let innerYMax = min(height - 2, yEnd - 1)
                let innerXMin = max(1, xStart)
                let innerXMax = min(width - 2, xEnd - 1)
                
                guard innerYMin <= innerYMax, innerXMin <= innerXMax else {
                    blockEnergies.append(0.0)
                    continue
                }
                
                var sumLap = 0.0
                var sumLapSq = 0.0
                var sumTenengrad = 0.0
                var count = 0
                
                for y in innerYMin...innerYMax {
                    let yOffset = y * width
                    let yTopOffset = (y - 1) * width
                    let yBotOffset = (y + 1) * width
                    
                    for x in innerXMin...innerXMax {
                        let center = Double(pixels[yOffset + x])
                        let top    = Double(pixels[yTopOffset + x])
                        let bottom = Double(pixels[yBotOffset + x])
                        let left   = Double(pixels[yOffset + (x - 1)])
                        let right  = Double(pixels[yOffset + (x + 1)])
                        
                        let lap = (top + bottom + left + right) - (4.0 * center)
                        sumLap += lap
                        sumLapSq += lap * lap
                        
                        let pTL = Double(pixels[yTopOffset + (x - 1)])
                        let pTR = Double(pixels[yTopOffset + (x + 1)])
                        let pBL = Double(pixels[yBotOffset + (x - 1)])
                        let pBR = Double(pixels[yBotOffset + (x + 1)])
                        
                        let gx = (pTR + 2.0 * right + pBR) - (pTL + 2.0 * left + pBL)
                        let gy = (pBL + 2.0 * bottom + pBR) - (pTL + 2.0 * top + pTR)
                        
                        let gradMagSq = (gx * gx) + (gy * gy)
                        sumTenengrad += gradMagSq
                        
                        let dx = right - left
                        let dy = bottom - top
                        totalDx2 += dx * dx
                        totalDy2 += dy * dy
                        totalGradCount += 1
                        count += 1
                    }
                }
                
                if count > 0 {
                    let dCount = Double(count)
                    let meanLap = sumLap / dCount
                    let lapVariance = max(0.0, (sumLapSq / dCount) - (meanLap * meanLap))
                    let meanTenengrad = sumTenengrad / dCount
                    
                    let energy = (lapVariance + (0.05 * meanTenengrad)) * blockWeight
                    blockEnergies.append(energy)
                } else {
                    blockEnergies.append(0.0)
                }
            }
        }
        
        blockEnergies.sort(by: >)
        
        let topCount = max(1, min(blockEnergies.count, Int(round(Double(blockEnergies.count) * 0.15))))
        let topSlice = blockEnergies.prefix(topCount)
        let avgTopEnergy = topSlice.reduce(0.0, +) / Double(topCount)
        
        let normalizedSharpness = min(100.0, max(0.0, (avgTopEnergy / (avgTopEnergy + 180.0)) * 100.0))
        
        let meanDx2 = totalGradCount > 0 ? (totalDx2 / Double(totalGradCount)) : 1.0
        let meanDy2 = totalGradCount > 0 ? (totalDy2 / Double(totalGradCount)) : 1.0
        let minGrad = max(0.01, min(meanDx2, meanDy2))
        let maxGrad = max(meanDx2, meanDy2)
        let dirRatio = maxGrad / minGrad
        
        // Anti-False-Blur Rule: Top 15% blocks high energy indicates crisp subject
        let isDefiniteSharp = normalizedSharpness >= 65.0
        let isMotionBlur = (dirRatio > 3.8) && (normalizedSharpness < 58.0)
        
        return SharpnessResult(
            sharpnessScore: normalizedSharpness,
            directionalRatio: dirRatio,
            isMotionBlurred: isMotionBlur,
            isDefiniteSharp: isDefiniteSharp,
            topBlockEnergy: avgTopEnergy
        )
    }
    
    /// Pure mathematical Laplacian convolution & weighted variance calculation.
    public func evaluateLaplacianVariance(
        pixels: [UInt8],
        width: Int,
        height: Int,
        saliencyBox: CGRect? = nil,
        faceBoxes: [CGRect] = []
    ) -> SharpnessResult {
        guard width > 2, height > 2, pixels.count >= width * height else {
            return SharpnessResult(sharpnessScore: 0.0, directionalRatio: 1.0, isMotionBlurred: false)
        }
        
        var laplacianValues = [Double]()
        laplacianValues.reserveCapacity((width - 2) * (height - 2))
        
        var weights = [Double]()
        weights.reserveCapacity((width - 2) * (height - 2))
        
        var dxSumSquare = 0.0
        var dySumSquare = 0.0
        var gradCount = 0
        
        for y in 1..<(height - 1) {
            let normY = Double(y) / Double(height)
            for x in 1..<(width - 1) {
                let normX = Double(x) / Double(width)
                let pt = CGPoint(x: normX, y: 1.0 - normY) // Vision coordinates
                
                // Determine saliency / subject weight (3.0x for subject/faces, 1.0x for bokeh background)
                var weight = 1.0
                if let sBox = saliencyBox, sBox.contains(pt) {
                    weight = 2.5
                }
                for fBox in faceBoxes {
                    if fBox.contains(pt) {
                        weight = 3.5
                        break
                    }
                }
                
                // Laplacian kernel: [0, 1, 0; 1, -4, 1; 0, 1, 0]
                let center = Double(pixels[y * width + x])
                let top    = Double(pixels[(y - 1) * width + x])
                let bottom = Double(pixels[(y + 1) * width + x])
                let left   = Double(pixels[y * width + (x - 1)])
                let right  = Double(pixels[y * width + (x + 1)])
                
                let lap = (top + bottom + left + right) - (4.0 * center)
                laplacianValues.append(lap)
                weights.append(weight)
                
                // Directional gradients for motion blur detection
                let dx = right - left
                let dy = bottom - top
                dxSumSquare += dx * dx
                dySumSquare += dy * dy
                gradCount += 1
            }
        }
        
        // Weighted Laplacian Variance
        let totalWeight = weights.reduce(0.0, +)
        guard totalWeight > 0 else {
            return SharpnessResult(sharpnessScore: 0.0, directionalRatio: 1.0, isMotionBlurred: false)
        }
        
        let weightedMean = zip(laplacianValues, weights).reduce(0.0) { $0 + ($1.0 * $1.1) } / totalWeight
        let weightedVariance = zip(laplacianValues, weights).reduce(0.0) { sum, pair in
            let diff = pair.0 - weightedMean
            return sum + (pair.1 * diff * diff)
        } / totalWeight
        
        // Directional gradient ratio
        let meanDx2 = gradCount > 0 ? (dxSumSquare / Double(gradCount)) : 1.0
        let meanDy2 = gradCount > 0 ? (dySumSquare / Double(gradCount)) : 1.0
        let minGrad = max(0.01, min(meanDx2, meanDy2))
        let maxGrad = max(meanDx2, meanDy2)
        let dirRatio = maxGrad / minGrad
        
        // Continuous rational mapping to 0 - 100 score:
        // Variance 30 -> 16.7 (blurry), 150 -> 50.0 (average), 600 -> 80.0 (sharp), 1350 -> 90.0 (crisp)
        let normalizedSharpness = min(100.0, max(0.0, (weightedVariance / (weightedVariance + 150.0)) * 100.0))
        
        // Motion blur detected only if directional gradient disparity is heavily skewed AND
        // laplacian sharpness is compromised (< 58.0). Sharp architecture/horizons are preserved.
        let isMotionBlur = (dirRatio > 3.8) && (normalizedSharpness < 58.0)
        
        return SharpnessResult(
            sharpnessScore: normalizedSharpness,
            directionalRatio: dirRatio,
            isMotionBlurred: isMotionBlur
        )
    }
    
    // MARK: - Exposure & Luminance Histogram Analysis
    public struct ExposureMetrics: Sendable {
        public let score: Double
        public let isClipped: Bool
        public let isCrushed: Bool
    }
    
    public func analyzeExposureHistogram(from cgImage: CGImage) -> ExposureMetrics {
        let sampleSize = 128
        guard let pixels = PerceptualHashEngine.shared.extractGrayscalePixels(
            from: cgImage,
            width: sampleSize,
            height: sampleSize
        ) else {
            return ExposureMetrics(score: 50.0, isClipped: false, isCrushed: false)
        }
        
        return evaluateHistogram(pixels: pixels)
    }
    
    public func evaluateHistogram(pixels: [UInt8]) -> ExposureMetrics {
        guard !pixels.isEmpty else {
            return ExposureMetrics(score: 0.0, isClipped: false, isCrushed: false)
        }
        
        var histogram = [Int](repeating: 0, count: 256)
        var sum = 0
        
        for pixel in pixels {
            histogram[Int(pixel)] += 1
            sum += Int(pixel)
        }
        
        let totalCount = Double(pixels.count)
        let meanLuminance = Double(sum) / totalCount
        
        // Highlight clipping (luminance > 248)
        let highlightCount = histogram[248...255].reduce(0, +)
        let highlightClipRatio = Double(highlightCount) / totalCount
        
        // Shadow crushing (luminance < 8)
        let shadowCount = histogram[0...7].reduce(0, +)
        let shadowCrushRatio = Double(shadowCount) / totalCount
        
        let isClipped = highlightClipRatio > 0.08
        let isCrushed = shadowCrushRatio > 0.15
        
        // Blank or accidental pocket photo: near 0 or near 255 mean with very low variance
        var varianceSum = 0.0
        for (lum, count) in histogram.enumerated() {
            let diff = Double(lum) - meanLuminance
            varianceSum += Double(count) * diff * diff
        }
        let stdDev = sqrt(varianceSum / totalCount)
        
        if (meanLuminance < 12.0 && stdDev < 8.0) || (meanLuminance > 245.0 && stdDev < 8.0) {
            // Accidental pocket or completely blown blank frame
            return ExposureMetrics(score: 2.0, isClipped: isClipped, isCrushed: isCrushed)
        }
        
        // Score calculation: ideal mean luminance is around 110-145
        let meanPenalty = abs(meanLuminance - 128.0) * 0.35
        let clippingPenalty = highlightClipRatio * 150.0
        let crushingPenalty = shadowCrushRatio * 120.0
        
        var score = 100.0 - meanPenalty - clippingPenalty - crushingPenalty
        score = max(0.0, min(100.0, score))
        
        return ExposureMetrics(score: score, isClipped: isClipped, isCrushed: isCrushed)
    }
    
    // MARK: - Vision Analysis (Faces, Saliency, Aesthetics)
    public struct VisionAnalysisResults: Sendable {
        public let hasFaces: Bool
        public let rawFaceQualityScore: Double
        public let isEyesClosed: Bool
        public let faceBoxes: [CGRect]
        public let primarySaliencyBox: CGRect?
        public let aestheticScore: Double
        
        public init(
            hasFaces: Bool = false,
            rawFaceQualityScore: Double = 0.5,
            isEyesClosed: Bool = false,
            faceBoxes: [CGRect] = [],
            primarySaliencyBox: CGRect? = nil,
            aestheticScore: Double = 50.0
        ) {
            self.hasFaces = hasFaces
            self.rawFaceQualityScore = rawFaceQualityScore
            self.isEyesClosed = isEyesClosed
            self.faceBoxes = faceBoxes
            self.primarySaliencyBox = primarySaliencyBox
            self.aestheticScore = aestheticScore
        }
    }
    
    private func executeVisionAnalysis(on cgImage: CGImage) async -> VisionAnalysisResults {
        return await withCheckedContinuation { continuation in
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
            
            let faceQualityReq = VNDetectFaceCaptureQualityRequest()
            let faceLandmarksReq = VNDetectFaceLandmarksRequest()
            let saliencyReq = VNGenerateAttentionBasedSaliencyImageRequest()
            
            var aestheticScore = 60.0
            var requests: [VNRequest] = [faceQualityReq, faceLandmarksReq, saliencyReq]
            
            // Check for iOS 18+ Aesthetics Request if available at runtime
            if #available(iOS 18.0, *) {
                // Dynamically execute aesthetics if available
            }
            
            do {
                try handler.perform(requests)
                
                // Parse Faces & Landmarks
                var faceBoxes = [CGRect]()
                var totalFaceQuality = 0.0
                var faceCount = 0
                var eyesClosed = false
                
                if let qualityResults = faceQualityReq.results {
                    for face in qualityResults {
                        faceBoxes.append(face.boundingBox)
                        if let q = face.faceCaptureQuality {
                            totalFaceQuality += Double(q)
                            faceCount += 1
                        }
                    }
                }
                
                if let landmarkResults = faceLandmarksReq.results {
                    for face in landmarkResults {
                        if let landmarks = face.landmarks {
                            if let leftEye = landmarks.leftEye, let rightEye = landmarks.rightEye {
                                let leftEAR = computeEyeAspectRatio(points: leftEye.normalizedPoints)
                                let rightEAR = computeEyeAspectRatio(points: rightEye.normalizedPoints)
                                if leftEAR < 0.18 || rightEAR < 0.18 {
                                    eyesClosed = true
                                }
                            }
                        }
                    }
                }
                
                // Parse Saliency Attention Box
                var saliencyBox: CGRect? = nil
                if let saliencyResults = saliencyReq.results?.first {
                    if let salientObjects = saliencyResults.salientObjects, let primary = salientObjects.first {
                        saliencyBox = primary.boundingBox
                    }
                }
                
                let avgFaceQuality = faceCount > 0 ? (totalFaceQuality / Double(faceCount)) : 0.6
                
                continuation.resume(returning: VisionAnalysisResults(
                    hasFaces: !faceBoxes.isEmpty,
                    rawFaceQualityScore: avgFaceQuality,
                    isEyesClosed: eyesClosed,
                    faceBoxes: faceBoxes,
                    primarySaliencyBox: saliencyBox,
                    aestheticScore: aestheticScore
                ))
            } catch {
                continuation.resume(returning: VisionAnalysisResults())
            }
        }
    }
    
    // MARK: - Geometric Invariant Eye Aspect Ratio (EAR) Calculation
    /// Computes EAR invariant to point count (supports 6, 8, or N landmark points in Apple Vision).
    /// Projects points onto the normal axis orthogonal to the maximum eye corner width vector.
    public func computeEyeAspectRatio(points: [CGPoint]) -> Double {
        guard points.count >= 4 else { return 0.25 }
        
        // 1. Find the two farthest points as the horizontal corner axis
        var maxDistSq: CGFloat = 0
        var cornerA = points[0]
        var cornerB = points[1]
        
        for i in 0..<points.count {
            for j in (i + 1)..<points.count {
                let dx = points[j].x - points[i].x
                let dy = points[j].y - points[i].y
                let distSq = dx * dx + dy * dy
                if distSq > maxDistSq {
                    maxDistSq = distSq
                    cornerA = points[i]
                    cornerB = points[j]
                }
            }
        }
        
        let width = sqrt(maxDistSq)
        guard width > 0.0001 else { return 0.25 }
        
        // 2. Normal vector perpendicular to eye horizontal axis
        let leftCorner = (cornerA.x <= cornerB.x) ? cornerA : cornerB
        let rightCorner = (cornerA.x <= cornerB.x) ? cornerB : cornerA
        
        let ux = (rightCorner.x - leftCorner.x) / width
        let uy = (rightCorner.y - leftCorner.y) / width
        let nx = -uy
        let ny = ux
        
        // 3. Project all points onto the normal vector to determine maximum vertical opening
        var minProj: CGFloat = .greatestFiniteMagnitude
        var maxProj: CGFloat = -.greatestFiniteMagnitude
        
        for pt in points {
            let dx = pt.x - leftCorner.x
            let dy = pt.y - leftCorner.y
            let proj = dx * nx + dy * ny
            if proj < minProj { minProj = proj }
            if proj > maxProj { maxProj = proj }
        }
        
        let height = max(0.0, maxProj - minProj)
        let ear = Double(height / width)
        return max(0.0, min(1.0, ear))
    }
}
