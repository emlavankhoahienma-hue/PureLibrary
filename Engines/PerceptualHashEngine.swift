//
//  PerceptualHashEngine.swift
//  PureLibrary
//
//  High-performance 64-bit Perceptual Hash (pHash) & Difference Hash (dHash) Engine.
//  Strictly ZERO-EMOJI Rule compliant.
//

import Foundation
import CoreGraphics
import Accelerate

#if canImport(UIKit)
import UIKit
#endif

public final class PerceptualHashEngine: Sendable {
    public static let shared = PerceptualHashEngine()
    
    public init() {}
    
    // MARK: - Difference Hash (dHash) 64-bit
    /// Computes 64-bit difference hash by downscaling to 9x8 grayscale and comparing horizontal gradients.
    public func computeDHash(from cgImage: CGImage) -> UInt64 {
        let width = 9
        let height = 8
        guard let grayscalePixels = extractGrayscalePixels(from: cgImage, width: width, height: height) else {
            return 0
        }
        return computeDHashFromGrayscaleGrid(grayscalePixels, width: width, height: height)
    }
    
    /// Computes dHash directly from a pre-extracted grayscale byte array of dimensions 9x8.
    public func computeDHashFromGrayscaleGrid(_ pixels: [UInt8], width: Int = 9, height: Int = 8) -> UInt64 {
        guard pixels.count >= width * height else { return 0 }
        var hash: UInt64 = 0
        var bitIndex = 0
        
        for y in 0..<height {
            for x in 0..<(width - 1) {
                let left = pixels[y * width + x]
                let right = pixels[y * width + (x + 1)]
                if left > right {
                    hash |= (1 << bitIndex)
                }
                bitIndex += 1
            }
        }
        return hash
    }
    
    // MARK: - Perceptual Hash (pHash) 64-bit
    /// Computes 64-bit DCT-based perceptual hash from a CGImage.
    public func computePHash(from cgImage: CGImage) -> UInt64 {
        let size = 32
        guard let pixels = extractGrayscalePixels(from: cgImage, width: size, height: size) else {
            return 0
        }
        return computePHashFromGrayscaleGrid(pixels, size: size)
    }
    
    /// Computes 64-bit DCT-based pHash from a 32x32 grayscale buffer.
    public func computePHashFromGrayscaleGrid(_ pixels: [UInt8], size: Int = 32) -> UInt64 {
        guard pixels.count >= size * size else { return 0 }
        
        // 1. Convert to Double array
        var doubleMatrix = [Double](repeating: 0.0, count: size * size)
        for i in 0..<(size * size) {
            doubleMatrix[i] = Double(pixels[i])
        }
        
        // 2. Perform 2D Discrete Cosine Transform (DCT-II)
        let dctMatrix = compute2DDCT(doubleMatrix, size: size)
        
        // 3. Extract top-left 8x8 low frequency coefficients (excluding DC term at [0][0])
        var lowFreq = [Double]()
        lowFreq.reserveCapacity(64)
        for u in 0..<8 {
            for v in 0..<8 {
                if u == 0 && v == 0 { continue }
                lowFreq.append(dctMatrix[u * size + v])
            }
        }
        
        // 4. Calculate Median of low frequency coefficients
        let sortedCoeffs = lowFreq.sorted()
        let median: Double
        if sortedCoeffs.isEmpty {
            median = 0.0
        } else if sortedCoeffs.count % 2 == 1 {
            median = sortedCoeffs[sortedCoeffs.count / 2]
        } else {
            let mid = sortedCoeffs.count / 2
            median = (sortedCoeffs[mid - 1] + sortedCoeffs[mid]) / 2.0
        }
        
        // 5. Generate 64-bit hash (1 if >= median, 0 if < median)
        var hash: UInt64 = 0
        var bitIndex = 0
        for u in 0..<8 {
            for v in 0..<8 {
                let val = dctMatrix[u * size + v]
                if val >= median {
                    hash |= (1 << bitIndex)
                }
                bitIndex += 1
            }
        }
        return hash
    }
    
    // MARK: - Hamming Distance & Similarity
    /// Computes bitwise Hamming distance between two 64-bit hashes using hardware popcount.
    public func hammingDistance(_ hash1: UInt64, _ hash2: UInt64) -> Int {
        return (hash1 ^ hash2).nonzeroBitCount
    }
    
    /// Normalizes similarity into a percentage [0.0 ... 1.0].
    public func similarityPercentage(_ hash1: UInt64, _ hash2: UInt64) -> Double {
        let dist = hammingDistance(hash1, hash2)
        return max(0.0, min(1.0, Double(64 - dist) / 64.0))
    }
    
    // MARK: - Internal 2D DCT-II Implementation
    private func compute2DDCT(_ matrix: [Double], size: Int) -> [Double] {
        var output = [Double](repeating: 0.0, count: size * size)
        let pi = Double.pi
        let factor = pi / (2.0 * Double(size))
        
        // 1D row DCT followed by 1D col DCT
        var rowTransformed = [Double](repeating: 0.0, count: size * size)
        
        for r in 0..<size {
            for u in 0..<size {
                var sum = 0.0
                for c in 0..<size {
                    sum += matrix[r * size + c] * cos(Double(2 * c + 1) * Double(u) * factor)
                }
                let alpha = (u == 0) ? (1.0 / sqrt(Double(size))) : sqrt(2.0 / Double(size))
                rowTransformed[r * size + u] = alpha * sum
            }
        }
        
        for c in 0..<size {
            for v in 0..<size {
                var sum = 0.0
                for r in 0..<size {
                    sum += rowTransformed[r * size + c] * cos(Double(2 * r + 1) * Double(v) * factor)
                }
                let alpha = (v == 0) ? (1.0 / sqrt(Double(size))) : sqrt(2.0 / Double(size))
                output[v * size + c] = alpha * sum
            }
        }
        
        return output
    }
    
    // MARK: - Grayscale Buffer Extraction
    public func extractGrayscalePixels(from cgImage: CGImage, width: Int, height: Int) -> [UInt8]? {
        var pixelBuffer = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        
        guard let context = CGContext(
            data: &pixelBuffer,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }
        
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelBuffer
    }
}
