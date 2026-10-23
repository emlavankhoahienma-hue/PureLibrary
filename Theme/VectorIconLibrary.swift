//
//  VectorIconLibrary.swift
//  PureLibrary
//
//  Lucide/Feather/Heroicons-styled Vector Shapes & Icons.
//  Strictly ZERO-EMOJI Rule compliant.
//

import SwiftUI

// MARK: - Crown Vector Shape (Best Shot Badge)
public struct CrownVectorShape: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Base points
        path.move(to: CGPoint(x: w * 0.15, y: h * 0.85))
        path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.85))
        path.addLine(to: CGPoint(x: w * 0.92, y: h * 0.32))
        path.addLine(to: CGPoint(x: w * 0.68, y: h * 0.55))
        path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.18))
        path.addLine(to: CGPoint(x: w * 0.32, y: h * 0.55))
        path.addLine(to: CGPoint(x: w * 0.08, y: h * 0.32))
        path.closeSubpath()
        return path
    }
}

// MARK: - Sharpness Focus Scan Reticle Shape
public struct SharpnessScanVectorShape: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let cornerLen = w * 0.25
        
        // Top-Left corner
        path.move(to: CGPoint(x: 0, y: cornerLen))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: cornerLen, y: 0))
        
        // Top-Right corner
        path.move(to: CGPoint(x: w - cornerLen, y: 0))
        path.addLine(to: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: w, y: cornerLen))
        
        // Bottom-Right corner
        path.move(to: CGPoint(x: w, y: h - cornerLen))
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: w - cornerLen, y: h))
        
        // Bottom-Left corner
        path.move(to: CGPoint(x: cornerLen, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.addLine(to: CGPoint(x: 0, y: h - cornerLen))
        
        // Center crosshair
        path.move(to: CGPoint(x: w * 0.35, y: h * 0.5))
        path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.5))
        path.move(to: CGPoint(x: w * 0.5, y: h * 0.35))
        path.addLine(to: CGPoint(x: w * 0.5, y: h * 0.65))
        
        return path
    }
}

// MARK: - Duplicate Layers Vector Shape
public struct DuplicateLayersVectorShape: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Front Rectangle
        let front = CGRect(x: 0, y: h * 0.22, width: w * 0.78, height: h * 0.78)
        path.addRoundedRect(in: front, cornerSize: CGSize(width: w * 0.12, height: h * 0.12))
        
        // Back Layer Lines
        path.move(to: CGPoint(x: w * 0.28, y: h * 0.12))
        path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.12))
        path.addQuadCurve(to: CGPoint(x: w, y: h * 0.24), control: CGPoint(x: w, y: h * 0.12))
        path.addLine(to: CGPoint(x: w, y: h * 0.72))
        
        return path
    }
}

// MARK: - Trash Bin Vector Shape
public struct TrashBinVectorShape: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Lid bar
        path.move(to: CGPoint(x: w * 0.1, y: h * 0.22))
        path.addLine(to: CGPoint(x: w * 0.9, y: h * 0.22))
        
        // Handle
        path.move(to: CGPoint(x: w * 0.35, y: h * 0.22))
        path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.10))
        path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.10))
        path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.22))
        
        // Bin body
        path.move(to: CGPoint(x: w * 0.18, y: h * 0.22))
        path.addLine(to: CGPoint(x: w * 0.24, y: h * 0.90))
        path.addQuadCurve(to: CGPoint(x: w * 0.32, y: h * 0.96), control: CGPoint(x: w * 0.24, y: h * 0.96))
        path.addLine(to: CGPoint(x: w * 0.68, y: h * 0.96))
        path.addQuadCurve(to: CGPoint(x: w * 0.76, y: h * 0.90), control: CGPoint(x: w * 0.76, y: h * 0.96))
        path.addLine(to: CGPoint(x: w * 0.82, y: h * 0.22))
        
        // Vertical ribs inside bin
        path.move(to: CGPoint(x: w * 0.40, y: h * 0.36))
        path.addLine(to: CGPoint(x: w * 0.40, y: h * 0.82))
        path.move(to: CGPoint(x: w * 0.60, y: h * 0.36))
        path.addLine(to: CGPoint(x: w * 0.60, y: h * 0.82))
        
        return path
    }
}

// MARK: - Storage Meter Vector Shape
public struct StorageMeterVectorShape: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Drive body
        let driveRect = CGRect(x: w * 0.08, y: h * 0.18, width: w * 0.84, height: h * 0.64)
        path.addRoundedRect(in: driveRect, cornerSize: CGSize(width: w * 0.1, height: h * 0.1))
        
        // Activity status LED
        path.addEllipse(in: CGRect(x: w * 0.22, y: h * 0.44, width: w * 0.12, height: h * 0.12))
        
        // Storage slot line
        path.move(to: CGPoint(x: w * 0.45, y: h * 0.50))
        path.addLine(to: CGPoint(x: w * 0.78, y: h * 0.50))
        
        return path
    }
}

// MARK: - Eye Sparkle Vector Shape
public struct EyeSparkleVectorShape: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Eye outline
        path.move(to: CGPoint(x: w * 0.05, y: h * 0.50))
        path.addQuadCurve(to: CGPoint(x: w * 0.95, y: h * 0.50), control: CGPoint(x: w * 0.50, y: h * 0.12))
        path.addQuadCurve(to: CGPoint(x: w * 0.05, y: h * 0.50), control: CGPoint(x: w * 0.50, y: h * 0.88))
        
        // Iris / Pupil
        path.addEllipse(in: CGRect(x: w * 0.38, y: h * 0.38, width: w * 0.24, height: h * 0.24))
        
        return path
    }
}

// MARK: - Exposure Slider Vector Shape
public struct ExposureSliderVectorShape: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Top track & thumb
        path.move(to: CGPoint(x: w * 0.10, y: h * 0.30))
        path.addLine(to: CGPoint(x: w * 0.90, y: h * 0.30))
        path.addEllipse(in: CGRect(x: w * 0.55, y: h * 0.18, width: w * 0.22, height: h * 0.24))
        
        // Bottom track & thumb
        path.move(to: CGPoint(x: w * 0.10, y: h * 0.70))
        path.addLine(to: CGPoint(x: w * 0.90, y: h * 0.70))
        path.addEllipse(in: CGRect(x: w * 0.22, y: h * 0.58, width: w * 0.22, height: h * 0.24))
        
        return path
    }
}

// MARK: - Shield Check Vector Shape (AI On-Device Neural Engine / Local Privacy Secured)
public struct ShieldCheckVectorShape: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Shield rim
        path.move(to: CGPoint(x: w * 0.50, y: h * 0.08))
        path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.22))
        path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.52))
        path.addQuadCurve(to: CGPoint(x: w * 0.50, y: h * 0.94), control: CGPoint(x: w * 0.84, y: h * 0.80))
        path.addQuadCurve(to: CGPoint(x: w * 0.12, y: h * 0.52), control: CGPoint(x: w * 0.16, y: h * 0.80))
        path.addLine(to: CGPoint(x: w * 0.12, y: h * 0.22))
        path.closeSubpath()
        
        // Internal checkmark
        path.move(to: CGPoint(x: w * 0.32, y: h * 0.50))
        path.addLine(to: CGPoint(x: w * 0.45, y: h * 0.63))
        path.addLine(to: CGPoint(x: w * 0.68, y: h * 0.38))
        
        return path
    }
}

// MARK: - Checkmark Vector Shape
public struct CheckmarkVectorShape: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w * 0.15, y: h * 0.52))
        path.addLine(to: CGPoint(x: w * 0.40, y: h * 0.78))
        path.addLine(to: CGPoint(x: w * 0.85, y: h * 0.22))
        return path
    }
}

// MARK: - Cross Vector Shape
public struct CrossVectorShape: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w * 0.20, y: h * 0.20))
        path.addLine(to: CGPoint(x: w * 0.80, y: h * 0.80))
        path.move(to: CGPoint(x: w * 0.80, y: h * 0.20))
        path.addLine(to: CGPoint(x: w * 0.20, y: h * 0.80))
        return path
    }
}

// MARK: - Undo Vector Shape
public struct UndoVectorShape: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Arrow head
        path.move(to: CGPoint(x: w * 0.32, y: h * 0.20))
        path.addLine(to: CGPoint(x: w * 0.14, y: h * 0.38))
        path.addLine(to: CGPoint(x: w * 0.32, y: h * 0.56))
        
        // Curved body
        path.move(to: CGPoint(x: w * 0.18, y: h * 0.38))
        path.addLine(to: CGPoint(x: w * 0.52, y: h * 0.38))
        path.addQuadCurve(to: CGPoint(x: w * 0.82, y: h * 0.68), control: CGPoint(x: w * 0.82, y: h * 0.38))
        path.addLine(to: CGPoint(x: w * 0.82, y: h * 0.78))
        
        return path
    }
}

// MARK: - Receipt & Document Scan Shape
public struct ReceiptScanVectorShape: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Document border
        let doc = CGRect(x: w * 0.18, y: h * 0.10, width: w * 0.64, height: h * 0.80)
        path.addRoundedRect(in: doc, cornerSize: CGSize(width: w * 0.08, height: h * 0.08))
        
        // Text lines
        path.move(to: CGPoint(x: w * 0.30, y: h * 0.30))
        path.addLine(to: CGPoint(x: w * 0.70, y: h * 0.30))
        
        path.move(to: CGPoint(x: w * 0.30, y: h * 0.46))
        path.addLine(to: CGPoint(x: w * 0.70, y: h * 0.46))
        
        path.move(to: CGPoint(x: w * 0.30, y: h * 0.62))
        path.addLine(to: CGPoint(x: w * 0.54, y: h * 0.62))
        
        return path
    }
}

// MARK: - Video Film Vector Shape
public struct VideoFilmVectorShape: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Frame
        let film = CGRect(x: w * 0.12, y: h * 0.18, width: w * 0.76, height: h * 0.64)
        path.addRoundedRect(in: film, cornerSize: CGSize(width: w * 0.08, height: h * 0.08))
        
        // Sprocket holes
        let sprockets: [CGFloat] = [0.26, 0.44, 0.62, 0.74]
        for yOffset in sprockets {
            path.addRect(CGRect(x: w * 0.16, y: h * yOffset, width: w * 0.08, height: h * 0.08))
            path.addRect(CGRect(x: w * 0.76, y: h * yOffset, width: w * 0.08, height: h * 0.08))
        }
        
        // Play triangle
        path.move(to: CGPoint(x: w * 0.44, y: h * 0.40))
        path.addLine(to: CGPoint(x: w * 0.60, y: h * 0.50))
        path.addLine(to: CGPoint(x: w * 0.44, y: h * 0.60))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Blur / Out-of-focus Droplet Shape
public struct BlurDropVectorShape: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        path.move(to: CGPoint(x: w * 0.50, y: h * 0.10))
        path.addQuadCurve(to: CGPoint(x: w * 0.86, y: h * 0.64), control: CGPoint(x: w * 0.86, y: h * 0.38))
        path.addQuadCurve(to: CGPoint(x: w * 0.50, y: h * 0.92), control: CGPoint(x: w * 0.86, y: h * 0.92))
        path.addQuadCurve(to: CGPoint(x: w * 0.14, y: h * 0.64), control: CGPoint(x: w * 0.14, y: h * 0.92))
        path.addQuadCurve(to: CGPoint(x: w * 0.50, y: h * 0.10), control: CGPoint(x: w * 0.14, y: h * 0.38))
        
        return path
    }
}

// MARK: - Chevron Vector Shape
public struct ChevronVectorShape: Shape {
    public enum Direction {
        case left, right, up, down
    }
    public let direction: Direction
    
    public init(direction: Direction = .right) {
        self.direction = direction
    }
    
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        switch direction {
        case .right:
            path.move(to: CGPoint(x: w * 0.35, y: h * 0.20))
            path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.50))
            path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.80))
        case .left:
            path.move(to: CGPoint(x: w * 0.65, y: h * 0.20))
            path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.50))
            path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.80))
        case .up:
            path.move(to: CGPoint(x: w * 0.20, y: h * 0.65))
            path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.35))
            path.addLine(to: CGPoint(x: w * 0.80, y: h * 0.65))
        case .down:
            path.move(to: CGPoint(x: w * 0.20, y: h * 0.35))
            path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.65))
            path.addLine(to: CGPoint(x: w * 0.80, y: h * 0.35))
        }
        return path
    }
}

// MARK: - Sparkles Vector Shape (Aesthetic & Vision score)
public struct SparklesVectorShape: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        
        // Large central star
        let cx = w * 0.50
        let cy = h * 0.50
        let rOut = w * 0.40
        let rIn = w * 0.12
        
        path.move(to: CGPoint(x: cx, y: cy - rOut))
        path.addQuadCurve(to: CGPoint(x: cx + rOut, y: cy), control: CGPoint(x: cx + rIn, y: cy - rIn))
        path.addQuadCurve(to: CGPoint(x: cx, y: cy + rOut), control: CGPoint(x: cx + rIn, y: cy + rIn))
        path.addQuadCurve(to: CGPoint(x: cx - rOut, y: cy), control: CGPoint(x: cx - rIn, y: cy + rIn))
        path.addQuadCurve(to: CGPoint(x: cx, y: cy - rOut), control: CGPoint(x: cx - rIn, y: cy - rIn))
        
        return path
    }
}

// MARK: - Unified Vector Icon Enum
public enum VectorIconType {
    case crown
    case sharpnessScan
    case duplicateLayers
    case layers
    case trashBin
    case storageMeter
    case eyeSparkle
    case faceDetection
    case exposureSlider
    case sliders
    case shieldCheck
    case checkmark
    case cross
    case undo
    case receiptScan
    case videoFilm
    case blurDrop
    case chevron(ChevronVectorShape.Direction)
    case sparkles
}

// MARK: - Vector Icon Component
public struct VectorIconView: View {
    public let type: VectorIconType
    public let size: CGFloat
    public let color: Color
    public let lineWidth: CGFloat
    
    public init(
        _ type: VectorIconType,
        size: CGFloat = 20,
        color: Color = AppTheme.Colors.textPrimary,
        lineWidth: CGFloat = 1.8
    ) {
        self.type = type
        self.size = size
        self.color = color
        self.lineWidth = lineWidth
    }
    
    public var body: some View {
        Group {
            switch type {
            case .crown:
                CrownVectorShape()
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            case .sharpnessScan:
                SharpnessScanVectorShape()
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            case .duplicateLayers, .layers:
                DuplicateLayersVectorShape()
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            case .trashBin:
                TrashBinVectorShape()
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            case .storageMeter:
                StorageMeterVectorShape()
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            case .eyeSparkle, .faceDetection:
                EyeSparkleVectorShape()
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            case .exposureSlider, .sliders:
                ExposureSliderVectorShape()
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            case .shieldCheck:
                ShieldCheckVectorShape()
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            case .checkmark:
                CheckmarkVectorShape()
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            case .cross:
                CrossVectorShape()
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            case .undo:
                UndoVectorShape()
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            case .receiptScan:
                ReceiptScanVectorShape()
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            case .videoFilm:
                VideoFilmVectorShape()
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            case .blurDrop:
                BlurDropVectorShape()
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            case .chevron(let dir):
                ChevronVectorShape(direction: dir)
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            case .sparkles:
                SparklesVectorShape()
                    .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: size, height: size)
    }
}
